using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Application.Dtos.Property;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/properties/{propertyId:long}/note")]
[Authorize]
public class PropertyNotesController : ControllerBase
{
    private const int MaxNoteLength = 1000;
    private readonly VividoDbContext _context;

    public PropertyNotesController(VividoDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<IActionResult> GetNote(long propertyId, CancellationToken ct)
    {
        if (!await _context.Properties.AsNoTracking().AnyAsync(p => p.Id == propertyId, ct))
            return PropertyNotFound();

        var userId = GetUserId();
        var note = await _context.PropertyNotes
            .AsNoTracking()
            .FirstOrDefaultAsync(n => n.UserId == userId && n.PropertyId == propertyId, ct);

        return Ok(ToResponse(propertyId, note));
    }

    [HttpPut]
    public async Task<IActionResult> PutNote(
        long propertyId,
        [FromBody] UpsertPropertyNoteRequest request,
        CancellationToken ct)
    {
        var value = request.Note?.Trim();
        if (string.IsNullOrEmpty(value) || value.Length > MaxNoteLength)
        {
            return ApiProblem.Validation(new Dictionary<string, string[]>
            {
                ["note"] = new[] { $"Not 1 ile {MaxNoteLength} karakter arasında olmalıdır." },
            });
        }

        if (!await _context.Properties.AsNoTracking().AnyAsync(p => p.Id == propertyId, ct))
            return PropertyNotFound();

        var userId = GetUserId();
        var note = await _context.PropertyNotes
            .FirstOrDefaultAsync(n => n.UserId == userId && n.PropertyId == propertyId, ct);

        if (note is null)
        {
            note = new PropertyNote
            {
                UserId = userId,
                PropertyId = propertyId,
                Note = value,
            };
            _context.PropertyNotes.Add(note);
        }
        else
        {
            note.Note = value;
            note.UpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync(ct);
        return Ok(ToResponse(propertyId, note));
    }

    [HttpDelete]
    public async Task<IActionResult> DeleteNote(long propertyId, CancellationToken ct)
    {
        var userId = GetUserId();
        var note = await _context.PropertyNotes
            .FirstOrDefaultAsync(n => n.UserId == userId && n.PropertyId == propertyId, ct);

        if (note is not null)
        {
            _context.PropertyNotes.Remove(note);
            await _context.SaveChangesAsync(ct);
        }

        return NoContent();
    }

    private Guid GetUserId()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.Parse(userId!);
    }

    private static PropertyNoteResponse ToResponse(long propertyId, PropertyNote? note) =>
        new(propertyId, note?.Note, note?.CreatedAt, note?.UpdatedAt);

    private static ObjectResult PropertyNotFound() => ApiProblem.Build(
        404,
        "Konut bulunamadı",
        "PROPERTY_NOT_FOUND");
}
