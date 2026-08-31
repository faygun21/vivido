using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;
using Vivido.Application.Dtos.Route;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;
using Vivido.Infrastructure.Routing;
using Vivido.RouteOptimization;
// ASP.NET Core'un `Microsoft.AspNetCore.Routing.Route`'u ile çakışmayı önler.
using RouteEntity = Vivido.Domain.Entities.Route;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/routes")]
[Authorize] // Sadece giriş yapmış kullanıcılar
public class RoutesController : ControllerBase
{
    private readonly VividoDbContext _context;
    private readonly OsrmClient _osrm;

    public RoutesController(VividoDbContext context, OsrmClient osrm)
    {
        _context = context;
        _osrm = osrm;
    }

    private Guid GetUserId()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.Parse(userIdStr!);
    }

    // GET: /api/v1/routes
    [HttpGet]
    public async Task<IActionResult> GetRoutes()
    {
        var userId = GetUserId();
        
        var routes = await _context.Routes
            .Where(r => r.UserId == userId)
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new RouteListResponse
            {
                Id = r.Id,
                Name = r.Name,
                Mode = r.Mode,
                TotalDistanceM = r.TotalDistanceM,
                TotalDurationS = r.TotalDurationS,
                CreatedAt = r.CreatedAt,
                StopCount = r.Stops.Count,
                ScheduledAt = r.ScheduledAt,
            })
            .ToListAsync();

        return Ok(routes);
    }

    // GET: /api/v1/routes/{id}
    [HttpGet("{id}")]
    public async Task<IActionResult> GetRoute(Guid id, CancellationToken cancellationToken)
    {
        var userId = GetUserId();

        var route = await _context.Routes
            .Include(r => r.Stops)
            .FirstOrDefaultAsync(r => r.Id == id && r.UserId == userId, cancellationToken);

        if (route == null)
        {
            return NotFound();
        }

        return Ok(await BuildDetailAsync(route, cancellationToken));
    }

    // POST: /api/v1/routes  (R-120: TSP + OSRM, R-123: kalıcılık)
    //
    // Akış (docs/01-PROJE-PLANI.md §7.2):
    //   1. Doğrula: 2–8 konut, konutlar veritabanında var mı, başlangıç koordinatı geçerli mi
    //   2. OSRM /table  → süre matrisi (başlangıç + konutlar)
    //   3. Held-Karp (Vivido.RouteOptimization) → sabit başlangıçlı en kısa ziyaret sırası
    //   4. OSRM /route  → tam geometri + bacak adımları (steps, geojson)
    //   5. routes + route_stops kaydet
    [HttpPost]
    [ProducesResponseType<RouteDetailResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status422UnprocessableEntity)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public Task<IActionResult> CreateRoute(
        [FromBody] CreateRouteRequest request,
        CancellationToken cancellationToken)
        => BuildRouteAsync(request, persist: true, cancellationToken);

    /// <summary>
    /// Rotayı HESAPLAR ama KAYDETMEZ (R-121).
    ///
    /// Akış değişikliği: kullanıcı önce rotayı görüp beğenmeli, kaydetmeye
    /// sonra karar vermeli. Eskiden `POST /routes` hesaplayıp anında
    /// kaydediyordu; beğenilmeyen her deneme "Kayıtlı Rotalarım"da çöp
    /// bırakıyordu.
    ///
    /// Yanıt <see cref="RouteDetailResponse"/> ile aynı şekilde ama
    /// <c>Id = Guid.Empty</c> ve <c>IsSaved = false</c>. Kaydetmek isteyen
    /// istemci aynı gövdeyi (istenirse `scheduledAt` ekleyerek)
    /// <c>POST /routes</c>'a gönderir.
    ///
    /// ⚠️ Kaydetme yeniden hesaplar. TSP ve OSRM aynı girdi için
    /// deterministik olduğundan sonuç birebir aynı çıkar; alternatifi
    /// istemcinin hesaplanmış geometriyi geri göndermesiydi — o da istemciye
    /// mesafe/süre uydurma imkânı verirdi.
    /// </summary>
    [HttpPost("preview")]
    [ProducesResponseType<RouteDetailResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status422UnprocessableEntity)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public Task<IActionResult> PreviewRoute(
        [FromBody] CreateRouteRequest request,
        CancellationToken cancellationToken)
        => BuildRouteAsync(request, persist: false, cancellationToken);

    private async Task<IActionResult> BuildRouteAsync(
        CreateRouteRequest request,
        bool persist,
        CancellationToken cancellationToken)
    {
        if (request is null)
            return ApiProblem.Build(422, "Rota isteği geçersiz", "ROUTE_VALIDATION_ERROR");

        var errors = new Dictionary<string, string[]>();

        // Ad yalnızca KAYDEDERKEN zorunlu. Önizlemede kullanıcı henüz ad
        // düşünmedi; istemesi, beğenmediği bir rota için ad uydurtmak olurdu.
        if (persist && string.IsNullOrWhiteSpace(request.Name))
            errors["name"] = new[] { "Rota adı zorunlu." };

        var propertyIds = request.PropertyIds;
        if (propertyIds is null || propertyIds.Count < RouteLimits.MinStops ||
            propertyIds.Count > RouteLimits.MaxStops)
        {
            return ApiProblem.RouteStopLimitExceeded(RouteLimits.MinStops, RouteLimits.MaxStops);
        }

        if (propertyIds.Distinct().Count() != propertyIds.Count)
            errors["propertyIds"] = new[] { "Aynı konut bir rotaya iki kez eklenemez." };

        var mode = string.IsNullOrWhiteSpace(request.Mode) ? "car" : request.Mode.ToLowerInvariant();
        if (mode is not ("car" or "foot"))
            errors["mode"] = new[] { "mode yalnızca 'car' ya da 'foot' olabilir." };

        var start = request.Start;
        if (start is null || start.Lat is < -90 or > 90 || start.Lon is < -180 or > 180)
            errors["start"] = new[] { "Geçerli bir başlangıç koordinatı gerekli." };

        if (errors.Count > 0)
            return ApiProblem.Validation(errors);

        // ─── Konutlar veritabanında var mı? ───
        var properties = await _context.Properties
            .AsNoTracking()
            .Where(p => propertyIds.Contains(p.Id))
            .ToDictionaryAsync(p => p.Id, cancellationToken);

        if (properties.Count != propertyIds.Count)
            return ApiProblem.Build(
                422,
                "Bazı konutlar bulunamadı",
                "ROUTE_VALIDATION_ERROR",
                "İstekteki konut id'lerinden en az biri veritabanında yok.");

        // ─── Koordinat listesi: [başlangıç, konutlar...] (istek sırası korunur) ───
        var coordinates = new List<OsrmCoordinate> { new(start!.Lon, start.Lat) };
        coordinates.AddRange(propertyIds.Select(id => new OsrmCoordinate(
            properties[id].Geom.X,
            properties[id].Geom.Y)));

        var profile = RoutingProfile.ForMode(mode);

        // ─── OSRM süre matrisi (başlangıç + konutlar) ───
        var table = await _osrm.GetTableAsync(coordinates, profile, cancellationToken);
        if (table is null)
            return ApiProblem.OsrmUnavailable();

        int nodeCount = coordinates.Count;
        var cost = new double[nodeCount, nodeCount];
        for (int i = 0; i < nodeCount; i++)
        {
            for (int j = 0; j < nodeCount; j++)
            {
                cost[i, j] = table.Durations[i]?[j] ?? double.PositiveInfinity;
            }
        }

        // ─── TSP: sabit başlangıç → en kısa ziyaret sırası ───
        // Node 0 her zaman başlangıç koordinatıdır.
        var tsp = TravelingSalesman.SolveFixedStart(cost, startIndex: 0);
        var orderedCoordinates = tsp.Path.Select(idx => coordinates[idx]).ToList();

        // ─── OSRM tam rota: geometri + bacak adımları ───
        var routeResult = await _osrm.GetRouteAsync(orderedCoordinates, profile, cancellationToken);
        if (routeResult is null)
            return ApiProblem.OsrmUnavailable();

        // ─── Rota nesnesi (önizlemede de kurulur, yalnızca KAYDEDİLMEZ) ───
        var route = new RouteEntity
        {
            Id = Guid.NewGuid(),
            UserId = GetUserId(),
            Name = string.IsNullOrWhiteSpace(request.Name) ? "Önizleme" : request.Name.Trim(),
            ScheduledAt = persist ? request.ScheduledAt : null,
            StartGeom = new Point(start.Lon, start.Lat) { SRID = 4326 },
            StartLabel = start.Label,
            Mode = mode,
            TotalDistanceM = (int)Math.Round(routeResult.Distance),
            TotalDurationS = (int)Math.Round(routeResult.Duration),
            Geometry = BuildLineString(routeResult.Geometry),
            Steps = JsonDocument.Parse(JsonSerializer.Serialize(
                new RouteStepsEnvelopeDto { Legs = BuildLegs(routeResult) },
                JsonSerializerOptions.Web)),
            CreatedAt = DateTime.UtcNow,
        };

        // Duraklar: path[0] başlangıçtır; path[i] (i≥1) konut indeksidir.
        // OSRM leg[i-1] = path[i-1] → path[i] bacak (mesafe/süre durakta saklanır).
        for (int i = 1; i < tsp.Path.Length; i++)
        {
            int legIndex = i - 1;
            route.Stops.Add(new RouteStop
            {
                Seq = (short)i,
                PropertyId = propertyIds[tsp.Path[i] - 1],
                ScoreSnapshot = null, // skor snapshot'ı Faz 2'de (scoring entegrasyonu)
                LegDistanceM = legIndex < routeResult.Legs.Count
                    ? (int)Math.Round(routeResult.Legs[legIndex].Distance)
                    : null,
                LegDurationS = legIndex < routeResult.Legs.Count
                    ? (int)Math.Round(routeResult.Legs[legIndex].Duration)
                    : null,
                VisitedAt = null,
            });
        }

        if (!persist)
        {
            // Önizleme: hiçbir şey yazılmıyor. `Id` boşaltılıyor ki istemci
            // yanlışlıkla `GET /routes/{id}` çağırmasın ya da kaydedilmiş
            // sansın.
            route.Id = Guid.Empty;
            var preview = await BuildDetailAsync(route, cancellationToken);
            preview.IsSaved = false;
            return Ok(preview);
        }

        _context.Routes.Add(route);
        await _context.SaveChangesAsync(cancellationToken);

        var detail = await BuildDetailAsync(route, cancellationToken);
        return CreatedAtAction(nameof(GetRoute), new { id = route.Id }, detail);
    }

    // DELETE: /api/v1/routes/{id}
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteRoute(Guid id)
    {
        var userId = GetUserId();

        var route = await _context.Routes
            .FirstOrDefaultAsync(r => r.Id == id && r.UserId == userId);

        if (route != null)
        {
            _context.Routes.Remove(route);
            await _context.SaveChangesAsync();
        }

        return NoContent(); // 204 Başarılı silme
    }

    // ─── Yardımcılar ───

    private async Task<RouteDetailResponse> BuildDetailAsync(
        RouteEntity route,
        CancellationToken cancellationToken)
    {
        var propertyIds = route.Stops.Select(s => s.PropertyId).Distinct().ToList();

        var neighborhoods = await _context.Neighborhoods
            .AsNoTracking()
            .ToDictionaryAsync(n => n.Id, n => n.Name, cancellationToken);

        var properties = await _context.Properties
            .AsNoTracking()
            .Where(p => propertyIds.Contains(p.Id))
            .ToDictionaryAsync(p => p.Id, cancellationToken);

        var stops = route.Stops.OrderBy(s => s.Seq).Select(s =>
        {
            properties.TryGetValue(s.PropertyId, out var property);
            return new RouteStopDetailDto
            {
                Seq = s.Seq,
                PropertyId = s.PropertyId,
                ScoreSnapshot = s.ScoreSnapshot,
                LegDistanceM = s.LegDistanceM,
                LegDurationS = s.LegDurationS,
                VisitedAt = s.VisitedAt,
                Property = property is null
                    ? new PropertySummaryDto()
                    : new PropertySummaryDto
                    {
                        MonthlyRent = property.MonthlyRent,
                        AreaM2 = property.AreaM2,
                        RoomCount = property.RoomCount,
                        Neighborhood = neighborhoods.TryGetValue(property.NeighborhoodId, out var name)
                            ? name
                            : null,
                        Lat = property.Geom.Y,
                        Lon = property.Geom.X,
                    },
            };
        }).ToList();

        return new RouteDetailResponse
        {
            Id = route.Id,
            Name = route.Name,
            Mode = route.Mode,
            TotalDistanceM = route.TotalDistanceM,
            TotalDurationS = route.TotalDurationS,
            CreatedAt = route.CreatedAt,
            StopCount = route.Stops.Count,
            ScheduledAt = route.ScheduledAt,
            // Önizleme yolu bunu sonradan false yapar; kayıtlı okumalarda doğru.
            IsSaved = true,
            Start = new CoordinateDto
            {
                Lat = route.StartGeom.Y,
                Lon = route.StartGeom.X,
                Label = route.StartLabel,
            },
            Geometry = ToGeoJson(route.Geometry),
            Stops = stops,
            Legs = ParseLegs(route.Steps),
        };
    }

    /// <summary>OSRM bacaklarını sözleşmedeki RouteLegDto listesine çevirir.</summary>
    private static List<RouteLegDto> BuildLegs(OsrmRouteResult route)
    {
        var legs = new List<RouteLegDto>();
        for (int i = 0; i < route.Legs.Count; i++)
        {
            var leg = route.Legs[i];
            var steps = (leg.Steps ?? new List<OsrmStep>()).Select(s => new RouteStepDto
            {
                Distance = s.Distance,
                Duration = s.Duration,
                Name = s.Name,
                Maneuver = new ManeuverDto
                {
                    Type = s.Maneuver?.Type ?? string.Empty,
                    Modifier = s.Maneuver?.Modifier,
                    Location = s.Maneuver?.Location ?? Array.Empty<double>(),
                    Exit = s.Maneuver?.Exit,
                },
                Geometry = ToGeoJson(s.Geometry),
            }).ToList();

            legs.Add(new RouteLegDto { Seq = i + 1, Steps = steps });
        }

        return legs;
    }

    /// <summary>DB `steps` jsonb sütununu geri bacak listesine çevirir.</summary>
    private static List<RouteLegDto> ParseLegs(JsonDocument steps)
    {
        if (steps is null) return new();

        try
        {
            var envelope = JsonSerializer.Deserialize<RouteStepsEnvelopeDto>(
                steps.RootElement.GetRawText(),
                JsonSerializerOptions.Web);
            return envelope?.Legs ?? new List<RouteLegDto>();
        }
        catch (JsonException)
        {
            return new List<RouteLegDto>();
        }
    }

    private static LineString BuildLineString(OsrmLineStringGeometry geometry)
    {
        var points = geometry.Coordinates
            .Where(c => c is { Length: >= 2 })
            .Select(c => new Coordinate(c[0], c[1])) // GeoJSON [lon, lat] → NTS (X=lon, Y=lat)
            .ToArray();
        return new LineString(points) { SRID = 4326 };
    }

    private static LineStringGeoDto ToGeoJson(LineString lineString)
    {
        var dto = new LineStringGeoDto();
        foreach (var coordinate in lineString.Coordinates)
        {
            dto.Coordinates.Add(new[] { coordinate.X, coordinate.Y });
        }

        return dto;
    }

    private static LineStringGeoDto ToGeoJson(OsrmLineStringGeometry? geometry)
    {
        var dto = new LineStringGeoDto();
        if (geometry?.Coordinates is not null)
        {
            dto.Coordinates = geometry.Coordinates;
        }

        return dto;
    }
}