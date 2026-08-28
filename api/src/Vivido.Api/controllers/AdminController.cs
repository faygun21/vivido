using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/admin")]
[Authorize(Policy = "AdminOnly")]
public class AdminController : ControllerBase
{
    private readonly VividoDbContext _db;

    public AdminController(VividoDbContext db)
    {
        _db = db;
    }

    // Tüm kullanıcıları listele
    [HttpGet("users")]
    public async Task<IActionResult> GetUsers()
    {
        var users = await _db.Users
            .AsNoTracking()
            .OrderByDescending(u => u.CreatedAt)
            .Select(u => new
            {
                u.Id,
                u.Email,
                u.DisplayName,
                u.IsAdmin,
                u.IsActive,
                u.CreatedAt
            })
            .ToListAsync();

        return Ok(users);
    }

    // Kullanıcıyı admin yap / admin yetkisini kaldır
    [HttpPatch("users/{id:guid}/admin")]
    public async Task<IActionResult> SetAdmin(
        Guid id,
        [FromBody] SetAdminRequest request)
    {
        var currentUserId = GetCurrentUserId();

        if (currentUserId is null)
            return Unauthorized();

        // Admin kendi admin yetkisini kaldıramaz.
        if (currentUserId == id && !request.IsAdmin)
        {
            return BadRequest(new
            {
                message = "Kendi admin yetkinizi kaldıramazsınız."
            });
        }

        var user = await _db.Users.FindAsync(id);

        if (user is null)
            return NotFound();

        user.IsAdmin = request.IsAdmin;

        await _db.SaveChangesAsync();

        return NoContent();
    }

    // Kullanıcıyı aktif / pasif yap
    [HttpPatch("users/{id:guid}/active")]
    public async Task<IActionResult> SetActive(
        Guid id,
        [FromBody] SetActiveRequest request)
    {
        var currentUserId = GetCurrentUserId();

        if (currentUserId is null)
            return Unauthorized();

        // Admin kendi hesabını pasif yapamaz.
        if (currentUserId == id && !request.IsActive)
        {
            return BadRequest(new
            {
                message = "Kendi hesabınızı pasif yapamazsınız."
            });
        }

        var user = await _db.Users.FindAsync(id);

        if (user is null)
            return NotFound();

        user.IsActive = request.IsActive;

        await _db.SaveChangesAsync();

        return NoContent();
    }

    // JWT içindeki kullanıcı id'sini alır.
    // ASP.NET "sub" claim'ini NameIdentifier'a map edebildiği için
    // birkaç farklı claim adını güvenli şekilde deniyoruz.
    private Guid? GetCurrentUserId()
    {
        var userIdValue =
            User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst(JwtRegisteredClaimNames.Sub)?.Value
            ?? User.FindFirst("sub")?.Value;

        if (Guid.TryParse(userIdValue, out var userId))
            return userId;

        return null;
    }
}

public record SetAdminRequest(bool IsAdmin);

public record SetActiveRequest(bool IsActive);