using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using NetTopologySuite.Geometries;
using NetTopologySuite.Geometries.Utilities;
using Vivido.Api.services; // PropertyScoringService namespace'i
using Vivido.Application.dtos.property; // DTO'ların
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;
using Vivido.Infrastructure.Routing;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/properties")]
[Authorize]
public class PropertiesController : ControllerBase
{
    private const int MaximumPropertyCount = 2000;
    private readonly VividoDbContext _context;
    private readonly PropertyScoringService _scoringService;
    private readonly PropertyScoreBreakdownService _breakdownService;
    private readonly PropertyAddressService _addressService;
    private readonly OsrmClient _osrm;
    private readonly IMemoryCache _cache;

    public PropertiesController(
        VividoDbContext context,
        PropertyScoringService scoringService,
        PropertyScoreBreakdownService breakdownService,
        PropertyAddressService addressService,
        OsrmClient osrm,
        IMemoryCache cache)
    {
        _context = context;
        _scoringService = scoringService;
        _breakdownService = breakdownService;
        _addressService = addressService;
        _osrm = osrm;
        _cache = cache;
    }

    /// <summary>
    /// Anchor koridoru cache anahtarı — bkz. <see cref="BuildAnchorAreaAsync"/>.
    /// <see cref="AnchorsController"/> anchor CRUD sonrası aynı anahtarla
    /// invalide ediyor (bkz. oradaki not).
    /// </summary>
    internal static string CorridorCacheKey(Guid profileId) => $"anchor-corridor:{profileId}";

    /// <summary>
    /// "En uygun evler" listesinin varsayılan uzunluğu.
    /// Üst sınır ayrı: kullanıcı `limit=5000` yazıp tüm konutların adresini
    /// hesaplatarak isteği kilitleyebilmemeli.
    /// </summary>
    private const int DefaultTopLimit = 20;
    private const int MaxTopLimit = 50;

