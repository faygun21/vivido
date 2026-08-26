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

    [Column("neighborhood_id")]
    public long NeighborhoodId { get; set; }

    [Column("monthly_rent")]
    public decimal MonthlyRent { get; set; }

    [Column("deposit")]
    public decimal? Deposit { get; set; }

    [Column("area_m2")]
    public short AreaM2 { get; set; }

    [Column("room_count")]
    public string RoomCount { get; set; } = null!;

    // ─── Detay panelinin "bu ev nasıl bir ev" kısmı ───
    // Şemada baştan beri vardı, entity'ye yeni eklendi: harita pin'ine
    // tıklayınca açılan panel yalnızca kira + m² + skor gösteriyordu.

    [Column("floor_no")]
    public short? FloorNo { get; set; }

    [Column("total_floors")]
    public short? TotalFloors { get; set; }

    [Column("building_age")]
    public short? BuildingAge { get; set; }

    [Column("has_elevator")]
    public bool HasElevator { get; set; }

    [Column("has_parking")]
    public bool HasParking { get; set; }

    [Column("is_furnished")]
    public bool IsFurnished { get; set; }

    [Column("pets_allowed")]
    public bool PetsAllowed { get; set; }

    /// <summary>
    /// `GENERATED ALWAYS AS ... STORED` — veritabanı hesaplar, EF ASLA yazmaz.
    /// Yazmaya kalkarsa Postgres 428C9 ile reddeder.
    /// </summary>
    [Column("rent_per_m2")]
    [DatabaseGenerated(DatabaseGeneratedOption.Computed)]
    public decimal? RentPerM2 { get; set; }

    [Column("is_synthetic")]
    public bool IsSynthetic { get; set; } = true;

    [Column("data_version")]
    public string DataVersion { get; set; } = null!;
}
