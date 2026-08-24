namespace Vivido.Scoring;

using System;
using System.Collections.Generic;

public static class ScoringEngine
{
    public record CategoryInput(
        double DurationMinutes,
        double Weight,
        double TIdeal,
        double THalf,
        double TCutoff
    );

    public static double CalculateScore(IEnumerable<CategoryInput> inputs)
    {
        double totalScore = 0.0;
        double totalWeightUsed = 0.0;

        foreach (var input in inputs)
        {
            if (input.Weight <= 0) continue;

            double categoryScore = CalculateDecayScore(
                input.DurationMinutes, 
                input.TIdeal, 
                input.THalf, 
                input.TCutoff
            );

            totalScore += categoryScore * input.Weight;
            totalWeightUsed += input.Weight;
        }

        if (totalWeightUsed > 0)
        {
            return Math.Round(totalScore / totalWeightUsed, 2);
        }

        return 0.0;
    }

    private static double CalculateDecayScore(double duration, double tIdeal, double tHalf, double tCutoff)
    {
        if (duration <= tIdeal) return 100.0;
        if (duration >= tCutoff) return 0.0;

        if (duration <= tHalf)
        {
            return 100.0 - 50.0 * ((duration - tIdeal) / (tHalf - tIdeal));
        }
        else
        {
            return 50.0 - 50.0 * ((duration - tHalf) / (tCutoff - tHalf));
        }
    }
}