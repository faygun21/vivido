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

    /// <summary>
    /// Zayıf halka cezası — bir kategori kullanıcının önemsediği bir alanda
    /// çok kötüyse (örn. ulaşıma çok uzak), diğer kategoriler bunu ağırlıklı
    /// ortalamayla tam telafi edemesin diye son skoru bu kadara kadar
    /// kısabilir. 0.5 = en kötü durumda (en zayıf kategori 0) skor en fazla
    /// yarıya iner; en zayıf kategori 100 ise hiç ceza yok.
    /// </summary>
    private const double WeakLinkPenaltyFloor = 0.5;

    /// <summary>
    /// Cezaya hangi kategoriler dahil olur — kullanıcının persona'sında
    /// ağırlığı bu eşiğin altındaki kategoriler (örn. öğrenci için okul,
    /// ağırlık 0) hiç önemsenmiyor demektir; oraya uzak olmak cezalandırmaz.
    /// </summary>
    private const double WeakLinkWeightThreshold = 0.05;

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

        // Zayıf halka cezası için: yalnızca kullanıcının gerçekten önemsediği
        // (ağırlığı eşiğin üstünde) kategoriler arasındaki en kötüsü izlenir.
        double worstConsideredScore = 100.0;
        bool anyConsidered = false;

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

            if (input.Weight >= WeakLinkWeightThreshold)
            {
                anyConsidered = true;
                if (categoryScore < worstConsideredScore) worstConsideredScore = categoryScore;
            }
        }

        if (totalWeightUsed <= 0) return 0.0;

        double weightedAverage = totalScore / totalWeightUsed;

        double penaltyFactor = anyConsidered
            ? WeakLinkPenaltyFloor + (1.0 - WeakLinkPenaltyFloor) * (worstConsideredScore / 100.0)
            : 1.0;

        return Math.Round(weightedAverage * penaltyFactor, 2);
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
