using System.Text.Json.Serialization;

namespace Vivido.Infrastructure.Routing;

/// <summary>OSRM /table yanıtı — `annotations=duration,distance` ile istenir.</summary>
public sealed class OsrmTableResponse
{
    [JsonPropertyName("code")]
    public string? Code { get; set; }

    [JsonPropertyName("durations")]
    public double?[][]? Durations { get; set; }

    [JsonPropertyName("distances")]
    public double?[][]? Distances { get; set; }
}

/// <summary>OSRM /route yanıtı — `steps=true&geometries=geojson&overview=full` ile istenir.</summary>
public sealed class OsrmRouteResponse
{
    [JsonPropertyName("code")]
    public string? Code { get; set; }

    [JsonPropertyName("routes")]
    public List<OsrmRoute>? Routes { get; set; }
}

public sealed class OsrmRoute
{
    [JsonPropertyName("distance")]
    public double Distance { get; set; }

    [JsonPropertyName("duration")]
    public double Duration { get; set; }

    [JsonPropertyName("geometry")]
    public OsrmLineStringGeometry? Geometry { get; set; }

    [JsonPropertyName("legs")]
    public List<OsrmLeg>? Legs { get; set; }
}

public sealed class OsrmLeg
{
    [JsonPropertyName("distance")]
    public double Distance { get; set; }

    [JsonPropertyName("duration")]
    public double Duration { get; set; }

    [JsonPropertyName("steps")]
    public List<OsrmStep>? Steps { get; set; }
}

public sealed class OsrmStep
{
    [JsonPropertyName("distance")]
    public double Distance { get; set; }

    [JsonPropertyName("duration")]
    public double Duration { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("maneuver")]
    public OsrmManeuver? Maneuver { get; set; }

    [JsonPropertyName("geometry")]
    public OsrmLineStringGeometry? Geometry { get; set; }
}

public sealed class OsrmManeuver
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("modifier")]
    public string? Modifier { get; set; }

    /// <summary>[lon, lat] — GeoJSON sırası (OSRM manevra konumu).</summary>
    [JsonPropertyName("location")]
    public double[] Location { get; set; } = Array.Empty<double>();

    [JsonPropertyName("exit")]
    public int? Exit { get; set; }
}

/// <summary>GeoJSON LineString — koordinatlar [lon, lat] sırasında.</summary>
public sealed class OsrmLineStringGeometry
{
    [JsonPropertyName("type")]
    public string Type { get; set; } = "LineString";

    [JsonPropertyName("coordinates")]
    public List<double[]> Coordinates { get; set; } = new();
}

/// <summary>İstemciye dönen /table sonucu.</summary>
public sealed class OsrmTableResult
{
    public double?[][] Durations { get; init; } = Array.Empty<double?[]>();
    public double?[][] Distances { get; init; } = Array.Empty<double?[]>();
}

/// <summary>İstemciye dönen /route sonucu.</summary>
public sealed class OsrmRouteResult
{
    public double Distance { get; init; }
    public double Duration { get; init; }
    public OsrmLineStringGeometry Geometry { get; init; } = new();
    public IReadOnlyList<OsrmLeg> Legs { get; init; } = Array.Empty<OsrmLeg>();
}
