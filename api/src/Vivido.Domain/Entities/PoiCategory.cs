using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

// Diğer entity'ler bu ad alanında; `PoiCategory` global ad alanında kalmıştı.
namespace Vivido.Domain.Entities;

[Table("poi_categories")]
public class PoiCategory
{
    [Key]
    [Column("code")]
    public string Code { get; set; } = null!;

    [Column("display_name_tr")]
    public string DisplayNameTr { get; set; } = null!;

    [Column("t_ideal_min")]
    public decimal TIdealMin { get; set; }

    [Column("t_half_min")]
    public decimal THalfMin { get; set; }

    [Column("t_cutoff_min")]
    public decimal TCutoffMin { get; set; }

    [Column("search_radius_m")]
    public int SearchRadiusM { get; set; } = 2500;

    [Column("min_poi_count")]
    public short MinPoiCount { get; set; } = 5;

   [Column("active")]
    public bool Active { get; set; } = true;
}