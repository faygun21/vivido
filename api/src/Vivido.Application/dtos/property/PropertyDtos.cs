namespace Vivido.Application.dtos.property;

/// <summary>R-109/R-110 harita konutu — konum, kira ve temel özellikler.</summary>
public record MapPropertyDto(
    long Id,
    string ExternalRef,
    double Latitude,
    double Longitude,
    decimal MonthlyRent,
    short AreaM2,
    string RoomCount,
    short? BuildingAge,
    bool HasElevator,
    bool IsSynthetic);
