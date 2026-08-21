namespace Vivido.Domain.Entities;

public class RouteStop
{
    public Guid RouteId { get; set; }
    public short Seq { get; set; } 
    public long PropertyId { get; set; }
    public decimal? ScoreSnapshot { get; set; } 
    public int? LegDistanceM { get; set; }
    public int? LegDurationS { get; set; }
    public DateTime? VisitedAt { get; set; } 

    public Route Route { get; set; } = null!;
}