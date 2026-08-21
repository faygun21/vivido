using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Caching.Memory;
using Vivido.Application.dtos.location;

namespace Vivido.Infrastructure.Services;

/// <summary>Nominatim ileri geocoding API uyarlayıcısı.</summary>
public sealed class NominatimGeocodingProvider : IGeocodingProvider
{
    private const string ProviderName = "nominatim";
    private static readonly TimeSpan CacheDuration = TimeSpan.FromHours(24);
    private static readonly TimeSpan MinimumRequestInterval = TimeSpan.FromSeconds(1);
    private static readonly SemaphoreSlim RequestGate = new(1, 1);
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };
    private static DateTimeOffset _lastRequest = DateTimeOffset.MinValue;

    private readonly HttpClient _httpClient;
    private readonly IMemoryCache _cache;

    public NominatimGeocodingProvider(HttpClient httpClient, IMemoryCache cache)
    {
        _httpClient = httpClient;
        _cache = cache;
    }

    public string Name => ProviderName;
    public string Attribution => "© OpenStreetMap contributors";

    public async Task<IReadOnlyList<LocationSearchResultDto>> SearchAsync(
        string query,
        int limit,
        CancellationToken cancellationToken = default)
    {
        var cacheKey = $"geocoding:{Name}:{query.Trim().ToLowerInvariant()}:{limit}";
        if (_cache.TryGetValue(cacheKey, out LocationSearchResultDto[]? cached) && cached is not null)
        {
            return cached;
        }

        await RequestGate.WaitAsync(cancellationToken);
        try
        {
            if (_cache.TryGetValue(cacheKey, out cached) && cached is not null)
            {
                return cached;
            }

            var elapsed = DateTimeOffset.UtcNow - _lastRequest;
            if (elapsed < MinimumRequestInterval)
            {
                await Task.Delay(MinimumRequestInterval - elapsed, cancellationToken);
            }

            _lastRequest = DateTimeOffset.UtcNow;
            var path = "search"
                + $"?q={Uri.EscapeDataString(query)}"
                + "&format=jsonv2&addressdetails=1"
                + $"&limit={limit}&countrycodes=tr"
                + $"&viewbox={Invariant(CankayaGeocodingBounds.West)},{Invariant(CankayaGeocodingBounds.North)},{Invariant(CankayaGeocodingBounds.East)},{Invariant(CankayaGeocodingBounds.South)}"
                + "&bounded=1";

            using var response = await _httpClient.GetAsync(path, cancellationToken);
            response.EnsureSuccessStatusCode();
            var payload = await response.Content.ReadFromJsonAsync<NominatimItem[]>(
                JsonOptions,
                cancellationToken) ?? [];
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
            throw new GeocodingProviderException(
                Name,
                "Nominatim konum aramasını tamamlayamadı.",
                exception);
        }
        finally
        {
            RequestGate.Release();
        }
    }

    private static LocationSearchResultDto? ToLocationResult(NominatimItem item)
    {
        if (!TryParse(item.Lat, out var latitude)
            || !TryParse(item.Lon, out var longitude)
            || !CankayaGeocodingBounds.Contains(latitude, longitude)
            || string.IsNullOrWhiteSpace(item.DisplayName))
        {
            return null;
        }

        LocationBoundsDto? bounds = null;
        if (item.Boundingbox is { Length: 4 }
            && TryParse(item.Boundingbox[0], out var south)
            && TryParse(item.Boundingbox[1], out var north)
            && TryParse(item.Boundingbox[2], out var west)
            && TryParse(item.Boundingbox[3], out var east))
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
            ProviderName);
    }

    private static string? GetAddressPart(
        IReadOnlyDictionary<string, string>? address,
        string key) =>
        address is not null && address.TryGetValue(key, out var value) ? value : null;

    private static string Invariant(double value) => value.ToString(CultureInfo.InvariantCulture);
    private static bool TryParse(string? value, out double result) =>
        double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out result);

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
