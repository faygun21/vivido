namespace Vivido.Scoring;

using System;
using System.Collections.Generic;
using System.Linq;

public static class ScoringEngine
{
    /// <param name="Code">
    /// Kategori kodu (`market`, `transit`…). Skor hesabına GİRMEZ; yalnızca
    /// gerekçe satırlarının hangi kategoriye ait olduğunu taşır. Varsayılanı
    /// boş olduğu için mevcut çağıranlar değişmeden derlenir.
    /// </param>
    public record CategoryInput(
        double DurationMinutes,
        double Weight,
        double TIdeal,
        double THalf,
        double TCutoff,
        string Code = ""
    );

    /// <summary>
    /// Tek bir kategorinin skora nasıl katkı verdiği — W6 gerekçe tablosunun
    /// bir satırı.
    /// </summary>
    /// <param name="NormalizedWeight">
    /// Ham ağırlığın, HESABA GİREN kategorilerin toplamına bölünmüş hâli.
    /// Ham ağırlığı göstermek yanıltıcı olurdu: persona ağırlığı 0 olan ya da
    /// erişim matrisinde satırı bulunmayan kategoriler hesap dışı kalıyor,
    /// dolayısıyla kalanların gerçek etkisi ham değerinden büyük oluyor.
    /// </param>
    /// <param name="Contribution">
    /// <c>SubScore × NormalizedWeight</c>. Tüm satırların toplamı
    /// <see cref="ScoreBreakdown.Total"/>'a eşittir (yuvarlama payı hariç).
    /// </param>
    public record CategoryResult(
        string Code,
        double DurationMinutes,
        double TIdeal,
        double TCutoff,
        double SubScore,
        double Weight,
        double NormalizedWeight,
        double Contribution
    );

    public record ScoreBreakdown(double Total, IReadOnlyList<CategoryResult> Categories);

    /// <summary>
    /// Toplam skoru döner.
    ///
    /// ⚠️ Formülün TEK kopyası <see cref="CalculateBreakdown"/> içindedir; bu
    /// metot ona devrediyor. Gerekçe tablosu ayrı bir yerde yeniden
    /// hesaplansaydı, motorun mantığı değiştiğinde tablo ile skor sessizce
    /// ayrışırdı — kullanıcı "77 puan" görürken satırların toplamı 71 ederdi.
    /// </summary>
    public static double CalculateScore(IEnumerable<CategoryInput> inputs)
        => CalculateBreakdown(inputs).Total;

    /// <summary>
    /// Toplam skoru ve onu oluşturan kategori satırlarını birlikte hesaplar.
    /// </summary>
    public static ScoreBreakdown CalculateBreakdown(IEnumerable<CategoryInput> inputs)
    {
        // İki kez dolaşıyoruz (önce toplam ağırlık, sonra normalize katkı);
        // çağıran bir kez okunabilen bir dizi verirse ikinci tur boş kalırdı.
        var usable = inputs.Where(i => i.Weight > 0).ToList();

        double totalWeightUsed = usable.Sum(i => i.Weight);

        if (totalWeightUsed <= 0)
        {
            return new ScoreBreakdown(0.0, Array.Empty<CategoryResult>());
        }

        var categories = new List<CategoryResult>(usable.Count);
        double weightedTotal = 0.0;

        foreach (var input in usable)
        {
            double subScore = CalculateDecayScore(
                input.DurationMinutes,
                input.TIdeal,
                input.THalf,
                input.TCutoff
            );

            double normalizedWeight = input.Weight / totalWeightUsed;

            weightedTotal += subScore * input.Weight;

            categories.Add(new CategoryResult(
                Code: input.Code,
                DurationMinutes: input.DurationMinutes,
                TIdeal: input.TIdeal,
                TCutoff: input.TCutoff,
                SubScore: Math.Round(subScore, 2),
                Weight: input.Weight,
                NormalizedWeight: normalizedWeight,
                Contribution: Math.Round(subScore * normalizedWeight, 2)
            ));
        }

        // Yuvarlama bilerek EN SONDA: satır satır yuvarlanmış değerleri
        // toplamak, toplamı 8 kategoride ±0.04'e kadar kaydırırdı.
        return new ScoreBreakdown(Math.Round(weightedTotal / totalWeightUsed, 2), categories);
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
