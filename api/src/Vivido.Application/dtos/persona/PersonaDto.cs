namespace Vivido.Application.dtos.persona;

public record PersonaDto(
    string Code,
    string DisplayNameTr,
    string DescriptionTr,
    string? Icon
);