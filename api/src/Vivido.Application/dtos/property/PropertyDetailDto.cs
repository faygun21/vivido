namespace Vivido.Application.dtos.property;

// Detay panelinde gösterilecek kapsamlı DTO
public record PropertyDetailDto(
    string Id,
    string ExternalRef,
    decimal MonthlyRent,
    short AreaM2,
    string RoomCount,
    double Latitude,
    double Longitude,
    double TotalScore,
    Dictionary<string, double> ScoreBreakdown // Alt kategori skor kırılımları
);