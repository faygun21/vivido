using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;
using Vivido.Application.dtos.profile;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

/// <summary>
/// Anchor (düzenli gidilen yer) CRUD ve öncelik sıralaması — W4.
///
/// Ayrı bir controller: <see cref="ProfilesController"/> ile aynı dosyada
/// çalışmamak için. Yol yine <c>/api/v1/profile/anchors</c>, yani sözleşme
/// (vivido-api-sozlesmesi.md §4) bozulmuyor.
/// </summary>
[ApiController]
[Route("api/v1/profile/anchors")]
[Authorize]
public class AnchorsController : ControllerBase
{
    /// <summary>Şema <c>CHECK (priority BETWEEN 1 AND 3)</c> ile de zorluyor.</summary>
    private const int MaxAnchors = 3;

    private readonly VividoDbContext _context;

    public AnchorsController(VividoDbContext context)
    {
        _context = context;
    }

    // ─── GET /api/v1/profile/anchors ───
    [HttpGet]
    public async Task<IActionResult> GetAnchors()
    {
        var profile = await FindProfileAsync();
        if (profile is null) return ApiProblem.ProfileNotFound();

        var anchors = await _context.Anchors
            .Where(a => a.ProfileId == profile.Id)
            .OrderBy(a => a.Priority)
            .AsNoTracking()
            .ToListAsync();

        return Ok(anchors.Select(ToDto).ToList());
    }

    // ─── POST /api/v1/profile/anchors ───
    [HttpPost]
    public async Task<IActionResult> CreateAnchor([FromBody] CreateAnchorRequest request)
    {
        if (request.Mode is not ("foot" or "car"))
        {
            ModelState.AddModelError(nameof(request.Mode), "Yalnızca 'foot' veya 'car' olabilir.");
            return ValidationProblem(ModelState);
        }

        if (string.IsNullOrWhiteSpace(request.Label))
        {
            ModelState.AddModelError(nameof(request.Label), "Etiket boş olamaz.");
            return ValidationProblem(ModelState);
        }

        var profile = await FindProfileAsync();
        if (profile is null) return ApiProblem.ProfileNotFound();

        var existing = await _context.Anchors
            .Where(a => a.ProfileId == profile.Id)
            .OrderBy(a => a.Priority)
            .ToListAsync();

        // DB CHECK kısıtı da reddederdi ama kullanıcıya 500 değil 422 dönmeli.
        if (existing.Count >= MaxAnchors) return ApiProblem.AnchorLimitExceeded(MaxAnchors);

        var anchor = new Anchor
        {
            Id = Guid.NewGuid(),
            ProfileId = profile.Id,
            Label = request.Label.Trim(),
            // NTS Point(x=lon, y=lat). SRID verilmezse PostGIS geometriyi reddeder.
            Geom = new Point(request.Lon, request.Lat) { SRID = 4326 },
            Mode = request.Mode,
            // K-G: önceliği sunucu atar — listenin sonuna eklenir.
            Priority = (short)(existing.Count + 1),
        };

        _context.Anchors.Add(anchor);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetAnchors), ToDto(anchor));
    }

    // ─── DELETE /api/v1/profile/anchors/{id} ───
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteAnchor(Guid id)
    {
        var profile = await FindProfileAsync();
        if (profile is null) return ApiProblem.ProfileNotFound();

        var anchors = await _context.Anchors
            .Where(a => a.ProfileId == profile.Id)
            .OrderBy(a => a.Priority)
            .ToListAsync();

        var target = anchors.FirstOrDefault(a => a.Id == id);
        // Başkasının anchor'ı da buraya düşer — "yok" demek doğru cevap.
        if (target is null) return NotFound();

        _context.Anchors.Remove(target);

        // Öncelikleri SIKIŞTIR: ② silinirse ③ → ② olur. Yoksa 1,3 boşluğu
        // kalır, DQ-06 kapısı kırılır ve geometrik ağırlık yanlış hesaplanır.
        var remaining = anchors.Where(a => a.Id != id).ToList();
        for (var i = 0; i < remaining.Count; i++) remaining[i].Priority = (short)(i + 1);

        // Tek SaveChanges = tek transaction. DEFERRABLE kısıt COMMIT'te
        // kontrol edildiği için ara adımdaki çakışma sorun olmaz.
        await _context.SaveChangesAsync();

        return NoContent();
    }

    // ─── PUT /api/v1/profile/anchors/order ───  ⭐ W4'ün kalbi
    [HttpPut("order")]
    public async Task<IActionResult> ReorderAnchors([FromBody] ReorderAnchorsRequest request)
    {
        var profile = await FindProfileAsync();
        if (profile is null) return ApiProblem.ProfileNotFound();

        var anchors = await _context.Anchors
            .Where(a => a.ProfileId == profile.Id)
            .ToListAsync();

        var order = request.Order ?? [];

        // Dört maddelik doğrulama. Biri bile bozuksa öncelikler boşluklu
        // kalır → DQ-06 kırılır. Bu yüzden kısmi uygulama YOK, hep ya da hiç.
        var parsed = new List<Guid>();
        foreach (var raw in order)
        {
            if (!Guid.TryParse(raw, out var guid))
                return ApiProblem.InvalidAnchorOrder($"Geçersiz anchor id: {raw}");
            parsed.Add(guid);
        }

        if (parsed.Distinct().Count() != parsed.Count)
            return ApiProblem.InvalidAnchorOrder("Listede tekrar eden id var.");

        if (parsed.Count != anchors.Count)
            return ApiProblem.InvalidAnchorOrder(
                $"Listede {parsed.Count} id var, profilde {anchors.Count} anchor bulunuyor. Tamamı gönderilmeli.");

        var owned = anchors.Select(a => a.Id).ToHashSet();
        if (!parsed.All(owned.Contains))
            return ApiProblem.InvalidAnchorOrder("Listede size ait olmayan ya da var olmayan bir anchor var.");

        var byId = anchors.ToDictionary(a => a.Id);
        for (var i = 0; i < parsed.Count; i++) byId[parsed[i]].Priority = (short)(i + 1);

        // ⚠️ Döngü İÇİNDE SaveChanges çağırma — her biri ayrı transaction olur
        // ve DEFERRABLE avantajı kaybolur, ikincisinde kısıt ihlali patlar.
        await _context.SaveChangesAsync();

        var result = anchors.OrderBy(a => a.Priority).Select(ToDto).ToList();
        return Ok(result);
    }

    // ─── yardımcılar ───

    private async Task<UserProfile?> FindProfileAsync()
    {
        var userIdString = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(userIdString, out var userId)) return null;

        return await _context.UserProfiles.FirstOrDefaultAsync(p => p.UserId == userId);
    }

    private static AnchorDto ToDto(Anchor a) =>
        new(a.Id.ToString(), a.Label, a.Geom.Y, a.Geom.X, a.Mode, a.Priority);
}
