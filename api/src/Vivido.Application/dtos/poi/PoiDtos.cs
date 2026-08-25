namespace Vivido.Application.dtos.poi;

/// <summary>R-108/R-110 harita POI'si — ad, kategori ve koordinat.</summary>
public record PoiDto(long Id, string? Name, string CategoryCode, double Latitude, double Longitude);

/// <summary>Harita katman panelindeki kategori listesi (R-108).</summary>
public record PoiCategoryDto(string Code, string DisplayNameTr);
