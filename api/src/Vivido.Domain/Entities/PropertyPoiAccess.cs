using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

[Table("property_poi_access")]
public class PropertyPoiAccess
    {
    [Column("property_id")]
    public long PropertyId { get; set; }

    [Column("category_code")]
    public string CategoryCode { get; set; } = null!;

    [Column("poi_id")]
    public long PoiId { get; set; }

    [Column("duration_min")]
    public decimal DurationMin { get; set; }

    [Column("distance_m")]
    public int DistanceM { get; set; }

    [Column("data_version")]
    public string DataVersion { get; set; } = null!;
}