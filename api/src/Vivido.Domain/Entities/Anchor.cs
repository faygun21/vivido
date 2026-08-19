using NetTopologySuite.Geometries;

namespace Vivido.Domain.Entities;

public class Anchor
{
    public Guid Id { get; set; }
    public Guid ProfileId { get; set; }
    public required string Label { get; set; }
    public required Point Geom { get; set; } // PostGIS geometry(Point, 4326) karşılığı
    public required string Mode { get; set; } // 'foot' veya 'car'
    public short Priority { get; set; } // 1 ile 3 arasında öncelik
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation property
    public UserProfile Profile { get; set; } = null!;
}