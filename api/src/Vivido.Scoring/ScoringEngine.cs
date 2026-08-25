namespace Vivido.Scoring;

using System;
using System.Collections.Generic;

public static class ScoringEngine
{
    /// <summary>
    /// t_ideal altında bırakılan tavan yumuşatma payı (0-100 ölçeğinde).
    /// Eskiden süre t_ideal'in altındaysa kategori skoru HER ZAMAN tam 100
    /// oluyordu — 50m'deki market ile 500m'deki market ayırt edilemiyordu,
    /// bu da çok sayıda evin aynı (100) skora yığılmasına yol açıyordu.
    /// Artık t_ideal'in altında da hafif bir eğim var: tam konumda 100,
    /// t_ideal'e yaklaştıkça (100-K)'ya iniyor.
    /// </summary>
    private const double CeilingSoftening = 8.0;

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
        if (duration <= 0) return 100.0;

        if (duration <= tIdeal)
        {
            // Yol A: tavan artık düz değil — tam konumda 100, t_ideal'e
            // yaklaştıkça (100-CeilingSoftening)'e iniyor.
            return 100.0 - CeilingSoftening * (duration / tIdeal);
        }

        if (duration >= tCutoff) return 0.0;

        // Orta segment artık 100'den değil, üstteki yumuşatılmış tavandan
        // (100-K) başlıyor — süreklilik bozulmasın diye.
        double softCeiling = 100.0 - CeilingSoftening;

        if (duration <= tHalf)
        {
            return softCeiling - (softCeiling - 50.0) * ((duration - tIdeal) / (tHalf - tIdeal));
        }
        else
        {
            return 50.0 - 50.0 * ((duration - tHalf) / (tCutoff - tHalf));
        }
    }
}
