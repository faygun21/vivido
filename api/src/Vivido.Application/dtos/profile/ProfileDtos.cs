namespace Vivido.Application.dtos.profile;

public record UserProfileDto(
    string Id,
    string FirstName,
    string LastName,
    string PersonaCode,
    decimal? MonthlyBudget,

    // Kullanıcının kaydettiği yaşam kriterleri önem sırası.
    // Örn: ["school", "market", "park", ...]
    List<string> CategoryOrder,

    List<AnchorDto> Anchors
);

public record UpdateProfileRequest(
    string FirstName,
    string LastName,
    string PersonaCode,
    decimal? MonthlyBudget,

    // Frontend sürükle-bırak sonrası kriterleri
    // en önemliden en aza doğru gönderir.
    List<string>? CategoryOrder
);

public record AnchorDto(
    string Id,
    string Label,
    double Lat,
    double Lon,
    string Mode,
    int Priority
);