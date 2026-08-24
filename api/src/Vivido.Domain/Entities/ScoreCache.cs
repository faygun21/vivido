using System.Text.Json;

namespace Vivido.Domain.Entities;

public class ScoreCache
{
    // Composite key: (PropertyId, ProfileId, ScoringVersion)
    public long PropertyId { get; set; }
    public Guid ProfileId { get; set; }
    public string ScoringVersion { get; set; } = "v1";

    public double Score { get; set; }
    public string? Breakdown { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public void SetBreakdown(object breakdown)
    {
        Breakdown = JsonSerializer.Serialize(breakdown);
    }
}
