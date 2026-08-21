namespace Vivido.Application.dtos.location;

/// <summary>Haritanın bir arama sonucuna yakınlaşması için sınır kutusu.</summary>
public sealed record LocationBoundsDto(
    double South,
    double West,
    double North,
    double East);

/// <summary>Mahalle, adres veya yer adı arama sonucu.</summary>
public sealed record LocationSearchResultDto(
    string Id,
    string Label,
    string Kind,
    double Latitude,
    double Longitude,
    LocationBoundsDto? Bounds,
    string? Neighborhood,
    string Source);

/// <summary>R-105 konum araması yanıtı.</summary>
public sealed record LocationSearchResponseDto(
    IReadOnlyList<LocationSearchResultDto> Items,
    string Attribution);

/// <summary>Yerel mahalle ve dış geocoder sonuçlarını tek sözleşmede birleştirir.</summary>
public interface ILocationSearchService
{
    Task<LocationSearchResponseDto> SearchAsync(
        string query,
        int limit,
        CancellationToken cancellationToken = default);
}

/// <summary>Dış geocoding servisine ulaşılamadığında oluşur.</summary>
public sealed class LocationSearchUnavailableException : Exception
{
    public LocationSearchUnavailableException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }
}
