namespace Vivido.Application.dtos.persona;

// Bir personaya ait yaşam kriterini ve başlangıç ağırlığını temsil eder.
public record PersonaCategoryWeightDto(
    string CategoryCode,
    decimal Weight
);

public record PersonaDto(
    string Code,
    string DisplayNameTr,
    string DescriptionTr,
    string? Icon,
    List<PersonaCategoryWeightDto> CategoryWeights
);