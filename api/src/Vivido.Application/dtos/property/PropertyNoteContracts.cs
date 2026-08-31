namespace Vivido.Application.Dtos.Property;

public record PropertyNoteResponse(
    long PropertyId,
    string? Note,
    DateTime? CreatedAt,
    DateTime? UpdatedAt);

public record UpsertPropertyNoteRequest(string? Note);
