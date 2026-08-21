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
[Authorize]
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

        if (profile == null)
            return ApiProblem.ProfileNotFound();

        var categoryOrder = await _context.UserProfileCategoryOrders
            .Where(x => x.ProfileId == profile.Id)
            .OrderBy(x => x.Priority)
            .Select(x => x.CategoryCode)
            .AsNoTracking()
            .ToListAsync();

        var profileDto = new UserProfileDto(
            profile.Id.ToString(),
            profile.FirstName,
            profile.LastName,
            profile.PersonaCode,
            profile.MonthlyBudget,
            categoryOrder,
            profile.Anchors
                .OrderBy(a => a.Priority)
                .Select(a => new AnchorDto(
                    a.Id.ToString(),
                    a.Label,
                    a.Geom.Y,
                    a.Geom.X,
                    a.Mode,
                    a.Priority
                ))
                .ToList()
        );

        return Ok(profileDto);
    }

    [HttpPut]
    public async Task<IActionResult> UpsertProfile(
        [FromBody] UpdateProfileRequest request
    )
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
                FirstName = request.FirstName,
                LastName = request.LastName,
                PersonaCode = request.PersonaCode,
                MonthlyBudget = request.MonthlyBudget
            };

            _context.UserProfiles.Add(profile);
        }
        else
        {
            profile.FirstName = request.FirstName;
            profile.LastName = request.LastName;
            profile.PersonaCode = request.PersonaCode;
            profile.MonthlyBudget = request.MonthlyBudget;
            profile.UpdatedAt = DateTime.UtcNow;
        }

        /*
         * Önce profili kaydediyoruz.
         *
         * Yeni profilse profile.Id'nin DB tarafında
         * ilişkiler için kullanılabilir olması gerekiyor.
         */
        await _context.SaveChangesAsync();

        /*
         * Kullanıcı kriter sırasını gönderdiyse
         * kişisel sıralamayı yeniliyoruz.
         */
        if (request.CategoryOrder is not null)
        {
            var categoryOrder = request.CategoryOrder;

            /*
             * Aynı kategori iki kez gönderilemez.
             */
            if (
                categoryOrder.Distinct().Count()
                != categoryOrder.Count
            )
            {
                ModelState.AddModelError(
                    nameof(request.CategoryOrder),
                    "Kriter listesinde tekrar eden kategori olamaz."
                );

                return ValidationProblem(ModelState);
            }

            /*
             * Frontend'den gelen kategorilerin gerçekten
             * geçerli POI kategorileri olduğunu doğrula.
             */
            var validCategories = await _context.PersonaCategoryWeights
                .Where(x => x.PersonaCode == request.PersonaCode)
                .Select(x => x.CategoryCode)
                .ToListAsync();

            var validSet = validCategories.ToHashSet();

            if (!categoryOrder.All(validSet.Contains))
            {
                ModelState.AddModelError(
                    nameof(request.CategoryOrder),
                    "Geçersiz yaşam kriteri gönderildi."
                );

                return ValidationProblem(ModelState);
            }

            /*
             * Persona için tanımlı bütün kriterler gönderilmeli.
             * Eksik liste kaydetmiyoruz.
             */
            if (categoryOrder.Count != validCategories.Count)
            {
                ModelState.AddModelError(
                    nameof(request.CategoryOrder),
                    "Yaşam kriterlerinin tamamı gönderilmelidir."
                );

                return ValidationProblem(ModelState);
            }

            /*
             * Önce kullanıcının eski kişisel sırasını sil.
             */
            var existingOrder = await _context.UserProfileCategoryOrders
                .Where(x => x.ProfileId == profile.Id)
                .ToListAsync();

            _context.UserProfileCategoryOrders
                .RemoveRange(existingOrder);

            /*
             * Yeni sırayı 1, 2, 3... olarak kaydet.
             */
            for (var i = 0; i < categoryOrder.Count; i++)
            {
                _context.UserProfileCategoryOrders.Add(
                    new UserProfileCategoryOrder
                    {
                        ProfileId = profile.Id,
                        CategoryCode = categoryOrder[i],
                        Priority = (short)(i + 1)
                    }
                );
            }

            await _context.SaveChangesAsync();
        }

        var anchors = await _context.Anchors
            .Where(a => a.ProfileId == profile.Id)
            .OrderBy(a => a.Priority)
            .AsNoTracking()
            .ToListAsync();

        var savedCategoryOrder = await _context.UserProfileCategoryOrders
            .Where(x => x.ProfileId == profile.Id)
            .OrderBy(x => x.Priority)
            .Select(x => x.CategoryCode)
            .AsNoTracking()
            .ToListAsync();

        return Ok(
            new UserProfileDto(
                profile.Id.ToString(),
                profile.FirstName,
                profile.LastName,
                profile.PersonaCode,
                profile.MonthlyBudget,
                savedCategoryOrder,
                anchors.Select(a => new AnchorDto(
                    a.Id.ToString(),
                    a.Label,
                    a.Geom.Y,
                    a.Geom.X,
                    a.Mode,
                    a.Priority
                )).ToList()
            )
        );
    }
}