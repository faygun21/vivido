using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;
using Vivido.Api.services; // PropertyScoringService namespace'i
using Vivido.Application.dtos.property; // DTO'ların
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/properties")]
[Authorize]
public class PropertiesController : ControllerBase
{
    private const int MaximumPropertyCount = 2000;
    private readonly VividoDbContext _context;
    private readonly PropertyScoringService _scoringService;

    public PropertiesController(VividoDbContext context, PropertyScoringService scoringService)
    {
        _context = context;
        _scoringService = scoringService;
    }

    /// <summary>
    /// 1. Harita ve Liste Görünümü (R-113, R-114):
    /// Kullanıcının aylık bütçesine uygun konutları getirir, her biri için skor hesaplar
    /// ve uygunluk skoruna göre yüksekten düşüğe (descending) sıralayıp harita ikonları için döner.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<PropertyMapItemDto>>> GetPropertiesForMap()
    {
        var userIdString = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(userIdString, out var userId))
            return Unauthorized();

        var profile = await _context.UserProfiles
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.UserId == userId);

        if (profile == null)
            return ApiProblem.ProfileNotFound();

        var query = _context.Properties.AsNoTracking().AsQueryable();

        if (profile.MinMonthlyBudget.HasValue)
        {
            query = query.Where(p => p.MonthlyRent >= profile.MinMonthlyBudget.Value);
        }

        if (profile.MaxMonthlyBudget.HasValue)
        {
            query = query.Where(p => p.MonthlyRent <= profile.MaxMonthlyBudget.Value);
        }

        var properties = await query.ToListAsync();

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
    /// 2. Konut Detay Paneli (R-115, R-118, R-33):
    /// Haritada bir konut ikonuna tıklandığında açılan panel için mimari bilgileri ve skoru getirir.
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<PropertyDetailDto>> GetPropertyDetail(long id)
    {
        var userIdString = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(userIdString, out var userId))
            return Unauthorized();

        var profile = await _context.UserProfiles
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.UserId == userId);

        if (profile == null)
            return ApiProblem.ProfileNotFound();

        var property = await _context.Properties
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == id);

        if (property == null)
            return NotFound(new { message = "Konut bulunamadı." });

        var score = await _scoringService.ScorePropertyAsync(property.Id, profile.Id);

        var detailDto = new PropertyDetailDto(
            property.Id.ToString(),
            property.ExternalRef,
            property.MonthlyRent,
            property.AreaM2,
            property.RoomCount,
            property.Geom.Y, // enlem
            property.Geom.X, // boylam
            score,
            new Dictionary<string, double>()
        );

        return Ok(detailDto);
    }

    /// <summary>
    /// Spesifik skor sorgulama ucu
    /// </summary>
    [HttpGet("{propertyId}/score")]
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

    /// <summary>
    /// R-109/R-110 — harita görünüm alanındaki (bbox) konutları döndürür.
    /// Konut noktaları herkese açık harita verisidir ([AllowAnonymous]);
    /// skor hesaplama ayrıca <c>profileId</c> ister.
    /// </summary>
    [HttpGet("map")]
    [AllowAnonymous]
    [ProducesResponseType<List<MapPropertyDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GetPropertiesForMapByBounds(
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
}