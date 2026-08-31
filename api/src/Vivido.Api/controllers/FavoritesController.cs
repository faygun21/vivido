using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Api.services;
using Vivido.Application.dtos.property;
using Vivido.Application.Dtos.Profile;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/profile/favorites")]
[Authorize] // Bu endpointler sadece giriş yapmış kullanıcılara açık
public class FavoritesController : ControllerBase
{
    private readonly VividoDbContext _context;
    private readonly PropertyScoringService _scoringService;
    private readonly PropertyScoreBreakdownService _breakdownService;
    private readonly PropertyAddressService _addressService;

    public FavoritesController(
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

    private Guid GetUserId()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.Parse(userIdStr!);
    }

    private const int DefaultPageSize = 50;
    private const int MaxPageSize = 100;

    // GET: /api/v1/profile/favorites
    /// <summary>
    /// Favori konutlar — kart basmaya yetecek kadar bilgiyle.
    ///
    /// Eskiden yalnızca `propertyId` dönüyordu; profil sayfası "Ev ID: 4213"
    /// yazmak zorundaydı. Artık kira, oda, adres ve skor da geliyor.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetFavorites(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = DefaultPageSize,
        CancellationToken ct = default)
    {
        var userId = GetUserId();
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, MaxPageSize);

        var query = _context.FavoriteProperties
            .AsNoTracking()
            .Where(f => f.UserId == userId)
            .OrderByDescending(f => f.CreatedAt); // En son eklenen en üstte

        var totalCount = await query.CountAsync(ct);

        var favorites = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(f => new { f.PropertyId, f.CreatedAt })
            .ToListAsync(ct);

        Response.Headers["X-Total-Count"] = totalCount.ToString();
        Response.Headers["X-Page"] = page.ToString();
        Response.Headers["X-Page-Size"] = pageSize.ToString();

        if (favorites.Count == 0)
            return Ok(Array.Empty<FavoriteResponse>());

        var ids = favorites.Select(f => f.PropertyId).ToList();

        var properties = await _context.Properties
            .AsNoTracking()
            .Where(p => ids.Contains(p.Id))
            .ToDictionaryAsync(p => p.Id, ct);

        var addresses = await _addressService.GetAddressesAsync(ids, ct);

        // Profil yoksa (onboarding tamamlanmamış) skor hesaplanamaz — favori
        // listesi yine de açılmalı, sadece skor alanı 0 kalır.
        var profile = await _context.UserProfiles
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.UserId == userId, ct);

        var scores = profile is null
            ? new Dictionary<long, double>()
            : await _scoringService.ScorePropertiesAsync(ids, profile.Id);

        var breakdowns = profile is null
            ? new Dictionary<long, PropertyScoreBreakdownService.Breakdown>()
            : await _breakdownService.GetBreakdownsAsync(ids, profile.Id, ct);

        var response = favorites.Select(f =>
        {
            properties.TryGetValue(f.PropertyId, out var property);
            var score = scores.GetValueOrDefault(f.PropertyId, 0.0);
            breakdowns.TryGetValue(f.PropertyId, out var breakdown);

            return new FavoriteResponse
            {
                PropertyId = f.PropertyId,
                CreatedAt = f.CreatedAt,
                Property = property is null ? null : new PropertySummaryDto(
                    Id: property.Id.ToString(),
                    ExternalRef: property.ExternalRef,
                    MonthlyRent: property.MonthlyRent,
                    AreaM2: property.AreaM2,
                    RoomCount: property.RoomCount,
                    Latitude: property.Geom.Y,
                    Longitude: property.Geom.X,
                    TotalScore: score,
                    Band: PropertyScoreBreakdownService.BandOf(score),
                    Address: addresses.GetValueOrDefault(property.Id)
                             ?? new PropertyAddressDto(null, null, "Çankaya", "Ankara"),
                    TopStrength: breakdown?.Strengths.FirstOrDefault()?.Label,
                    TopWeakness: breakdown?.Weaknesses.FirstOrDefault()?.Label,
                    // Tanım gereği: bu liste zaten favorilerden oluşuyor.
                    IsFavorite: true),
            };
        });

        return Ok(response);
    }

    // POST: /api/v1/profile/favorites
    [HttpPost]
    public async Task<IActionResult> AddFavorite([FromBody] AddFavoriteRequest request, CancellationToken ct = default)
    {
        var userId = GetUserId();

        // Var olmayan bir konut favorilenirse FK ihlali 500 dönerdi; bu tam
        // olarak 404'tür.
        var exists = await _context.Properties.AnyAsync(p => p.Id == request.PropertyId, ct);
        if (!exists)
            return NotFound(new { message = "Konut bulunamadı." });

        var already = await _context.FavoriteProperties
            .AnyAsync(f => f.UserId == userId && f.PropertyId == request.PropertyId, ct);

        if (!already)
        {
            _context.FavoriteProperties.Add(new FavoriteProperty
            {
                UserId = userId,
                PropertyId = request.PropertyId
            });

            try
            {
                await _context.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                // Yarış durumu: kullanıcı kalp düğmesine iki kez hızlıca
                // bastı, iki istek de "yok" gördü. PK ihlali burada patlar —
                // ama sonuç kullanıcı açısından zaten istenen şey.
            }
        }

        return NoContent();
    }

    // DELETE: /api/v1/profile/favorites/{propertyId}
    [HttpDelete("{propertyId:long}")]
    public async Task<IActionResult> RemoveFavorite(long propertyId, CancellationToken ct = default)
    {
        var userId = GetUserId();

        var favorite = await _context.FavoriteProperties
            .FirstOrDefaultAsync(f => f.UserId == userId && f.PropertyId == propertyId, ct);

        if (favorite != null)
        {
            _context.FavoriteProperties.Remove(favorite);
            await _context.SaveChangesAsync(ct);
        }

        return NoContent(); // 204 başarıyla silindi
    }
}
