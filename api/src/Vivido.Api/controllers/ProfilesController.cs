using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Application.dtos.profile;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

[ApiController]
// ⚠️ `[controller]` KULLANMA: sınıf adı ProfilesController olduğu için yol
// /api/v1/profiles (çoğul) olurdu. Sözleşme (vivido-api-sozlesmesi.md §4),
// packages/shared tipleri ve web istemcisi TEKİL /profile bekliyor.
[Route("api/v1/profile")]
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
            return ApiProblem.ProfileNotFound();

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

        // Sözleşme: 200 → UserProfile. İstemci kaydettikten sonra ikinci bir
        // GET atmak zorunda kalmasın diye güncel profili döneriz.
        var anchors = await _context.Anchors
            .Where(a => a.ProfileId == profile.Id)
            .OrderBy(a => a.Priority)
            .AsNoTracking()
            .ToListAsync();

        return Ok(new UserProfileDto(
            profile.Id.ToString(),
            profile.PersonaCode,
            profile.MonthlyBudget,
            anchors.Select(a => new AnchorDto(
                a.Id.ToString(), a.Label, a.Geom.Y, a.Geom.X, a.Mode, a.Priority
            )).ToList()
        ));
    }
}