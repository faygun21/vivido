using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using NetTopologySuite.Geometries;

namespace Vivido.Domain.Entities;

/// <summary>
/// OSM'den ETL ile türetilen önemli nokta (POI). Şema: db/schema/001_initial.sql §4.
/// </summary>
[Table("pois")]
public class Poi
{
    [Key]
    [Column("id")]
    public long Id { get; set; }

    [Column("osm_id")]
    public long? OsmId { get; set; }

    [Column("osm_type")]
    public string? OsmType { get; set; }

    [Column("name")]
    public string? Name { get; set; }

    [Column("category_code")]
    public string CategoryCode { get; set; } = null!;

    [Column("geom")]
    public Point Geom { get; set; } = null!;

    [Column("data_version")]
    public string DataVersion { get; set; } = null!;
}
