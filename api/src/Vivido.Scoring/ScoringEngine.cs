namespace Vivido.Scoring;

public static class ScoringEngine
{
    /// <summary>
    /// Calculates the score for a single category using a two-piece linear decay defined by
    /// tIdeal -> 100, tHalf -> 50, tCutoff -> 0.
    /// If tHalf equals tIdeal or tCutoff equals tHalf, the method falls back to a single linear
    /// interpolation across the available range to avoid division by zero.
    /// </summary>
    public static double CalculateCategoryScore(double durationMinutes, double tIdeal, double tHalf, double tCutoff)
    {
        // Normalization: if any thresholds are invalid, treat conservative defaults
        if (tCutoff <= tIdeal)
        {
            // Degenerate: cutoff not greater than ideal — map directly: <=ideal => 100, >=cutoff => 0, linear between
            if (durationMinutes <= tIdeal) return 100.0;
            if (durationMinutes >= tCutoff) return 0.0;
            // Linear between
            return 100.0 + (0.0 - 100.0) * ((durationMinutes - tIdeal) / (tCutoff - tIdeal));
        }

        if (durationMinutes <= tIdeal) return 100.0;
        if (durationMinutes >= tCutoff) return 0.0;

        // duration in (tIdeal, tCutoff)
        // If tHalf is strictly between ideal and cutoff, use two-piece linear with 100->50 and 50->0
        if (tHalf > tIdeal && tHalf < tCutoff)
        {
            if (durationMinutes <= tHalf)
            {
                // linear from (tIdeal,100) to (tHalf,50)
                var span = tHalf - tIdeal;
                if (span == 0) return 50.0; // degenerate
                var slope = (50.0 - 100.0) / span; // negative
                return 100.0 + slope * (durationMinutes - tIdeal);
            }
            else
            {
                // linear from (tHalf,50) to (tCutoff,0)
                var span = tCutoff - tHalf;
                if (span == 0) return 0.0; // degenerate
                var slope = (0.0 - 50.0) / span; // negative
                return 50.0 + slope * (durationMinutes - tHalf);
            }
        }

        // If tHalf is not between ideal and cutoff (degenerate), fallback to single linear interpolation
        return 100.0 + (0.0 - 100.0) * ((durationMinutes - tIdeal) / (tCutoff - tIdeal));
    }

    /// <summary>
    /// Calculates weighted overall score from multiple category scores.
    /// Expects weights to be non-negative. If total weight is zero, returns 0.
    /// </summary>
    public static double CalculateWeightedScore(IEnumerable<(double score, double weight)> categoryScores)
    {
        double totalWeight = 0.0;
        double weightedSum = 0.0;
        foreach (var (score, weight) in categoryScores)
        {
            if (weight <= 0) continue;
            weightedSum += score * weight;
            totalWeight += weight;
        }

        if (totalWeight == 0.0) return 0.0;
        return weightedSum / totalWeight;
    }
}
