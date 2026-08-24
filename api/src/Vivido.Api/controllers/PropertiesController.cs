using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Api.services; // PropertyScoringService namespace'i
using Vivido.Application.dtos.property; // DTO'ların
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/properties")]
[Authorize]
public class PropertiesController : ControllerBase
{
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
        var mapItems = new List<PropertyMapItemDto>();

        foreach (var prop in properties)
        {
            // Orijinal servis metodunu kullanıyoruz
            var score = await _scoringService.ScorePropertyAsync(prop.Id, profile.Id);

            double lat = 39.9208; // Çankaya merkez örnek koordinat
            double lon = 32.8541;

            mapItems.Add(new PropertyMapItemDto(
                prop.Id.ToString(),
                prop.MonthlyRent,
                prop.AreaM2,
                prop.RoomCount,
                lat,
                lon,
                score
            ));
        }

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

        double lat = 39.9208;
        double lon = 32.8541;

        var detailDto = new PropertyDetailDto(
            property.Id.ToString(),
            property.ExternalRef,
            property.MonthlyRent,
            property.AreaM2,
            property.RoomCount,
            lat,
            lon,
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
}