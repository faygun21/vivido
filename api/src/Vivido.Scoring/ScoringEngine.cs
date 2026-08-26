namespace Vivido.Scoring;

using System;
using System.Collections.Generic;
using System.Linq;

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
    /// Zayıf halka cezasının EN SERT hâli — en zayıf kategori 0 puan VE bu
    /// kategori kullanıcı için tam önemliyken (bkz. <see
    /// cref="WeakLinkFullPenaltyWeight"/>) skor en fazla yarıya iner. Daha az
    /// önemli bir kategori zayıfsa ceza bu tavana kadar SEYRELİR (bkz.
    /// <see cref="WeakLinkFullPenaltyWeight"/>) — 0.5 sabit bir taban değil,
    /// artık üst sınır.
    /// </summary>
    private const double WeakLinkPenaltyFloor = 0.5;

    /// <summary>
    /// Zayıf halka cezasının ağırlığa göre ölçeklendiği referans nokta.
    ///
    /// Öncesinde ceza yalnızca en zayıf kategorinin PUANINA bakıyordu —
    /// kullanıcının EN önemli saydığı kategori (örn. ağırlık 0.30) kötüyse
    /// ile zar zor eşiği geçen bir kategori (ağırlık 0.06) kötüyse AYNI
    /// cezayı veriyordu. Artık ceza kategorinin ağırlığına göre de
    /// ölçekleniyor: ağırlığı bu referansa (persona'lardaki en yüksek
    /// değerlere yakın, ör. 0.259) eşit ya da üstündeyse TAM ceza (0.5)
    /// uygulanır; eşiğe (0.05) yakın, zar zor önemli bir kategori en kötü
    /// olsa bile ceza çok daha hafif kalır.
    /// </summary>
    private const double WeakLinkFullPenaltyWeight = 0.25;

    /// <summary>
    /// Cezaya hangi kategoriler dahil olur — kullanıcının persona'sında
    /// ağırlığı bu eşiğin altındaki kategoriler (örn. öğrenci için okul,
    /// ağırlık 0) hiç önemsenmiyor demektir; oraya uzak olmak cezalandırmaz.
    /// </summary>
    private const double WeakLinkWeightThreshold = 0.05;

    /// <summary>
    /// Yoğunluk çarpanının alt/üst sınırı — bir kategori ne kadar POI-zengin
    /// ya da POI-fakir olursa olsun skor en fazla ±%10 değişir. Amaç ince bir
    /// ayrıştırma sinyali, kategori skorunu domine eden bir faktör değil.
    /// </summary>
    private const double DensityFactorMin = 0.9;
    private const double DensityFactorMax = 1.1;

    /// <summary>Yoğunluk oranındaki her birim sapmanın çarpana katkısı.</summary>
    private const double DensityBonusRate = 0.05;

    public record CategoryInput(
        double DurationMinutes,
        double Weight,
        double TIdeal,
        double THalf,
        double TCutoff,
        /// <summary>
        /// Bu kategoride, konudun arama yarıçapında (poi_categories.search_radius_m)
        /// bulunan POI sayısı. Veri henüz yoksa (backfill/ETL tamamlanmadıysa)
        /// null bırakılır — bu durumda yoğunluk çarpanı devre dışı kalır (1.0),
        /// eski davranışla birebir aynı sonucu verir.
        /// </summary>
        int? PoiCountInRadius = null,
        /// <summary>Referans "yeterli sayılır" eşiği (poi_categories.min_poi_count).</summary>
        int? MinPoiCount = null,
        /// <summary>
        /// Kategori kodu (`market`, `transit`…). Skor hesabına GİRMEZ; yalnızca
        /// gerekçe satırlarının hangi kategoriye ait olduğunu taşır.
        ///
        /// ⚠️ Konumu bilerek EN SONDA: mevcut çağıranlar ve
        /// `ScoringEngineTests` bu kaydı POZİSYONEL kuruyor
        /// (`new(duration, weight, tIdeal, tHalf, tCutoff, poiCount, minPoiCount)`),
        /// araya eklenseydi hepsi sessizce yanlış alana yazardı.
        /// </summary>
        string Code = ""
    );

    /// <summary>
    /// Tek bir kategorinin skora nasıl katkı verdiği — W6 gerekçe tablosunun
    /// bir satırı.
    /// </summary>
    /// <param name="SubScore">
    /// Bozunum skoru, yoğunluk çarpanı UYGULANMIŞ hâli. Kullanıcıya
    /// "bu kriter kaç puan aldı" olarak gösterilen değer bu.
    /// </param>
    /// <param name="NormalizedWeight">
    /// Ham ağırlığın, HESABA GİREN kategorilerin toplamına bölünmüş hâli.
    /// Ham ağırlığı göstermek yanıltıcı olurdu: persona ağırlığı 0 olan ya da
    /// erişim matrisinde satırı bulunmayan kategoriler hesap dışı kalıyor,
    /// dolayısıyla kalanların gerçek etkisi ham değerinden büyük oluyor.
    /// </param>
    /// <param name="Contribution">
    /// <c>SubScore × NormalizedWeight</c> — yani ağırlıklı ortalamaya katkısı.
    /// Zayıf halka cezası BURAYA dağıtılmaz; ayrı bir satır olarak durur
    /// (bkz. <see cref="ScoreBreakdown.WeakLinkPenalty"/>).
    /// </param>
    /// <param name="DensityFactor">
    /// Yoğunluk çarpanı (0.9–1.1). Veri yoksa 1.0.
    /// </param>
    public record CategoryResult(
        string Code,
        double DurationMinutes,
        double TIdeal,
        double TCutoff,
        double SubScore,
        double Weight,
        double NormalizedWeight,
        double Contribution,
        int? PoiCountInRadius,
        double DensityFactor
    );

    /// <summary>
    /// Skorun tamamı ve onu oluşturan satırlar.
    ///
    /// ⭐ DEĞİŞMEZLİK: <c>Σ Categories.Contribution + WeakLinkPenalty == Total</c>
    /// (yuvarlama payı hariç). Arayüzdeki TOPLAM satırı bunu toplayarak
    /// gösteriyor; tutmazsa ekranda anında görünür.
    /// </summary>
    /// <param name="WeightedAverage">Ceza uygulanmadan ÖNCEKİ ağırlıklı ortalama.</param>
    /// <param name="WeakLinkPenalty">
    /// Zayıf halka cezasının puan cinsinden karşılığı — <b>negatif ya da 0</b>.
    ///
    /// Ceza motorda son skoru ÇARPAN olarak kısıyor (<c>ortalama × faktör</c>),
    /// yani doğrusal değil. Kategorilerin katkılarına dağıtsaydık ceza
    /// görünmez olurdu: kullanıcı "market 18 puan getirdi" satırını okurken
    /// o 18'in içine sessizce serpiştirilmiş bir cezayı fark edemezdi.
    /// Bunun yerine 01-PROJE-PLANI §6.5'in "CES düzeltmesi" satırı gibi
    /// AÇIK bir satır olarak duruyor.
    /// </param>
    /// <param name="WeakLinkCode">
    /// Cezayı tetikleyen (en zayıf) kategorinin kodu — "bu evi aşağı çeken
    /// şey şu" diyebilmek için. Ceza yoksa null.
    /// </param>
    public record ScoreBreakdown(
        double Total,
        IReadOnlyList<CategoryResult> Categories,
        double WeightedAverage,
        double WeakLinkPenalty,
        string? WeakLinkCode
    );

    /// <summary>
    /// Toplam skoru döner.
    ///
    /// ⚠️ Formülün TEK kopyası <see cref="CalculateBreakdown"/> içindedir; bu
    /// metot ona devrediyor. Gerekçe tablosu ayrı bir yerde yeniden
    /// hesaplansaydı, motorun mantığı değiştiğinde tablo ile skor sessizce
    /// ayrışırdı — kullanıcı "77 puan" görürken satırların toplamı 71 ederdi
    /// (K-16).
    /// </summary>
    public static double CalculateScore(IEnumerable<CategoryInput> inputs)
        => CalculateBreakdown(inputs).Total;

    /// <summary>
    /// Toplam skoru ve onu oluşturan satırları birlikte hesaplar.
    /// </summary>
    public static ScoreBreakdown CalculateBreakdown(IEnumerable<CategoryInput> inputs)
    {
        // İki kez dolaşıyoruz (önce toplam ağırlık, sonra normalize katkı);
        // çağıran bir kez okunabilen bir dizi verirse ikinci tur boş kalırdı.
        var usable = inputs.Where(i => i.Weight > 0).ToList();

        double totalWeightUsed = usable.Sum(i => i.Weight);
        if (totalWeightUsed <= 0)
        {
            return new ScoreBreakdown(0.0, Array.Empty<CategoryResult>(), 0.0, 0.0, null);
        }

        // Zayıf halka cezası için: yalnızca kullanıcının gerçekten önemsediği
        // (ağırlığı eşiğin üstünde) kategoriler arasındaki en kötüsü izlenir.
        // Ağırlığı da birlikte tutuyoruz — cezanın şiddeti artık buna bağlı.
        double worstConsideredScore = 100.0;
        double worstConsideredWeight = 0.0;
        string? worstCode = null;
        bool anyConsidered = false;

        double totalScore = 0.0;
        var categories = new List<CategoryResult>(usable.Count);

        foreach (var input in usable)
        {
            double decayScore = CalculateDecayScore(
                input.DurationMinutes,
                input.TIdeal,
                input.THalf,
                input.TCutoff
            );

            double densityFactor = DensityFactorOf(input.PoiCountInRadius, input.MinPoiCount);
            double categoryScore = ApplyDensityFactor(decayScore, densityFactor);

            totalScore += categoryScore * input.Weight;

            if (input.Weight >= WeakLinkWeightThreshold)
            {
                anyConsidered = true;
                if (categoryScore < worstConsideredScore)
                {
                    worstConsideredScore = categoryScore;
                    worstConsideredWeight = input.Weight;
                    worstCode = input.Code;
                }
            }

            double normalizedWeight = input.Weight / totalWeightUsed;

            categories.Add(new CategoryResult(
                Code: input.Code,
                DurationMinutes: input.DurationMinutes,
                TIdeal: input.TIdeal,
                TCutoff: input.TCutoff,
                SubScore: Math.Round(categoryScore, 2),
                Weight: input.Weight,
                NormalizedWeight: normalizedWeight,
                Contribution: Math.Round(categoryScore * normalizedWeight, 2),
                PoiCountInRadius: input.PoiCountInRadius,
                DensityFactor: densityFactor
            ));
        }

        double weightedAverage = totalScore / totalWeightUsed;

        // Zayıf halka ağırlığı referansa (0.25) eşit/üstündeyse TAM ceza
        // tavanı (0.5) uygulanır; eşiğe (0.05) yakınsa ceza çok daha hafif
        // kalır — kullanıcının EN önemli saydığı yer kötüyse ile zar zor
        // önemli bir yer kötüyse artık aynı cezayı vermiyor.
        double weightSeverity = anyConsidered
            ? Math.Clamp(worstConsideredWeight / WeakLinkFullPenaltyWeight, 0.0, 1.0)
            : 0.0;
        double effectivePenaltyFloor = 1.0 - (1.0 - WeakLinkPenaltyFloor) * weightSeverity;

        double penaltyFactor = anyConsidered
            ? effectivePenaltyFloor + (1.0 - effectivePenaltyFloor) * (worstConsideredScore / 100.0)
            : 1.0;

        // 4 ondalık: 2 ondalıkla farklı iki gerçek skorun aynı sayıya
        // yuvarlanıp sahte bir "eşit skor" görüntüsü vermesini önlüyor.
        // Gösterimde (frontend) yine 0 ondalıkla yuvarlanabilir.
        double total = Math.Round(weightedAverage * penaltyFactor, 4);

        // Ceza puan cinsinden: negatif ya da 0. Satırların toplamına
        // eklendiğinde `total`ı vermeli.
        double penaltyPoints = Math.Round(total - weightedAverage, 2);

        return new ScoreBreakdown(
            Total: total,
            Categories: categories,
            WeightedAverage: Math.Round(weightedAverage, 2),
            WeakLinkPenalty: penaltyPoints,
            // Ceza fiilen sıfırsa "en zayıf kategori" diye bir suçlu göstermek
            // yanıltıcı olur — o kategori aslında sorun değil.
            WeakLinkCode: penaltyPoints < -0.005 ? worstCode : null
        );
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

    /// <summary>
    /// Yoğunluk çarpanını hesaplar; veri yoksa 1.0 (etkisiz) döner.
    ///
    /// Çarpanı uygulamaktan AYRI bir metot çünkü gerekçe tablosu çarpanın
    /// kendisini de gösteriyor ("300 m'de 5 market") — uygulanmış sonuçtan
    /// geri hesaplamak clamp yüzünden mümkün değil.
    /// </summary>
    private static double DensityFactorOf(int? poiCountInRadius, int? minPoiCount)
    {
        if (poiCountInRadius is not int count || minPoiCount is not int minCount || minCount <= 0)
        {
            return 1.0;
        }

        double ratio = (double)count / minCount;
        double factor = 1.0 + DensityBonusRate * (ratio - 1.0);
        return Math.Clamp(factor, DensityFactorMin, DensityFactorMax);
    }

    private static double ApplyDensityFactor(double categoryScore, double densityFactor)
        => Math.Clamp(categoryScore * densityFactor, 0.0, 100.0);
}
