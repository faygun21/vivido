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

    /// <summary>
    /// Bu kategoride, konutun arama yarıçapında (poi_categories.search_radius_m)
    /// kaç POI olduğu — yoğunluk sinyali için. Migration'dan önce yazılmış
    /// satırlarda null olabilir; skorlama bu durumda çarpanı devre dışı bırakır.
    /// </summary>
    [Column("poi_count_in_radius")]
    public int? PoiCountInRadius { get; set; }

    [Column("data_version")]
    public string DataVersion { get; set; } = null!;
}