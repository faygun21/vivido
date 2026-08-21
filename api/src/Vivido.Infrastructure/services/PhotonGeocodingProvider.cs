using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Caching.Memory;
using Vivido.Application.dtos.location;

namespace Vivido.Infrastructure.Services;

/// <summary>Photon GeoJSON ileri geocoding API uyarlayıcısı.</summary>
public sealed class PhotonGeocodingProvider : IGeocodingProvider
{
    private static readonly TimeSpan CacheDuration = TimeSpan.FromHours(24);
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    };

    private readonly HttpClient _httpClient;
    private readonly IMemoryCache _cache;

    public PhotonGeocodingProvider(HttpClient httpClient, IMemoryCache cache)
    {
        _httpClient = httpClient;
        _cache = cache;
    }

    public string Name => "photon";
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

        try
        {
            var path = "api/"
                + $"?q={Uri.EscapeDataString(query)}"
                + $"&limit={limit}&countrycode=TR"
                + $"&bbox={Invariant(CankayaGeocodingBounds.West)},{Invariant(CankayaGeocodingBounds.South)},{Invariant(CankayaGeocodingBounds.East)},{Invariant(CankayaGeocodingBounds.North)}";
            using var response = await _httpClient.GetAsync(path, cancellationToken);
            response.EnsureSuccessStatusCode();
            var payload = await response.Content.ReadFromJsonAsync<PhotonResponse>(
                JsonOptions,
                cancellationToken) ?? new PhotonResponse();
            var results = payload.Features
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
                "Photon konum aramasını tamamlayamadı.",
                exception);
        }
    }

    private static LocationSearchResultDto? ToLocationResult(PhotonFeature item)
    {
        if (item.Geometry.Coordinates is not { Length: >= 2 } coordinates
            || !CankayaGeocodingBounds.Contains(coordinates[1], coordinates[0]))
        {
            return null;
        }

        var properties = item.Properties;
        var label = BuildLabel(properties);
        if (string.IsNullOrWhiteSpace(label))
        {
            return null;
        }

        LocationBoundsDto? bounds = null;
        if (properties.Extent is { Length: 4 } extent)
        {
            bounds = new LocationBoundsDto(
                Math.Min(extent[1], extent[3]),
                Math.Min(extent[0], extent[2]),
                Math.Max(extent[1], extent[3]),
                Math.Max(extent[0], extent[2]));
        }

        var osmValue = properties.OsmValue?.ToLowerInvariant();
        var kind = osmValue switch
        {
            "neighbourhood" or "quarter" or "suburb" => "neighborhood",
            _ when !string.IsNullOrWhiteSpace(properties.HouseNumber)
                || !string.IsNullOrWhiteSpace(properties.Street)
                || properties.OsmKey is "highway" or "building" => "address",
            _ => "place",
        };
        var id = properties.OsmId is not null
            ? $"photon:{properties.OsmType ?? "item"}:{properties.OsmId}"
            : $"photon:{Invariant(coordinates[0])}:{Invariant(coordinates[1])}";

        return new LocationSearchResultDto(
            id,
            label,
            kind,
            coordinates[1],
            coordinates[0],
            bounds,
            properties.District ?? properties.Locality,
            "photon");
    }

    private static string BuildLabel(PhotonProperties properties)
    {
        var streetAddress = string.Join(
            ' ',
            new[] { properties.Street, properties.HouseNumber }
                .Where(value => !string.IsNullOrWhiteSpace(value)));
        return string.Join(
            ", ",
            new[]
            {
                properties.Name,
                streetAddress,
                properties.District,
                properties.Locality,
                properties.City,
                properties.State,
                properties.Country,
            }
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Distinct(StringComparer.OrdinalIgnoreCase));
    }

    private static string Invariant(double value) => value.ToString(CultureInfo.InvariantCulture);

    private sealed class PhotonResponse
    {
        public PhotonFeature[] Features { get; init; } = [];
    }

    private sealed class PhotonFeature
    {
        public PhotonGeometry Geometry { get; init; } = new();
        public PhotonProperties Properties { get; init; } = new();
    }

    private sealed class PhotonGeometry
    {
        public double[] Coordinates { get; init; } = [];
    }

    private sealed class PhotonProperties
    {
        public string? Name { get; init; }
        public string? Street { get; init; }
        public string? HouseNumber { get; init; }
        public string? District { get; init; }
        public string? Locality { get; init; }
        public string? City { get; init; }
        public string? State { get; init; }
        public string? Country { get; init; }
        public string? OsmKey { get; init; }
        public string? OsmValue { get; init; }
        public string? OsmType { get; init; }
        public long? OsmId { get; init; }
        public double[]? Extent { get; init; }
    }
}
