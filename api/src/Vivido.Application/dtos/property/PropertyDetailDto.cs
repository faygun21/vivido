namespace Vivido.Application.dtos.property;

/// <summary>Konutun "nasıl bir ev" bilgileri — şemada baştan beri vardı.</summary>
public record PropertyFeaturesDto(
    short? FloorNo,
    short? TotalFloors,
    short? BuildingAge,
    bool HasElevator,
    bool HasParking,
    bool IsFurnished,
    bool PetsAllowed,
    decimal? RentPerM2,
    decimal? Deposit
);

/// <summary>
/// Haritada bir konut pin'ine tıklanınca açılan detay panelinin verisi
/// (R-115, R-118, W6).
///
/// Eskiden yalnızca kira + m² + oda + toplam skor taşıyordu; kullanıcı
/// "77/100" görüyor ama BU SKORUN NEDEN 77 olduğunu göremiyordu. Artık
/// gerekçe satırları, adres ve favori durumu da burada.
/// </summary>
public record PropertyDetailDto(
    string Id,
    string ExternalRef,
    decimal MonthlyRent,
    short AreaM2,
    string RoomCount,
    double Latitude,
    double Longitude,
    PropertyAddressDto Address,
    PropertyFeaturesDto Features,
    PropertyScoreDetailDto Score,
    bool IsFavorite,
    /// <summary>K-06 dürüstlük kuralı: arayüzde rozetlenmesi ZORUNLU.</summary>
    bool IsSynthetic
);
