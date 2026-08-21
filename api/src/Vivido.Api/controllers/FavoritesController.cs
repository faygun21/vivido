using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
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

    public FavoritesController(VividoDbContext context)
    {
        _context = context;
    }

    private Guid GetUserId()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.Parse(userIdStr!);
    }

    // GET: /api/v1/profile/favorites
    [HttpGet]
    public async Task<IActionResult> GetFavorites()
    {
        var userId = GetUserId();
        var favorites = await _context.FavoriteProperties
            .Where(f => f.UserId == userId)
            .OrderByDescending(f => f.CreatedAt) // En son eklenen en üstte
            .Select(f => new FavoriteResponse
            {
                PropertyId = f.PropertyId,
                CreatedAt = f.CreatedAt
            })
            .ToListAsync();

        return Ok(favorites);
    }

    // POST: /api/v1/profile/favorites
    [HttpPost]
    public async Task<IActionResult> AddFavorite([FromBody] AddFavoriteRequest request)
    {
        var userId = GetUserId();
        
        // Zaten favorilere eklenmiş mi kontrolü
        var exists = await _context.FavoriteProperties
            .AnyAsync(f => f.UserId == userId && f.PropertyId == request.PropertyId);

        if (!exists)
        {
            var favorite = new FavoriteProperty
            {
                UserId = userId,
                PropertyId = request.PropertyId
            };
            _context.FavoriteProperties.Add(favorite);
            await _context.SaveChangesAsync();
        }

        return Ok(); 
    }

    // DELETE: /api/v1/profile/favorites/{propertyId}
    [HttpDelete("{propertyId}")]
    public async Task<IActionResult> RemoveFavorite(long propertyId)
    {
        var userId = GetUserId();
        
        var favorite = await _context.FavoriteProperties
            .FirstOrDefaultAsync(f => f.UserId == userId && f.PropertyId == propertyId);

        if (favorite != null)
        {
            _context.FavoriteProperties.Remove(favorite);
            await _context.SaveChangesAsync();
        }

        return NoContent(); // 204 başarıyla silindi
    }
}