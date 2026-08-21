namespace Vivido.Application.Dtos.Route;

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

// Rota detayına girildiğinde döneceğimiz kapsamlı model
public class RouteDetailResponse : RouteListResponse
{
    public string? StartLabel { get; set; }
    public CoordinateDto Start { get; set; } = null!;
    
    // NTS Geometry ve JsonDocument verileri bu kısımdan beslenecek
    public object? Steps { get; set; } 
    public List<RouteStopDto> Stops { get; set; } = new();
}

public class CoordinateDto
{
    public double Lat { get; set; }
    public double Lon { get; set; }
}

public class RouteStopDto
{
    public short Seq { get; set; }
    public long PropertyId { get; set; }
    public decimal? ScoreSnapshot { get; set; }
    public int? LegDistanceM { get; set; }
    public int? LegDurationS { get; set; }
    public DateTime? VisitedAt { get; set; }
}