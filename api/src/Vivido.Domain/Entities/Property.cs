using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using NetTopologySuite.Geometries;

[Table("properties")]
public class Property
{
    [Key]
    [Column("id")]
    public long Id { get; set; }

    [Column("external_ref")]
    public string ExternalRef { get; set; } = null!;

    [Column("geom")]
    public Point Geom { get; set; } = null!;

    [Column("monthly_rent")]
    public decimal MonthlyRent { get; set; }

    [Column("area_m2")]
    public short AreaM2 { get; set; }

    [Column("room_count")]
    public string RoomCount { get; set; } = null!;

    [Column("is_synthetic")]
    public bool IsSynthetic { get; set; } = true;

    [Column("data_version")]
    public string DataVersion { get; set; } = null!;
}