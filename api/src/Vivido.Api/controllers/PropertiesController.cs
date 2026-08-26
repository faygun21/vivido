using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Api.services; // PropertyScoringService namespace'i
using Vivido.Application.dtos.property; // DTO'ların
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/properties")]
[Authorize]
public class PropertiesController : ControllerBase
{
    private readonly VividoDbContext _context;
    private readonly PropertyScoringService _scoringService;
    private readonly PropertyScoreBreakdownService _breakdownService;
    private readonly PropertyAddressService _addressService;

    public PropertiesController(
        VividoDbContext context,
        PropertyScoringService scoringService,
        PropertyScoreBreakdownService breakdownService,
        PropertyAddressService addressService)
    {
        _context = context;
        _scoringService = scoringService;
        _breakdownService = breakdownService;
        _addressService = addressService;
    }

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
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<PropertyMapItemDto>>> GetPropertiesForMap()
    {
        var profile = await GetProfileAsync();
        if (profile == null) return ApiProblem.ProfileNotFound();

        var properties = await BudgetFilteredQuery(profile).ToListAsync();

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

        return Ok(sortedItems);
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
    public async Task<ActionResult<IEnumerable<PropertySummaryDto>>> GetTopProperties(
        [FromQuery] int limit = DefaultTopLimit,
        CancellationToken ct = default)
    {
        var profile = await GetProfileAsync(ct);
        if (profile == null) return ApiProblem.ProfileNotFound();

        limit = Math.Clamp(limit, 1, MaxTopLimit);

        var properties = await BudgetFilteredQuery(profile).ToListAsync(ct);
        if (properties.Count == 0) return Ok(Array.Empty<PropertySummaryDto>());

        var scores = await _scoringService.ScorePropertiesAsync(
            properties.Select(p => p.Id).ToList(), profile.Id);

        var top = properties
            .OrderByDescending(p => scores.GetValueOrDefault(p.Id, 0.0))
            // Eşit skorlu evlerde sıra rastgele olmasın: aynı istek iki kez
            // atıldığında liste zıplarsa kullanıcı "veri değişti" sanır.
            .ThenBy(p => p.Id)
            .Take(limit)
            .ToList();

        var topIds = top.Select(p => p.Id).ToList();

        var addresses = await _addressService.GetAddressesAsync(topIds, ct);
        var breakdowns = await _breakdownService.GetBreakdownsAsync(topIds, profile.Id, ct);
        var favoriteIds = await GetFavoriteIdsAsync(profile.UserId, topIds, ct);

        var items = top.Select(p =>
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
        });

        return Ok(items);
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
            ?? new PropertyScoreBreakdownService.Breakdown(0, [], [], []);

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
                    profile.MaxMonthlyBudget)),
            IsFavorite: favoriteIds.Contains(property.Id),
            IsSynthetic: property.IsSynthetic);

        return Ok(detail);
    }

    /// <summary>
    /// Spesifik skor sorgulama ucu
    /// </summary>
    [HttpGet("{propertyId:long}/score")]
    public async Task<IActionResult> GetPropertyScore(long propertyId, [FromQuery] Guid profileId)
    {
        if (profileId == Guid.Empty)
        {
            return BadRequest(new { Message = "Geçerli bir profileId belirtilmelidir." });
        }

        try
        {
            var score = await _scoringService.ScorePropertyAsync(propertyId, profileId);

            return Ok(new
            {
                PropertyId = propertyId,
                ProfileId = profileId,
                Score = score
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { Message = "Skor hesaplanırken sunucu tarafında bir hata oluştu.", Details = ex.Message });
        }
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