    /// <summary>
    /// 1. Harita ve Liste Görünümü (R-113, R-114):
    /// Kullanıcının aylık bütçesine uygun konutları getirir, her biri için skor hesaplar
    /// ve uygunluk skoruna göre yüksekten düşüğe (descending) sıralayıp harita ikonları için döner.
    ///
    /// ⚠️ <see cref="GetMapPropertiesByBounds"/> İLE KARIŞTIRMA: bu uç
    /// bbox almaz, kullanıcının bütçesine/anchor koridoruna göre TÜM
    /// eşleşen (skorlu) konutları döner — "kişiselleştirilmiş liste" ekseni.
    /// Diğeri viewport'a (bbox) göre ham/skorsuz konut noktalarını döner —
    /// "haritada görünen alan" ekseni. İkisi aynı veriye farklı iki filtre
    /// modeliyle bakıyor, birbirinin yerine geçmez.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<PropertiesMapResponseDto>> GetScoredProperties(
        // Kapalıyken (varsayılan) anchor koridoru uygulanır; kullanıcı
        // "Tüm evleri göster"i açtıysa true gönderilir.
        [FromQuery] bool showAll = false,
        CancellationToken ct = default)
    {
        var profile = await GetProfileAsync(ct);
        if (profile == null) return ApiProblem.ProfileNotFound();

        var budgetProperties = await BudgetFilteredQuery(profile).ToListAsync(ct);

        var (corridor, properties) = await BuildAnchorAreaBoundedAsync(profile, budgetProperties, showAll, ct);

        // Tek tek ScorePropertyAsync çağırmak N+1 sorgu demekti (profil,
        // ağırlık ve kategori her konut için ayrı ayrı çekiliyordu) — geniş
        // bütçe aralıklarında binlerce sıralı sorguya çıkıp isteği saniyelerce
        // kilitliyordu. Toplu metot bunları tek seferde çekip bellekte
        // eşliyor.
        var scores = await _scoringService.ScorePropertiesAsync(
            properties.Select(p => p.Id).ToList(), profile.Id);

        var mapItems = properties.Select(prop => new PropertyMapItemDto(
            prop.Id.ToString(),
            prop.MonthlyRent,
            prop.AreaM2,
            prop.RoomCount,
            prop.Geom.Y, // enlem
            prop.Geom.X, // boylam
            scores.GetValueOrDefault(prop.Id, 0.0)
        ));

        // Skorlarına göre yüksekten düşüğe sıralama (R-114)
        var sortedItems = mapItems.OrderByDescending(x => x.TotalScore).ToList();

        return Ok(new PropertiesMapResponseDto(
            sortedItems,
            corridor is null ? null : ToPolygonGeoJson(corridor)));
    }

    /// <summary>
    /// "En uygun evler" paneli: kullanıcının tercihlerine göre EN YÜKSEK
    /// skorlu konutlar, adres ve tek satırlık gerekçe özetiyle.
    ///
    /// ⚠️ Sıra kritik: ÖNCE hepsi skorlanır, SONRA sıralanır, EN SON kesilir.
    /// Önce kesip sonra skorlasaydık liste "en uygun 20" değil "rastgele
    /// 20'nin en uygunu" olurdu.
    ///
    /// Adres ve gerekçe kırılımı yalnızca kesilen ilk N konut için
    /// hesaplanıyor — 6.000 konutun tamamı için yapmak gereksiz iş.
    /// </summary>
    [HttpGet("top")]
    public async Task<ActionResult<TopPropertiesResponseDto>> GetTopProperties(
        [FromQuery] int limit = DefaultTopLimit,
        // Kapalıyken (varsayılan) anchor koridoru uygulanır; kullanıcı
        // "Tüm evleri göster"i açtıysa true gönderilir.
        [FromQuery] bool showAll = false,
        CancellationToken ct = default)
    {
        var profile = await GetProfileAsync(ct);
        if (profile == null) return ApiProblem.ProfileNotFound();

        limit = Math.Clamp(limit, 1, MaxTopLimit);

        // Bütçeye uygun TÜM evler — 6.000 satır civarı, bellekte filtrelemek
        // trivial (<10ms); ayrı bir SQL bbox turu gerektirmiyor.
        var budgetProperties = await BudgetFilteredQuery(profile).ToListAsync(ct);

        var (corridor, properties) = await BuildAnchorAreaBoundedAsync(profile, budgetProperties, showAll, ct);

        var corridorDto = corridor is null ? null : ToPolygonGeoJson(corridor);

        if (properties.Count == 0)
        {
            // Koridorda hiç ev yoksa (en genişletilmiş halinde bile) boş
            // liste yerine "en yakın uygun ev"i öneriyoruz — kullanıcı
            // "burada hiçbir şey yok" duvarına çarpmasın.
            if (corridor is not null && budgetProperties.Count > 0)
            {
                var centre = corridor.Centroid;
                var nearest = budgetProperties
                    .OrderBy(p => HaversineDistanceMetres(centre.Y, centre.X, p.Geom.Y, p.Geom.X))
                    .First();

                var fallbackSummaries = await BuildSummariesAsync([nearest], profile, ct);
                return Ok(new TopPropertiesResponseDto([], fallbackSummaries.SingleOrDefault(), corridorDto));
            }

            return Ok(new TopPropertiesResponseDto([], null, corridorDto));
        }

        var scores = await _scoringService.ScorePropertiesAsync(
            properties.Select(p => p.Id).ToList(), profile.Id);

        var top = properties
            .OrderByDescending(p => scores.GetValueOrDefault(p.Id, 0.0))
            // Eşit skorlu evlerde sıra rastgele olmasın: aynı istek iki kez
            // atıldığında liste zıplarsa kullanıcı "veri değişti" sanır.
            .ThenBy(p => p.Id)
            .Take(limit)
            .ToList();

        var items = await BuildSummariesAsync(top, profile, ct);

        return Ok(new TopPropertiesResponseDto(items, null, corridorDto));
    }

    /// <summary>
    /// Verilen konutlar için skor + adres + gerekçe özetini tek toplu
    /// sorgu turuyla <see cref="PropertySummaryDto"/> listesine çevirir.
    /// Hem "en iyi N" listesi hem de anchor alanı boşken tek bir "en yakın"
    /// önerisi İÇİN kullanılıyor — ikinci bir kopya olmasın diye.
    /// </summary>
    private async Task<List<PropertySummaryDto>> BuildSummariesAsync(
        IReadOnlyCollection<Property> properties, UserProfile profile, CancellationToken ct)
    {
        var ids = properties.Select(p => p.Id).ToList();

        var scores = await _scoringService.ScorePropertiesAsync(ids, profile.Id);
        var addresses = await _addressService.GetAddressesAsync(ids, ct);
        var breakdowns = await _breakdownService.GetBreakdownsAsync(ids, profile.Id, ct);
        var favoriteIds = await GetFavoriteIdsAsync(profile.UserId, ids, ct);

        return properties.Select(p =>
        {
            var score = scores.GetValueOrDefault(p.Id, 0.0);
            breakdowns.TryGetValue(p.Id, out var breakdown);

            return new PropertySummaryDto(
                Id: p.Id.ToString(),
                ExternalRef: p.ExternalRef,
                MonthlyRent: p.MonthlyRent,
                AreaM2: p.AreaM2,
                RoomCount: p.RoomCount,
                Latitude: p.Geom.Y,
                Longitude: p.Geom.X,
                TotalScore: score,
                Band: PropertyScoreBreakdownService.BandOf(score),
                Address: addresses.GetValueOrDefault(p.Id)
                         ?? new PropertyAddressDto(null, null, "Çankaya", "Ankara"),
                TopStrength: breakdown?.Strengths.FirstOrDefault()?.Label,
                TopWeakness: breakdown?.Weaknesses.FirstOrDefault()?.Label,
                IsFavorite: favoriteIds.Contains(p.Id));
        }).ToList();
    }

    /// <summary>
    /// 2. Konut Detay Paneli (R-115, R-118, R-33, W6):
    /// Haritada bir konut ikonuna tıklandığında açılan panel — mimari
    /// bilgiler, adres, favori durumu ve skorun SATIR SATIR gerekçesi.
    /// </summary>
    [HttpGet("{id:long}")]
    public async Task<ActionResult<PropertyDetailDto>> GetPropertyDetail(long id, CancellationToken ct = default)
    {
        var profile = await GetProfileAsync(ct);
        if (profile == null) return ApiProblem.ProfileNotFound();

        var property = await _context.Properties
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == id, ct);

        if (property == null)
            return NotFound(new { message = "Konut bulunamadı." });

        var breakdowns = await _breakdownService.GetBreakdownsAsync(new[] { id }, profile.Id, ct);
        var address = await _addressService.GetAddressAsync(id, ct);
        var favoriteIds = await GetFavoriteIdsAsync(profile.UserId, new[] { id }, ct);

        // Kırılım hesaplanamadıysa (profil silinmiş gibi bir sınır durumu)
        // panel skorsuz açılsın; 500 dönmek kullanıcıya hiçbir şey anlatmaz.
        var breakdown = breakdowns.GetValueOrDefault(id)
            ?? new PropertyScoreBreakdownService.Breakdown(0, [], [], [], null);

        var detail = new PropertyDetailDto(
            Id: property.Id.ToString(),
            ExternalRef: property.ExternalRef,
            MonthlyRent: property.MonthlyRent,
            AreaM2: property.AreaM2,
            RoomCount: property.RoomCount,
            Latitude: property.Geom.Y,
            Longitude: property.Geom.X,
            Address: address,
            Features: new PropertyFeaturesDto(
                property.FloorNo,
                property.TotalFloors,
                property.BuildingAge,
                property.HasElevator,
                property.HasParking,
                property.IsFurnished,
                property.PetsAllowed,
                property.RentPerM2,
                property.Deposit),
            Score: new PropertyScoreDetailDto(
                Total: breakdown.Total,
                Band: PropertyScoreBreakdownService.BandOf(breakdown.Total),
                Rows: breakdown.Rows,
                Strengths: breakdown.Strengths,
                Weaknesses: breakdown.Weaknesses,
                Budget: PropertyScoreBreakdownService.BuildBudgetFit(
                    property.MonthlyRent,
                    profile.MinMonthlyBudget,
                    profile.MaxMonthlyBudget),
                WeakLink: breakdown.WeakLink),
            IsFavorite: favoriteIds.Contains(property.Id),
            IsSynthetic: property.IsSynthetic);

        return Ok(detail);
    }

    /// <summary>
    /// Spesifik skor sorgulama ucu.
    ///
    /// ⚠️ Beklenmeyen hatalar burada YAKALANMAZ — eskiden `ex.Message` doğrudan
    /// istemciye dönüyordu (SQL/EF iç detaylarını sızdırma riski, ayrıca
    /// `ApiProblem` sözleşmesini hiç kullanmıyordu). Artık Program.cs'teki
    /// global exception handler'a düşer: detay sızdırmadan INTERNAL_ERROR
    /// döner, tam hata sunucu tarafında loglanır.
    ///
    /// ⚠️ `profileId` İSTEKTEN ALINMAZ: eskiden query string'ten geliyordu,
    /// yani giriş yapmış HERHANGİ bir kullanıcı başkasının profileId'sini
    /// vererek onun skorunu çekebiliyordu (broken object-level authorization).
    /// Artık dosyadaki diğer her action gibi JWT'deki kullanıcıdan türetilir.
    /// </summary>
    [HttpGet("{propertyId:long}/score")]
    public async Task<IActionResult> GetPropertyScore(long propertyId, CancellationToken ct = default)
    {
        var profile = await GetProfileAsync(ct);
        if (profile == null) return ApiProblem.ProfileNotFound();

        var score = await _scoringService.ScorePropertyAsync(propertyId, profile.Id);

        return Ok(new
        {
            PropertyId = propertyId,
            ProfileId = profile.Id,
            Score = score
        });
    }

    /// <summary>
    /// R-109/R-110 — harita görünüm alanındaki (bbox) konutları döndürür.
    /// Konut noktaları herkese açık harita verisidir ([AllowAnonymous]);
    /// skor hesaplama ayrıca <c>profileId</c> ister.
    /// </summary>
    [HttpGet("map")]
    [AllowAnonymous]
    // Kimlik doğrulama istemediği için [AllowAnonymous] uçlar arasında en
    // kolay kötüye kullanılabilecek olanı — IP başına dakikada 120 istekle sınırlı.
    [EnableRateLimiting("public-map")]
    [ProducesResponseType<List<MapPropertyDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GetMapPropertiesByBounds(
        [FromQuery] double west,
        [FromQuery] double south,
        [FromQuery] double east,
        [FromQuery] double north,
        CancellationToken cancellationToken)
    {
        if (west < -180 || east > 180 || south < -90 || north > 90 || west >= east || south >= north)
        {
            ModelState.AddModelError("bbox",
                "Geçerli bir sınırlayıcı kutu gerekli: -180 ≤ west < east ≤ 180 ve -90 ≤ south < north ≤ 90.");
        }

        if (!ModelState.IsValid)
        {
            return ApiProblem.Validation(ModelState.ToDictionary(
                kvp => kvp.Key,
                kvp => kvp.Value!.Errors.Select(e => e.ErrorMessage).ToArray()));
        }

        // SRID 4326'da bbox poligonu: GiST indeksini kullanan ST_Intersects ile eşleşir.
        var boundsGeom = new GeometryFactory(new PrecisionModel(), 4326)
            .ToGeometry(new Envelope(west, east, south, north));

        var items = await _context.Properties
            .AsNoTracking()
            .Where(p => p.Geom.Intersects(boundsGeom))
            .OrderBy(p => p.Id)
            .Take(MaximumPropertyCount)
            .Select(p => new MapPropertyDto(
                p.Id,
                p.ExternalRef,
                p.Geom.Y,
                p.Geom.X,
                p.MonthlyRent,
                p.AreaM2,
                p.RoomCount,
                p.BuildingAge,
                p.HasElevator,
                p.IsSynthetic))
            .ToListAsync(cancellationToken);

        return Ok(items);
    }

    // ══════════════════════════════════════════════════════════════
    //  Ortak yardımcılar
    // ══════════════════════════════════════════════════════════════

    private async Task<UserProfile?> GetProfileAsync(CancellationToken ct = default)
    {
        var userIdString = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(userIdString, out var userId)) return null;

        return await _context.UserProfiles
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.UserId == userId, ct);
    }

    /// <summary>
    /// Bütçe aralığı süzgeci — harita ve "en uygun evler" AYNI kümeye
    /// bakmalı. İki yerde ayrı yazılsaydı biri güncellendiğinde listedeki ev
    /// haritada görünmeyebilirdi.
    /// </summary>
    private IQueryable<Property> BudgetFilteredQuery(UserProfile profile)
    {
        var query = _context.Properties.AsNoTracking().AsQueryable();

        if (profile.MinMonthlyBudget.HasValue)
            query = query.Where(p => p.MonthlyRent >= profile.MinMonthlyBudget.Value);

        if (profile.MaxMonthlyBudget.HasValue)
            query = query.Where(p => p.MonthlyRent <= profile.MaxMonthlyBudget.Value);

        return query;
    }

    /// <summary>
    /// İki nokta arasındaki büyük daire (jeodezik) mesafesi, metre cinsinden.
    /// Koridor boşken "en yakın uygun ev"i bulmak için kullanılıyor.
    /// </summary>
    private static double HaversineDistanceMetres(double lat1, double lon1, double lat2, double lon2)
    {
        const double earthRadiusMetres = 6_371_008.8;
        var lat1Rad = lat1 * Math.PI / 180.0;
        var lat2Rad = lat2 * Math.PI / 180.0;
        var dLat = (lat2 - lat1) * Math.PI / 180.0;
        var dLon = (lon2 - lon1) * Math.PI / 180.0;

        var sinDLat = Math.Sin(dLat / 2);
        var sinDLon = Math.Sin(dLon / 2);
        var h = sinDLat * sinDLat + Math.Cos(lat1Rad) * Math.Cos(lat2Rad) * sinDLon * sinDLon;

        return 2 * earthRadiusMetres * Math.Asin(Math.Sqrt(Math.Min(1, h)));
    }

    // ══════════════════════════════════════════════════════════════
    //  Anchor koridoru — R-anchor-corridor
    //
    //  Mentor geri bildirimi: sabit yarıçaplı bir daire yerine, anchor'lar
    //  arasındaki GERÇEK yolu (OSRM) hesaplayıp o rotanın etrafında bir
    //  "koridor" (buffer) oluşturmalıyız. Evler bu koridorda aranır; hiç
    //  bulunamazsa koridor genişletilip tekrar denenir.
    //
    //  ⭐ Karma mod (2026-08-27, mentor testinde bulundu): anchor'lar arası
    //  TEK bir profille (hep araç ya da hep yaya) tek parça rota istemek iki
    //  sorun çıkardı — (a) araç yol ağı ilçenin bazı bölgelerinde (kırsal
    //  kesimde) KOPUK; OSRM "NoRoute" dönünce eski kod iki anchor'ı düz bir
    //  çizgiyle birleştiriyordu (ConvexHull) — haritada gerçek bir yolu
    //  yokmuş gibi göstermek yerine VARMIŞ gibi gösteren, yanıltıcı bir
    //  şekildi; (b) yaya profili çoğu zaman bağlıydı ama anlamsız derecede
    //  uzun (40+ km) "gerçek ama saçma" rotalar üretebiliyordu. Çözüm: her
    //  bacak (bkz. aşağıdaki "merkez" kuralı) kendi başına değerlendirilir —
    //  normal harita uygulamalarının "kısa mesafeyi yürü, uzunu araçla
    //  bağla" mantığıyla aynı, bkz. <see cref="BuildCorridorLegsAsync"/>.
    //
    //  ⭐ Merkez anchor (1 numaralı öncelik) — anchor'ların AĞIRLIĞI yok,
    //  yalnızca kullanıcının belirlediği bir SIRASI var (1, 2, 3...).
    //  Bacaklar bu sırayı bir ZİNCİR gibi değil (1↔2, 2↔3), 1 numaralı
    //  (en önemli) anchor'ı MERKEZ alan bir YILDIZ gibi kurar: 1↔2, 1↔3, ...
    //  Sebep: kullanıcı için en önemli yer neresiyse ("okulum" gibi), evler
    //  ÖNCELİKLE oraya olan ulaşıma göre değerlendirilmeli — 2. ve 3.
    //  anchor'lar birbirlerine değil, her zaman 1. anchor'a bağlanır. Zincir
    //  modelinde ise ortadaki (2 numaralı) anchor hem 1'e hem 3'e bağlanan
    //  bir "ara durak" gibi davranıp bu önceliği bulanıklaştırırdı.
    // ══════════════════════════════════════════════════════════════

    /// <summary>1 derece enlemin metre karşılığı — WGS84'te sabit, boylam enleme göre değişir ama Çankaya ölçeğinde bu yaklaşıklık yeterli.</summary>
    private const double MetresPerDegreeLat = 111_320.0;

    private const int MaxCorridorWidenAttempts = 5;
    private const double FootInitialCorridorMetres = 400;
    private const double CarInitialCorridorMetres = 1500;

    /// <summary>
    /// Bunun ötesi makul bir yürüme mesafesi sayılmaz (~18-20 dk normal
    /// yürüyüş hızında) — bacak bundan uzunsa araç rotası denenir. Kısaysa
    /// ve yaya rotası varsa yaya tercih edilir: gerçek bir yürüyüş yolu,
    /// (araç ağı kopuk diye) uydurulacak bir çizgiden her zaman daha doğru
    /// bir koridor verir.
    /// </summary>
    private const double MaxWalkableLegMetres = 1500;

    private readonly record struct CorridorLeg(Geometry Geometry, double BaseWidthMetres);

    /// <summary>
    /// Kullanıcının anchor'larından (özel yer) bir "koridor" üretir ve
    /// verilen bütçeye-uygun evler arasından bu koridora düşenleri döner.
    ///
    /// AKIŞ:
    ///   1. Anchor yoksa: koridor yok, filtre yok — tüm evler döner.
    ///   2. Anchor'lar, 1 numaralı (en önemli) anchor'ı merkez alan
    ///      bacaklara bölünüp gerçek rotalara çevrilir
    ///      (bkz. <see cref="BuildCorridorLegsAsync"/>).
    ///   3. Her bacak KENDİ BAŞINA, çevresinde en az 1 ev bulana kadar (en
    ///      fazla <see cref="MaxCorridorWidenAttempts"/> kez) genişletilir —
    ///      bkz. <see cref="BuildWidenedLegPolygon"/>. Böylece kalabalık bir
    ///      bacağın erken doyması, ıssız bir bacağın hiç genişlememesine yol
    ///      açmaz.
    ///   4. Genişletilmiş bacaklar birleştirilir (union) — tek parça
    ///      (Polygon) ya da kopuk parçalardan oluşan (MultiPolygon) bir
    ///      koridor çıkabilir, ikisi de geçerli.
    ///
    /// ⚠️ GEÇİCİ: koridor şu an mentor'un gözle kontrol edebilmesi için
    /// dışarı (frontend'e) döndürülüyor — bkz. çağıranlardaki not.
    ///
    /// ⭐ CACHE (2026-08-31): kullanıcının anchor'ları (ev/iş yeri) neredeyse
    /// hiç değişmiyor, ama koridor öncesinde HER istekte (harita her
    /// hareket ettiğinde, panel her açıldığında) sıfırdan hesaplanıyordu —
    /// anchor sayısı kadar OSRM `/route` çağrısı + CPU-ağır NTS
    /// `Buffer`/`Union` işlemleri. 10 dakikalık TTL ile <see cref="IMemoryCache"/>'e
    /// yazılıyor; <see cref="AnchorsController"/> anchor CRUD'da aynı
    /// anahtarla invalide ediyor. Anahtar yalnızca profile.Id'ye bağlı —
    /// bütçe aralığı değişse bile (nadir) TTL süresi içinde eski koridor
    /// kullanılabilir; bu, "her istekte OSRM'e git" maliyetine karşı kabul
    /// edilebilir bir yaklaşıklık.
    /// </summary>
    /// <summary>
    /// Bir istekte kabul edilen üst sınır. <see cref="BuildAnchorAreaAsync"/>
    /// cache boşken (anchor CRUD sonrası ya da 10dk TTL bitince) ardışık en
    /// fazla 2×(anchor sayısı-1) OSRM çağrısı yapabiliyor — her biri kendi
    /// zaman aşımına (bkz. OsrmOptions) sahip olsa da toplamı çok
    /// uzayabiliyordu (3 anchor'da ~40sn'ye kadar), kullanıcıyı hiçbir geri
    /// bildirim vermeden bekletiyordu. Bu, RoutesController'daki
    /// RequestTimeout deseninin aynısı: aşılırsa koridor filtresi olmadan
    /// (bütçeye uygun TÜM evlerle) devam edilir, istek asla çıplak
    /// başarısız olmaz.
    /// </summary>
    private static readonly TimeSpan CorridorTimeout = TimeSpan.FromSeconds(15);

    private async Task<(Geometry? Corridor, List<Property> Matched)> BuildAnchorAreaBoundedAsync(
        UserProfile profile, List<Property> budgetProperties, bool showAll, CancellationToken ct)
    {
        if (showAll) return (null, budgetProperties);

        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeoutCts.CancelAfter(CorridorTimeout);

        try
        {
            return await BuildAnchorAreaAsync(profile, budgetProperties, timeoutCts.Token);
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            // İstemci iptal ETMEDİ — kendi üst sınırımız tetiklendi.
            return (null, budgetProperties);
        }
    }

    private async Task<(Geometry? Corridor, List<Property> Matched)> BuildAnchorAreaAsync(
        UserProfile profile, List<Property> budgetProperties, CancellationToken ct)
    {
        var anchors = await _context.Anchors
            .Where(a => a.ProfileId == profile.Id)
            .OrderBy(a => a.Priority)
            .AsNoTracking()
            .ToListAsync(ct);

        if (anchors.Count == 0) return (null, budgetProperties);

        var cacheKey = CorridorCacheKey(profile.Id);
        if (!_cache.TryGetValue(cacheKey, out Geometry? corridor))
        {
            var legs = await BuildCorridorLegsAsync(anchors, ct);

            // ⭐ Her bacak KENDİ BAŞINA genişler. Tek bir genel genişletme (tüm
            // bacakların birleşimine bakıp "birinde ev bulundu mu") kullansaydık,
            // güçlü bir bacak (çok ev olan bölge) hemen eşiği geçip döngüyü
            // durdurur, zayıf bir bacak (örn. kopuk anchor'ın kendi dairesi) hiç
            // genişlemeden dar kalırdı — o anchor'ın etrafında pratikte hiç ev
            // gösterilmemiş olurdu. Bunun yerine her bacak, kendi çevresinde en
            // az 1 ev bulana kadar (ya da MaxCorridorWidenAttempts sınırına
            // kadar — abartmasın diye) ayrı ayrı genişletiliyor, SONRA hepsi
            // birleştiriliyor.
            foreach (var leg in legs)
            {
                corridor = corridor is null
                    ? BuildWidenedLegPolygon(leg, budgetProperties)
                    : corridor.Union(BuildWidenedLegPolygon(leg, budgetProperties));
            }

            _cache.Set(cacheKey, corridor, TimeSpan.FromMinutes(10));
        }

        var matched = corridor is null
            ? budgetProperties
            : budgetProperties.Where(p => corridor.Intersects(p.Geom)).ToList();

        return (corridor, matched);
    }

    /// <summary>Bir bacağı, çevresinde en az 1 bütçeye-uygun ev bulana kadar (en fazla <see cref="MaxCorridorWidenAttempts"/> kez) genişletip buffer'lar.</summary>
    private static Geometry BuildWidenedLegPolygon(CorridorLeg leg, List<Property> budgetProperties)
    {
        var widthMetres = leg.BaseWidthMetres;
        var polygon = BufferMetres(leg.Geometry, widthMetres);

        for (var attempt = 0; attempt < MaxCorridorWidenAttempts - 1; attempt++)
        {
            if (budgetProperties.Any(p => polygon.Intersects(p.Geom))) break;

            widthMetres *= 2;
            polygon = BufferMetres(leg.Geometry, widthMetres);
        }

        return polygon;
    }

    /// <summary>
    /// Bir geometriyi GERÇEK dünyada (metre cinsinden) düzgün bir daire/şerit
    /// çıkaracak şekilde buffer'lar.
    ///
    /// ⚠️ Çıplak <c>geometry.Buffer(metres / MetresPerDegreeLat)</c> yanlıştı:
    /// NTS'in buffer'ı DERECE cinsinden çalışır ve 1 derecelik X (boylam) ile
    /// 1 derecelik Y (enlem) mesafesini EŞİT sanır. Oysa 1 boylam derecesi
    /// enleme göre KISALIR (Çankaya'nın ~39.9° enleminde bir enlem
    /// derecesinden yaklaşık %23 daha kısa). Sonuç: tek anchor'lu bir
    /// koridor gerçek haritada daire değil, doğu-batı yönünde SIKIŞMIŞ bir
    /// elips çıkıyordu — "her açıdan eşit değil" (2026-09-02, gözle
    /// bulundu).
    ///
    /// Düzeltme: X eksenini enlemin kosinüsüyle "geriyoruz" (bu uzayda 1
    /// birim X ile 1 birim Y artık gerçekten aynı mesafeyi temsil ediyor),
    /// dairesel buffer'ı bu gerilmiş uzayda alıyoruz, sonra geri
    /// sıkıştırıyoruz — sonuç gerçek dünyada doğru bir daire/şerit.
    /// </summary>
    private static Geometry BufferMetres(Geometry geometry, double metres)
    {
        var stretch = 1.0 / Math.Cos(geometry.Centroid.Y * Math.PI / 180.0);

        var stretched = AffineTransformation.ScaleInstance(stretch, 1.0).Transform(geometry);
        var buffered = stretched.Buffer(metres / MetresPerDegreeLat);
        return AffineTransformation.ScaleInstance(1.0 / stretch, 1.0).Transform(buffered);
    }

    /// <summary>
    /// Anchor'ları, 1 numaralı (en önemli) anchor'ı MERKEZ alan bacaklara
    /// bölüp gerçek OSRM rotalarına çevirir — her biri kendi buffer
    /// genişliğiyle.
    ///
    /// ⭐ YILDIZ, ZİNCİR DEĞİL: bacaklar (1↔2), (1↔3), ... şeklinde kuruluyor
    /// — ardışık ikili (1↔2, 2↔3) DEĞİL. Anchor'ların bir ağırlığı yok,
    /// sadece kullanıcının belirlediği bir önem SIRASI var; bu sıradaki en
    /// önemli (1.) anchor, evlerin değerlendirileceği asıl referans noktası.
    /// 2. ve 3. anchor'lar birbirine değil, her zaman 1. anchor'a bağlanır —
    /// "okuluma yakın, oradan da işe/arkadaşa nasıl gidilir" mantığı.
    ///
    /// Bacak başına sıra: (1) yaya rotası dene — kısaysa (≤
    /// <see cref="MaxWalkableLegMetres"/>) onu kullan; (2) uzunsa ya da yaya
    /// rota bulamadıysa araç rotası dene, bulursa onu kullan; (3) ikisi de
    /// olmadıysa (araç kısa yaya kadar makul değil, araç da yoksa) bacağın
    /// iki ucu KENDİ BAŞINA, kendi modlarına göre buffer'lanır — aralarına
    /// uzun/saçma bir "gerçek ama anlamsız" rota ya da sahte bir doğru
    /// çizmek yerine.
    ///
    /// Tek anchor varsa tek "bacak" o noktanın kendisidir.
    /// </summary>
    private async Task<List<CorridorLeg>> BuildCorridorLegsAsync(
        List<Anchor> anchors, CancellationToken ct)
    {
        if (anchors.Count == 1)
        {
            var only = anchors[0];
            return [new CorridorLeg(
                new Point(only.Geom.X, only.Geom.Y) { SRID = 4326 },
                only.Mode == "car" ? CarInitialCorridorMetres : FootInitialCorridorMetres)];
        }

        // `anchors` çağırandan Priority'ye göre sıralı geliyor (bkz.
        // BuildAnchorAreaAsync) — bu yüzden anchors[0] her zaman kullanıcının
        // 1 numara verdiği, en önemli anchor'dır: merkez bu.
        var hub = anchors[0];

        var legs = new List<CorridorLeg>();
        for (var i = 1; i < anchors.Count; i++)
        {
            var to = anchors[i];
            var coords = new List<OsrmCoordinate>
            {
                new(hub.Geom.X, hub.Geom.Y),
                new(to.Geom.X, to.Geom.Y),
            };

            var footRoute = await _osrm.GetRouteAsync(coords, RoutingProfile.Foot, ct);
            if (footRoute is not null && footRoute.Distance <= MaxWalkableLegMetres)
            {
                legs.Add(new CorridorLeg(BuildRouteLineString(footRoute.Geometry), FootInitialCorridorMetres));
                continue;
            }

            var carRoute = await _osrm.GetRouteAsync(coords, RoutingProfile.Driving, ct);
            if (carRoute is not null)
            {
                legs.Add(new CorridorLeg(BuildRouteLineString(carRoute.Geometry), CarInitialCorridorMetres));
                continue;
            }

            legs.Add(new CorridorLeg(
                new Point(hub.Geom.X, hub.Geom.Y) { SRID = 4326 },
                hub.Mode == "car" ? CarInitialCorridorMetres : FootInitialCorridorMetres));
            legs.Add(new CorridorLeg(
                new Point(to.Geom.X, to.Geom.Y) { SRID = 4326 },
                to.Mode == "car" ? CarInitialCorridorMetres : FootInitialCorridorMetres));
        }

        return legs;
    }

    /// <summary>OSRM GeoJSON LineString → NTS LineString. RoutesController'daki aynı dönüşümün küçük bir kopyası.</summary>
    private static LineString BuildRouteLineString(OsrmLineStringGeometry geometry)
    {
        var points = geometry.Coordinates
            .Where(c => c is { Length: >= 2 })
            .Select(c => new Coordinate(c[0], c[1])) // GeoJSON [lon, lat] → NTS (X=lon, Y=lat)
            .ToArray();
        return new LineString(points) { SRID = 4326 };
    }

    /// <summary>
    /// Koridor artık kopuk parçalardan oluşabilir (bkz.
    /// <see cref="BuildCorridorLegsAsync"/> — rota bulunamayan bacaklar ayrı
    /// birer daire olarak kalır) — bu yüzden her zaman MultiPolygon olarak
    /// dönüyor, tek parçalı koridorlar da 1 elemanlı bir MultiPolygon'a
    /// sarılıyor. Frontend'in tek bir GeoJSON tipiyle uğraşması yeterli.
    /// </summary>
    private static PolygonGeoJsonDto ToPolygonGeoJson(Geometry geometry)
    {
        var polygons = geometry switch
        {
            Polygon p => [p],
            MultiPolygon mp => mp.Geometries.Cast<Polygon>().ToList(),
            _ => [(Polygon)geometry.ConvexHull()],
        };

        var coordinates = polygons
            .Select(p => new List<List<double[]>>
            {
                p.ExteriorRing.Coordinates.Select(c => new[] { c.X, c.Y }).ToList(),
            })
            .ToList();

        return new PolygonGeoJsonDto("MultiPolygon", coordinates);
    }

    private async Task<HashSet<long>> GetFavoriteIdsAsync(
        Guid userId, IReadOnlyCollection<long> propertyIds, CancellationToken ct)
    {
        if (propertyIds.Count == 0) return [];

        var ids = await _context.FavoriteProperties
            .AsNoTracking()
            .Where(f => f.UserId == userId && propertyIds.Contains(f.PropertyId))
            .Select(f => f.PropertyId)
            .ToListAsync(ct);

        return ids.ToHashSet();
    }
}

