namespace Vivido.Application.dtos.property;

// Harita üzerinde ikonlar ve liste için özet DTO
public record PropertyMapItemDto(
    string Id,
    decimal MonthlyRent,
    short AreaM2,
    string RoomCount,
    double Latitude,
    double Longitude,
    double TotalScore
);