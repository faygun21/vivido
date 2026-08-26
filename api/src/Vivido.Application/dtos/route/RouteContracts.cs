using System.Text.Json.Serialization;

namespace Vivido.Application.Dtos.Route;

/// <summary>Rota sınırları — packages/shared MAX_ROUTE_STOPS=8 / MIN_ROUTE_STOPS=2 ile senkron.</summary>
public static class RouteLimits
{
    public const int MinStops = 2;
    public const int MaxStops = 8;
}

// Rotaları listelerken (Ana ekran / mobil liste) döneceğimiz özet model
public class RouteListResponse
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Mode { get; set; } = string.Empty;
    public int TotalDistanceM { get; set; }
    public int TotalDurationS { get; set; }
    public DateTime CreatedAt { get; set; }
    public int StopCount { get; set; }
}

// POST /routes isteği — packages/shared CreateRouteRequest ile senkron
public class CreateRouteRequest
{
    public string Name { get; set; } = string.Empty;

    public RouteStartDto Start { get; set; } = new();

    /// <summary>2–8 konut id'si. Sınır dışı → 422 ROUTE_STOP_LIMIT_EXCEEDED.</summary>
    public List<long> PropertyIds { get; set; } = new();

    /// <summary>'car' (varsayılan) | 'foot'</summary>
    public string? Mode { get; set; }
}

public class RouteStartDto
{
    public double Lat { get; set; }
    public double Lon { get; set; }
    public string? Label { get; set; }
}

// Rota detayı — packages/shared RouteDetail ile senkron:
// { id, name, start:{lat,lon,label}, mode, totalDistanceM, totalDurationS,
//   geometry, stops, legs, createdAt }
public class RouteDetailResponse : RouteListResponse
{
    public CoordinateDto Start { get; set; } = null!;

    /// <summary>Tam rota çizgisi (GeoJSON LineString, [lon, lat]).</summary>
    public LineStringGeoDto Geometry { get; set; } = null!;

    public List<RouteStopDetailDto> Stops { get; set; } = new();

    /// <summary>Manevra adımlı bacaklar (OSRM /route steps).</summary>
    public List<RouteLegDto> Legs { get; set; } = new();
}

public class CoordinateDto
{
    public double Lat { get; set; }
    public double Lon { get; set; }
    public string? Label { get; set; }
}

public class RouteStopDetailDto
{
    public short Seq { get; set; }
    public long PropertyId { get; set; }

    /// <summary>JSON anahtarı packages/shared RouteStop.score ile senkron.</summary>
    [JsonPropertyName("score")]
    public decimal? ScoreSnapshot { get; set; }

    public int? LegDistanceM { get; set; }
    public int? LegDurationS { get; set; }
    public DateTime? VisitedAt { get; set; }

    /// <summary>Konut özeti — packages/shared RouteStop.property ile senkron.</summary>
    public PropertySummaryDto Property { get; set; } = null!;
}

public class PropertySummaryDto
{
    public decimal MonthlyRent { get; set; }
    public short AreaM2 { get; set; }
    public string RoomCount { get; set; } = string.Empty;
    public string? Neighborhood { get; set; }
    public double Lat { get; set; }
    public double Lon { get; set; }
}

// ─── GeoJSON / OSRM adımları (packages/shared route.ts ile senkron) ───

public class LineStringGeoDto
{
    public string Type { get; set; } = "LineString";

    /// <summary>[lon, lat] çiftleri — GeoJSON standardı.</summary>
    public List<double[]> Coordinates { get; set; } = new();
}

public class ManeuverDto
{
    public string Type { get; set; } = string.Empty;
    public string? Modifier { get; set; }

    /// <summary>[lon, lat]</summary>
    public double[] Location { get; set; } = Array.Empty<double>();

    public int? Exit { get; set; }
}

public class RouteStepDto
{
    public double Distance { get; set; }
    public double Duration { get; set; }
    public string Name { get; set; } = string.Empty;
    public ManeuverDto Maneuver { get; set; } = new();
    public LineStringGeoDto Geometry { get; set; } = new();
}

public class RouteLegDto
{
    public int Seq { get; set; }
    public List<RouteStepDto> Steps { get; set; } = new();
}

/// <summary>DB `steps` jsonb sütununda saklanan zarf — `{ "legs": [...] }`.</summary>
public class RouteStepsEnvelopeDto
{
    public List<RouteLegDto> Legs { get; set; } = new();
}
