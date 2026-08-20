using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Application.dtos.profile;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
[Authorize] // Sadece giriş yapmış kullanıcılar profil işlemlerini yönetebilir
public class ProfilesController : ControllerBase
{
    private readonly VividoDbContext _context;

    public ProfilesController(VividoDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<UserProfileDto>> GetProfile()
    {
        var userIdString = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(userIdString, out var userId))
            return Unauthorized();

        var profile = await _context.UserProfiles
            .Include(p => p.Anchors)
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.UserId == userId);

        // Profil yoksa 404 döneriz. Frontend bu 404 cevabını 
        // "kullanıcı onboarding'i henüz tamamlamamış" olarak yorumlayıp 
        // kullanıcıyı /onboarding sayfasına yönlendirebilir.
        if (profile == null)
            return NotFound(new { message = "Profil bulunamadı, onboarding adımları bekleniyor." });

        var profileDto = new UserProfileDto(
            profile.Id.ToString(),
            profile.PersonaCode,
            profile.MonthlyBudget,
            profile.Anchors.Select(a => new AnchorDto(
                a.Id.ToString(),
                a.Label,
                a.Geom.Y, // Lat
                a.Geom.X, // Lon
                a.Mode,
                a.Priority
            )).ToList()
        );

        return Ok(profileDto);
    }

    [HttpPut]
    public async Task<IActionResult> UpsertProfile([FromBody] UpdateProfileRequest request)
    {
        var userIdString = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(userIdString, out var userId))
            return Unauthorized();

        var profile = await _context.UserProfiles
            .FirstOrDefaultAsync(p => p.UserId == userId);

        if (profile == null)
        {
            profile = new UserProfile
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                PersonaCode = request.PersonaCode,
                MonthlyBudget = request.MonthlyBudget
            };
            _context.UserProfiles.Add(profile);
        }
        else
        {
            profile.PersonaCode = request.PersonaCode;
            profile.MonthlyBudget = request.MonthlyBudget;
            profile.UpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
        return Ok(new { message = "Profil başarıyla kaydedildi." });
    }
}