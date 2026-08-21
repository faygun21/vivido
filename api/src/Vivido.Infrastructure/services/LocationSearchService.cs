using System.Globalization;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Vivido.Application.dtos.location;
using Vivido.Infrastructure.Data;

namespace Vivido.Infrastructure.Services;

/// <summary>
/// R-105 için önce yerel mahalleleri, eşleşme yoksa yapılandırılmış geocoder'ı arar.
/// </summary>
public sealed class LocationSearchService : ILocationSearchService
{
    private const string Attribution = "© OpenStreetMap contributors";

    // data/cankaya.geojson dosyasındaki ilçe sınırının zarfı.
    private const double West = 32.6265211;
    private const double South = 39.6582726;
    private const double East = 33.14353;
    private const double North = 39.9374826;

    private static readonly TimeSpan MinimumRequestInterval = TimeSpan.FromSeconds(1);
    private static readonly TimeSpan CacheDuration = TimeSpan.FromHours(24);
    private static readonly SemaphoreSlim GeocoderGate = new(1, 1);
    private static readonly JsonSerializerOptions GeocoderJsonOptions = new(JsonSerializerDefaults.Web)
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };
    private static DateTimeOffset _lastGeocoderRequest = DateTimeOffset.MinValue;

    private readonly VividoDbContext _context;
    private readonly HttpClient _httpClient;
    private readonly IMemoryCache _cache;

    public LocationSearchService(
        VividoDbContext context,
        HttpClient httpClient,
        IMemoryCache cache)
    {
        _context = context;
        _httpClient = httpClient;
        _cache = cache;
    }

    public async Task<LocationSearchResponseDto> SearchAsync(
        string query,
        int limit,
        CancellationToken cancellationToken = default)
    {
        var trimmedQuery = query.Trim();
        var neighborhoodResults = await SearchNeighborhoodsAsync(
            trimmedQuery,
            limit,
            cancellationToken);

        // Yerel veri hem daha hızlıdır hem de dış servis kotasını tüketmez.
        if (neighborhoodResults.Count > 0)
        {
            return new LocationSearchResponseDto(neighborhoodResults, Attribution);
        }

        var geocoderResults = await SearchGeocoderAsync(trimmedQuery, limit, cancellationToken);
        return new LocationSearchResponseDto(geocoderResults, Attribution);
    }

    private async Task<IReadOnlyList<LocationSearchResultDto>> SearchNeighborhoodsAsync(
        string query,
        int limit,
        CancellationToken cancellationToken)
    {
        var normalizedQuery = NormalizeForSearch(query);
        var names = await _context.Neighborhoods
            .AsNoTracking()
            .Select(item => new NeighborhoodName(item.Id, item.Name))
            .ToListAsync(cancellationToken);

        var selected = names
            .Select(item => new
            {
                Item = item,
                NormalizedName = NormalizeForSearch(item.Name),
            })
            .Where(item => item.NormalizedName.Contains(normalizedQuery, StringComparison.Ordinal))
            .OrderBy(item => item.NormalizedName == normalizedQuery ? 0 : 1)
            .ThenBy(item => item.NormalizedName.StartsWith(normalizedQuery, StringComparison.Ordinal) ? 0 : 1)
            .ThenBy(item => item.Item.Name.Length)
            .ThenBy(item => item.NormalizedName, StringComparer.Ordinal)
            .Take(limit)
            .Select(item => item.Item)
            .ToList();

        if (selected.Count == 0)
        {
            return [];
        }

        var selectedIds = selected.Select(item => item.Id).ToArray();
        var neighborhoods = await _context.Neighborhoods
            .AsNoTracking()
            .Where(item => selectedIds.Contains(item.Id))
            .ToListAsync(cancellationToken);
        var byId = neighborhoods.ToDictionary(item => item.Id);

        return selected
            .Where(item => byId.ContainsKey(item.Id))
            .Select(item =>
            {
                var neighborhood = byId[item.Id];
                var center = neighborhood.Geom.Centroid;
                var envelope = neighborhood.Geom.EnvelopeInternal;

                return new LocationSearchResultDto(
                    $"neighborhood:{neighborhood.Id}",
                    $"{neighborhood.Name} Mahallesi, Çankaya, Ankara",
                    "neighborhood",
                    center.Y,
                    center.X,
                    new LocationBoundsDto(
                        envelope.MinY,
                        envelope.MinX,
                        envelope.MaxY,
                        envelope.MaxX),
                    neighborhood.Name,
                    "local");
            })
            .ToList();
    }

    private async Task<IReadOnlyList<LocationSearchResultDto>> SearchGeocoderAsync(
        string query,
        int limit,
        CancellationToken cancellationToken)
    {
        var cacheKey = $"location-search:{NormalizeForSearch(query)}:{limit}";
        if (_cache.TryGetValue(cacheKey, out LocationSearchResultDto[]? cached) && cached is not null)
        {
            return cached;
        }

        await GeocoderGate.WaitAsync(cancellationToken);
        try
        {
            // Kapıyı beklerken başka istek aynı sonucu önbelleğe almış olabilir.
            if (_cache.TryGetValue(cacheKey, out cached) && cached is not null)
            {
                return cached;
            }

            var elapsed = DateTimeOffset.UtcNow - _lastGeocoderRequest;
            if (elapsed < MinimumRequestInterval)
            {
                await Task.Delay(MinimumRequestInterval - elapsed, cancellationToken);
            }

            _lastGeocoderRequest = DateTimeOffset.UtcNow;
            var path = "search"
                + $"?q={Uri.EscapeDataString(query)}"
                + "&format=jsonv2"
                + "&addressdetails=1"
                + $"&limit={limit}"
                + "&countrycodes=tr"
                + $"&viewbox={West.ToString(CultureInfo.InvariantCulture)},{North.ToString(CultureInfo.InvariantCulture)},{East.ToString(CultureInfo.InvariantCulture)},{South.ToString(CultureInfo.InvariantCulture)}"
                + "&bounded=1";

            using var response = await _httpClient.GetAsync(path, cancellationToken);
            response.EnsureSuccessStatusCode();
            var payload = await response.Content.ReadFromJsonAsync<NominatimItem[]>(
                GeocoderJsonOptions,
                cancellationToken: cancellationToken) ?? [];

            var results = payload
                .Select(ToLocationResult)
                .Where(item => item is not null)
                .Select(item => item!)
                .DistinctBy(item => item.Id)
                .Take(limit)
                .ToArray();

            _cache.Set(cacheKey, results, CacheDuration);
            return results;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception) when (exception is HttpRequestException
                                          or TaskCanceledException
                                          or JsonException)
        {
            throw new LocationSearchUnavailableException(
                "Adres arama servisine şu anda ulaşılamıyor.",
                exception);
        }
        finally
        {
            GeocoderGate.Release();
        }
    }

    private static LocationSearchResultDto? ToLocationResult(NominatimItem item)
    {
        if (!TryParseInvariant(item.Lat, out var latitude)
            || !TryParseInvariant(item.Lon, out var longitude)
            || !IsInsideCankayaEnvelope(latitude, longitude)
            || string.IsNullOrWhiteSpace(item.DisplayName))
        {
            return null;
        }

        LocationBoundsDto? bounds = null;
        if (item.Boundingbox is { Length: 4 }
            && TryParseInvariant(item.Boundingbox[0], out var south)
            && TryParseInvariant(item.Boundingbox[1], out var north)
            && TryParseInvariant(item.Boundingbox[2], out var west)
            && TryParseInvariant(item.Boundingbox[3], out var east))
        {
            bounds = new LocationBoundsDto(south, west, north, east);
        }

        var addressType = item.Addresstype ?? item.Type ?? string.Empty;
        var kind = addressType switch
        {
            "neighbourhood" or "quarter" or "suburb" => "neighborhood",
            "house" or "building" or "road" or "residential" => "address",
            _ => "place",
        };

        var neighborhood = GetAddressPart(item.Address, "neighbourhood")
            ?? GetAddressPart(item.Address, "quarter")
            ?? GetAddressPart(item.Address, "suburb");
        var id = item.OsmId is not null
            ? $"osm:{item.OsmType ?? "item"}:{item.OsmId}"
            : $"nominatim:{item.PlaceId}";

        return new LocationSearchResultDto(
            id,
            item.DisplayName,
            kind,
            latitude,
            longitude,
            bounds,
            neighborhood,
            "nominatim");
    }

    private static string? GetAddressPart(
        IReadOnlyDictionary<string, string>? address,
        string key) =>
        address is not null && address.TryGetValue(key, out var value) ? value : null;

    private static bool TryParseInvariant(string? value, out double result) =>
        double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out result);

    private static bool IsInsideCankayaEnvelope(double latitude, double longitude) =>
        latitude is >= South and <= North && longitude is >= West and <= East;

    private static string NormalizeForSearch(string value)
    {
        var decomposed = value.Trim().ToLowerInvariant().Replace('ı', 'i').Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(decomposed.Length);

        foreach (var character in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(character) != UnicodeCategory.NonSpacingMark)
            {
                builder.Append(character);
            }
        }

        return builder.ToString().Normalize(NormalizationForm.FormC);
    }

    private sealed record NeighborhoodName(long Id, string Name);

    private sealed class NominatimItem
    {
        public long PlaceId { get; init; }
        public string? OsmType { get; init; }
        public long? OsmId { get; init; }
        public string? Lat { get; init; }
        public string? Lon { get; init; }
        public string? DisplayName { get; init; }
        public string? Type { get; init; }
        public string? Addresstype { get; init; }
        public string[]? Boundingbox { get; init; }
        public Dictionary<string, string>? Address { get; init; }
    }
}
