using System.Text.Json;
using NetTopologySuite.Geometries;

namespace Vivido.Domain.Entities;

public class Route
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public required string Name { get; set; }
    public required Point StartGeom { get; set; } 
    public string? StartLabel { get; set; }
    public string Mode { get; set; } = "car";
    public int TotalDistanceM { get; set; }
    public int TotalDurationS { get; set; }
    public required LineString Geometry { get; set; } 
    public required JsonDocument Steps { get; set; } 
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Kullanıcının bu rotayı gezmeyi planladığı an. NULL = plan girilmedi.
    ///
    /// ⚠️ Bildirim GÖNDERMEZ — yalnızca saklanır ve kayıtlı rotalar
    /// listesinde gösterilir (bkz. db/schema/013_add_route_schedule.sql).
    /// </summary>
    public DateTime? ScheduledAt { get; set; }

    public User User { get; set; } = null!;
    public ICollection<RouteStop> Stops { get; set; } = new List<RouteStop>();
}