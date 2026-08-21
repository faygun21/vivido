using NetTopologySuite.Geometries;

namespace Vivido.Domain.Entities;

/// <summary>PostGIS'te tutulan Çankaya mahalle sınırı.</summary>
public class Neighborhood
{
    public long Id { get; set; }
    public required string Name { get; set; }
    public required MultiPolygon Geom { get; set; }
    public decimal RentIndex { get; set; }
    public required string DataVersion { get; set; }
}
