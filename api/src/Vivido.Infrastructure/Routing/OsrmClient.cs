using System.Globalization;
using System.Net.Http.Json;
using System.Text.Json;

namespace Vivido.Infrastructure.Routing;

/// <summary>Koordinat — [lon, lat] sırasını iki ayrı alana bölerek karışıklığı önler.</summary>
public readonly record struct OsrmCoordinate(double Lon, double Lat);

/// <summary>
/// OSRM için yazılmış typed HttpClient.
///
/// · <see cref="GetTableAsync"/> — süre + mesafe matrisi (TSP girdisi, R-120)
/// · <see cref="GetRouteAsync"/> — tam geometri + manevra adımları (kalıcılık girdisi, R-123)
///
/// OSRM "code":"Ok" dönmezse ya da HTTP 200 değilse <c>null</c> döner — çağıran
/// 503 PROBLEM üretir. İstisna fırlatmaz: rota servisi düştüğünde istek 500'e
/// dönüp kullanıcıya çıplak hata göstermesin.
/// </summary>
public sealed class OsrmClient
{
    private readonly HttpClient _http;
    private readonly OsrmOptions _options;

    public OsrmClient(HttpClient http, OsrmOptions options)
    {
        _http = http;
        _options = options;
    }

    /// <summary>n x n süre/mesafe matrisi. Hücre <c>null</c> = OSRM o düğüme rota bulamadı.</summary>
    public Task<OsrmTableResult?> GetTableAsync(
        IReadOnlyList<OsrmCoordinate> coordinates,
        string profile,
        CancellationToken cancellationToken = default)
    {
        if (coordinates.Count < 2 || coordinates.Count > _options.MaxTableSize)
            return Task.FromResult<OsrmTableResult?>(null);

        var url = $"{BaseUrl(profile)}/table/v1/{profile}/{Join(coordinates)}?annotations=duration,distance";
        return SendAsync<OsrmTableResponse, OsrmTableResult>(url, cancellationToken, body =>
            body is { Code: "Ok" } && body.Durations is not null
                ? new OsrmTableResult
                {
                    Durations = body.Durations,
                    Distances = body.Distances ?? Array.Empty<double?[]>(),
                }
                : null);
    }

    /// <summary>İlk koordinattan son koordinata tam rota: geometri + bacak adımları.</summary>
    public Task<OsrmRouteResult?> GetRouteAsync(
        IReadOnlyList<OsrmCoordinate> coordinates,
        string profile,
        CancellationToken cancellationToken = default)
    {
        if (coordinates.Count < 2)
            return Task.FromResult<OsrmRouteResult?>(null);

        var url = $"{BaseUrl(profile)}/route/v1/{profile}/{Join(coordinates)}" +
                  "?steps=true&geometries=geojson&overview=full&annotations=duration,distance";
        return SendAsync<OsrmRouteResponse, OsrmRouteResult>(url, cancellationToken, body =>
        {
            var route = body?.Routes?.FirstOrDefault(r => r.Geometry is not null);
            if (body is not { Code: "Ok" } || route is null) return null;

            return new OsrmRouteResult
            {
                Distance = route.Distance,
                Duration = route.Duration,
                Geometry = route.Geometry!,
                Legs = route.Legs ?? new List<OsrmLeg>(),
            };
        });
    }

    private string BaseUrl(string profile) =>
        string.Equals(profile, RoutingProfile.Foot, StringComparison.OrdinalIgnoreCase)
            ? _options.FootUrl
            : _options.CarUrl;

    private static string Join(IReadOnlyList<OsrmCoordinate> coordinates) =>
        string.Join(';', coordinates.Select(c =>
            $"{c.Lon.ToString("F6", CultureInfo.InvariantCulture)},{c.Lat.ToString("F6", CultureInfo.InvariantCulture)}"));

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private async Task<TResult?> SendAsync<TResponse, TResult>(
        string url,
        CancellationToken cancellationToken,
        Func<TResponse?, TResult?> map)
        where TResult : class
    {
        try
        {
            using var response = await _http.GetAsync(url, cancellationToken);
            if (!response.IsSuccessStatusCode) return null;

            var body = await response.Content.ReadFromJsonAsync<TResponse>(JsonOptions, cancellationToken);
            return map(body);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            // OSRM ayakta değil / yanıt bozuk — çağıran 503 PROBLEM üretsin.
            return null;
        }
    }
}
