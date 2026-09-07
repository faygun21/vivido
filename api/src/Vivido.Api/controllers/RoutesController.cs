using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
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
    /// <summary>
    /// Bir rota isteğine (OSRM /table + Held-Karp + OSRM /route toplamı)
    /// tanınan üst sınır. OSRM'in kendi zaman aşımı (10sn, bkz. OsrmOptions)
    /// zaten her tekil çağrıyı sınırlıyor ama akış İKİ OSRM çağrısı
    /// içeriyor — bu, TOPLAM isteğin (kullanıcının gördüğü bekleme) asla
    /// bu süreyi aşmamasını garanti eder.
    /// </summary>
    private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(15);

    /// <summary>Çift tıklama/ağ retry'ında aynı rotanın iki kez kaydedilmesini önleyen pencere.</summary>
    private static readonly TimeSpan IdempotencyWindow = TimeSpan.FromMinutes(5);

    private const int DefaultPageSize = 50;
    private const int MaxPageSize = 100;

    /// <summary>Rota adı ve başlangıç etiketi için üst sınır.</summary>
    private const int MaxNameLength = 120;

    private readonly VividoDbContext _context;
    private readonly OsrmClient _osrm;
    private readonly IMemoryCache _cache;

    public RoutesController(VividoDbContext context, OsrmClient osrm, IMemoryCache cache)
    {
        _context = context;
        _osrm = osrm;
        _cache = cache;
    }

    private Guid GetUserId()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.Parse(userIdStr!);
    }

    // GET: /api/v1/routes
    [HttpGet]
    public async Task<IActionResult> GetRoutes(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = DefaultPageSize,
        CancellationToken cancellationToken = default)
    {
        var userId = GetUserId();
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, MaxPageSize);

        var query = _context.Routes
            .Where(r => r.UserId == userId)
            .OrderByDescending(r => r.CreatedAt);

        var totalCount = await query.CountAsync(cancellationToken);

        var routes = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
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
            .ToListAsync(cancellationToken);

        // Yanıt şekli (düz dizi) bilerek KORUNUYOR — mevcut istemciler
        // değişmeden çalışmaya devam eder. Toplam sayı/sayfa header'da:
        // istemci ilerledikçe gerçek sayfalamaya (sayfa göstergesi, "daha
        // fazla yükle") header'ları okuyarak geçebilir.
        Response.Headers["X-Total-Count"] = totalCount.ToString();
        Response.Headers["X-Page"] = page.ToString();
        Response.Headers["X-Page-Size"] = pageSize.ToString();

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
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status504GatewayTimeout)]
    public async Task<IActionResult> CreateRoute(
        [FromBody] CreateRouteRequest request,
        CancellationToken cancellationToken)
    {
        // İsteğe bağlı idempotency: zayıf bağlantıda çift tıklama ya da bir
        // istemci retry'ı aynı isteği iki kez gönderebilir. İstemci bir
        // `Idempotency-Key` header'ı gönderirse, aynı anahtarla 5 dakika
        // içinde gelen ikinci istek YENİDEN HESAPLAMAZ/KAYDETMEZ — ilk
        // sonucu döner. Header yoksa davranış eskisiyle birebir aynı.
        var idempotencyKey = Request.Headers["Idempotency-Key"].FirstOrDefault();

        if (!string.IsNullOrWhiteSpace(idempotencyKey))
        {
            var cacheKey = IdempotencyCacheKey(GetUserId(), idempotencyKey);
            if (_cache.TryGetValue<Guid>(cacheKey, out var existingRouteId))
            {
                return await GetRoute(existingRouteId, cancellationToken);
            }
        }

        var result = await BuildRouteAsync(request, persist: true, cancellationToken);

        if (!string.IsNullOrWhiteSpace(idempotencyKey) &&
            result is CreatedAtActionResult { Value: RouteDetailResponse detail })
        {
            _cache.Set(IdempotencyCacheKey(GetUserId(), idempotencyKey), detail.Id, IdempotencyWindow);
        }

        return result;
    }

    private static string IdempotencyCacheKey(Guid userId, string idempotencyKey) =>
        $"route-idempotency:{userId}:{idempotencyKey}";

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
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status504GatewayTimeout)]
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

        // `routes.name` ve `routes.start_label` şemada sınırsız `text`. Üst
        // sınır olmadan istek gövdesi sınırına (~30 MB) kadar her şey kabul
        // edilip saklanıyordu — kullanıcı başına sınırsız rota ile birleşince
        // bedava disk doldurma. İkisi de listede ve rota detayında gösteriliyor.
        if (request.Name is { } name && name.Trim().Length > MaxNameLength)
            errors["name"] = new[] { $"Rota adı en fazla {MaxNameLength} karakter olabilir." };

        if (request.Start?.Label is { } startLabel &&
            startLabel.Trim().Length > MaxNameLength)
        {
            errors["start"] = new[]
            {
                $"Başlangıç etiketi en fazla {MaxNameLength} karakter olabilir."
            };
        }

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

        // ─── Toplam istek üst sınırı ───
        //
        // Akış İKİ ayrı OSRM çağrısı içeriyor (/table, sonra TSP çıktısına
        // bağlı /route) — her biri kendi zaman aşımına sahip olsa da (bkz.
        // OsrmOptions.TimeoutSeconds), TOPLAM bekleme süresi ikisinin
        // toplamına kadar çıkabilirdi. Bu, kullanıcının GERÇEKTEN gördüğü
        // (istek başından yanıta kadar) süreyi tek bir üst sınıra bağlar.
        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutCts.CancelAfter(RequestTimeout);
        var ct = timeoutCts.Token;

        try
        {
            // ─── Konutlar veritabanında var mı? ───
            var properties = await _context.Properties
                .AsNoTracking()
                .Where(p => propertyIds.Contains(p.Id))
                .ToDictionaryAsync(p => p.Id, ct);

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
            var table = await _osrm.GetTableAsync(coordinates, profile, ct);
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
            TravelingSalesman.TspResult tsp;
            try
            {
                tsp = TravelingSalesman.SolveFixedStart(cost, startIndex: 0);
            }
            catch (InvalidOperationException)
            {
                // OSRM'in bildiği yol ağında seçilen konutları birbirine
                // bağlayan bir yol yok (örn. kopuk bir bölge) — bu sunucu
                // hatası değil, kullanıcı farklı konut/başlangıç seçerek
                // çözebilir. Eskiden bu istisna hiçbir yerde yakalanmıyordu,
                // çıplak bir 500 olarak dönüyordu.
                return ApiProblem.RouteUnreachable();
            }

            var orderedCoordinates = tsp.Path.Select(idx => coordinates[idx]).ToList();

            // ─── OSRM tam rota: geometri + bacak adımları ───
            var routeResult = await _osrm.GetRouteAsync(orderedCoordinates, profile, ct);
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
                var preview = await BuildDetailAsync(route, ct);
                preview.IsSaved = false;
                return Ok(preview);
            }

            _context.Routes.Add(route);
            await _context.SaveChangesAsync(ct);

            var detail = await BuildDetailAsync(route, ct);
            return CreatedAtAction(nameof(GetRoute), new { id = route.Id }, detail);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            // İstemci iptal ETMEDİ — kendi üst sınırımız (RequestTimeout)
            // tetiklendi. İstemci gerçekten iptal ettiyse (sekme kapandı vb.)
            // burada bir yanıt üretmenin anlamı yok, o durumda yeniden fırlatılır.
            return ApiProblem.RouteTimeout();
        }
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