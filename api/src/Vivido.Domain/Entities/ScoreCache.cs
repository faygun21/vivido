using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Vivido.Domain.Entities; 

[Table("score_cache")]
public class ScoreCache
{
    [Column("property_id")]
    public long PropertyId { get; set; }

    [Column("profile_id")]
    public Guid ProfileId { get; set; }

    [Column("scoring_version")]
    public string ScoringVersion { get; set; } = null!;

    [Column("total_score")]
    public decimal TotalScore { get; set; }

    [Column("breakdown", TypeName = "jsonb")]
    public string Breakdown { get; set; } = null!;

    [Column("computed_at")]
    public DateTime ComputedAt { get; set; } = DateTime.UtcNow;
}