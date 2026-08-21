namespace Vivido.Application.dtos.profile;

public record UserProfileDto(
    string Id,
    string FirstName,
    string LastName,
    string PersonaCode,
    decimal? MonthlyBudget,
    List<AnchorDto> Anchors
);

public record UpdateProfileRequest(
    string FirstName,
    string LastName,
    string PersonaCode,
    decimal? MonthlyBudget
);

public record AnchorDto(
    string Id,
    string Label,
    double Lat,
    double Lon,
    string Mode,
    int Priority
);