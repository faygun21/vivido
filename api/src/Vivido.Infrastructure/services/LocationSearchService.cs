using System.Globalization;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Vivido.Application.dtos.location;
using Vivido.Infrastructure.Data;

namespace Vivido.Infrastructure.Services;

/// <summary>Yerel mahalle aramasını dış geocoding sağlayıcılarıyla birleştirir.</summary>
public sealed class LocationSearchService : ILocationSearchService
{
    private const string OpenStreetMapAttribution = "© OpenStreetMap contributors";
    private readonly VividoDbContext _context;
    private readonly IReadOnlyList<IGeocodingProvider> _providers;
    private readonly ILogger<LocationSearchService> _logger;

    public LocationSearchService(
        VividoDbContext context,
        IEnumerable<IGeocodingProvider> providers,
        ILogger<LocationSearchService> logger)
    {
        _context = context;
        _providers = providers.ToArray();
        _logger = logger;
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

        if (neighborhoodResults.Count > 0)
        {
            return new LocationSearchResponseDto(
                neighborhoodResults,
                OpenStreetMapAttribution);
        }

        var successfulProviderCount = 0;
        var attribution = OpenStreetMapAttribution;

        foreach (var provider in _providers)
        {
            try
            {
                var results = await provider.SearchAsync(
                    trimmedQuery,
                    limit,
                    cancellationToken);
                successfulProviderCount++;
                attribution = provider.Attribution;

                if (results.Count > 0)
                {
                    return new LocationSearchResponseDto(results, attribution);
                }
            }
            catch (GeocodingProviderException exception)
            {
                // Sağlayıcı zincirindeki sıradaki uygulama aynı sözleşmeyi dener.
                _logger.LogWarning(
                    exception,
                    "{ProviderName} konum sağlayıcısı başarısız; sıradaki sağlayıcı deneniyor.",
                    provider.Name);
            }
        }

        if (_providers.Count > 0 && successfulProviderCount == 0)
        {
            throw new LocationSearchUnavailableException(
                "Konum arama sağlayıcılarına şu anda ulaşılamıyor.");
        }

        return new LocationSearchResponseDto([], attribution);
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
}
