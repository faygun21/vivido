namespace Vivido.Domain.Entities;

public class PropertyPoiAccess
{
    // Composite key in DB is (PropertyId, CategoryCode)
    public long PropertyId { get; set; }
    public required string CategoryCode { get; set; }
    public double DurationMin { get; set; }
}