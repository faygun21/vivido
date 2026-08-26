namespace Vivido.Api.services;

using Microsoft.EntityFrameworkCore;
using Vivido.Application.dtos.property;
using Vivido.Infrastructure.Data;
using Vivido.Scoring;

/// <summary>
/// Skorun GEREKÇESİNİ üretir (W6): hangi kriter kaç puan kazandırdı,
/// hangisi kaybettirdi.
///
/// ⚠️ FORMÜLÜ BURADA YENİDEN HESAPLAMIYORUZ. Alt skorlar ve katkılar
/// <see cref="ScoringEngine.CalculateBreakdown"/>'dan geliyor; bu sınıf
/// yalnızca onları etiketleyip sıralıyor. İkinci bir kopya olsaydı motorun
/// mantığı değiştiğinde tablo ile skor sessizce ayrışırdı — kullanıcı
/// "77 puan" görürken satırların toplamı 71 ederdi.
///
/// <see cref="PropertyScoringService"/> ile ilişkisi: o, harita listesi için
/// cache'li TOPLAM skoru veriyor; bu sınıf aynı motoru aynı girdilerle
/// çalıştırıp satırları da üretiyor. Girdiler (erişim matrisi, persona
/// ağırlıkları, kategori eşikleri) aynı olduğu için liste skoru ile detay
/// skoru EŞİTTİR — R6'nın korunması buna dayanıyor.
/// </summary>
public class PropertyScoreBreakdownService
{
    private readonly VividoDbContext _context;

    public PropertyScoreBreakdownService(VividoDbContext context)
    {
        _context = context;
    }

    /// <summary>Bir kriterin en çok kaç puan kazandırabileceği: alt skor 100 iken.</summary>
    private const double PerfectSubScore = 100.0;

    public sealed record Breakdown(
        double Total,
        IReadOnlyList<ScoreRowDto> Rows,
        IReadOnlyList<ScoreRowDto> Strengths,
        IReadOnlyList<ScoreRowDto> Weaknesses,
        WeakLinkPenaltyDto? WeakLink = null);

    /// <summary>
    /// Verilen konutların skor kırılımını TEK sorgu turuyla hesaplar.
    ///
    /// Profil, persona ağırlıkları ve kategori eşikleri tüm konutlar için
    /// AYNI olduğundan bir kez çekilir; erişim matrisi de tek toplu sorguyla
    /// gelir. Konut başına ayrı sorgu N+1 demekti.
    /// </summary>
    public async Task<Dictionary<long, Breakdown>> GetBreakdownsAsync(
        IReadOnlyCollection<long> propertyIds,
        Guid profileId,
        CancellationToken ct = default)
    {
        var result = new Dictionary<long, Breakdown>();
        if (propertyIds.Count == 0) return result;

        var profile = await _context.UserProfiles
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == profileId, ct);

        if (profile is null) return result;

        var weights = await _context.PersonaCategoryWeights
            .Where(w => w.PersonaCode == profile.PersonaCode)
            .AsNoTracking()
            .ToDictionaryAsync(w => w.CategoryCode, w => (double)w.Weight, ct);

        // Aynı düzeltme PropertyScoringService'te de var: kullanıcının
        // özelleştirdiği kriter sırası burada da uygulanmazsa, listedeki
        // skor ile detay panelindeki gerekçe satırları birbirinden
        // sessizce ayrışır (liste doğru ağırlıkla sıralanır, panel yine
        // persona varsayılanını gösterir).
        var customOrder = await _context.UserProfileCategoryOrders
            .Where(o => o.ProfileId == profileId)
            .OrderBy(o => o.Priority)
            .Select(o => o.CategoryCode)
            .AsNoTracking()
            .ToListAsync(ct);

        weights = CategoryWeightResolver.Resolve(weights, customOrder);

        var categories = await _context.PoiCategories
            .Where(c => c.Active)
            .AsNoTracking()
            .ToDictionaryAsync(c => c.Code, c => c, ct);

        var accessLookup = (await _context.PropertyPoiAccesses
                .Where(pa => propertyIds.Contains(pa.PropertyId))
                .AsNoTracking()
                .ToListAsync(ct))
            .GroupBy(a => a.PropertyId)
            .ToDictionary(g => g.Key, g => g.ToList());

        foreach (var propertyId in propertyIds)
        {
            var inputs = new List<ScoringEngine.CategoryInput>();

            if (accessLookup.TryGetValue(propertyId, out var accesses))
            {
                foreach (var access in accesses)
                {
                    if (!weights.TryGetValue(access.CategoryCode, out var weight) || weight <= 0) continue;
                    if (!categories.TryGetValue(access.CategoryCode, out var cat)) continue;

                    inputs.Add(new ScoringEngine.CategoryInput(
                        DurationMinutes: (double)access.DurationMin,
                        Weight: weight,
                        TIdeal: (double)cat.TIdealMin,
                        THalf: (double)cat.THalfMin,
                        TCutoff: (double)cat.TCutoffMin,
                        // ⚠️ Yoğunluk girdileri PropertyScoringService ile
                        // BİREBİR aynı olmak zorunda: biri yoğunluğu geçip
                        // diğeri geçmeseydi listedeki skor ile detaydaki
                        // gerekçe farklı sayılara dayanırdı.
                        PoiCountInRadius: access.PoiCountInRadius,
                        MinPoiCount: cat.MinPoiCount,
                        Code: access.CategoryCode));
                }
            }

            result[propertyId] = ToBreakdown(ScoringEngine.CalculateBreakdown(inputs), categories);
        }

        return result;
    }

    private static Breakdown ToBreakdown(
        ScoringEngine.ScoreBreakdown engineResult,
        // ⚠️ `PoiCategory` global ad alanında (dosyada `namespace` satırı yok),
        // Vivido.Domain.Entities içinde DEĞİL — `Property` ve
        // `PropertyPoiAccess` de öyle.
        IReadOnlyDictionary<string, PoiCategory> categories)
    {
        var rows = engineResult.Categories
            .Select(c => new ScoreRowDto(
                CategoryCode: c.Code,
                Label: categories.TryGetValue(c.Code, out var cat) ? cat.DisplayNameTr : c.Code,
                DurationMin: Math.Round(c.DurationMinutes, 1),
                TargetMin: c.TIdeal,
                CutoffMin: c.TCutoff,
                SubScore: c.SubScore,
                Weight: Math.Round(c.NormalizedWeight, 3),
                Contribution: c.Contribution,
                Status: StatusOf(c.SubScore),
                PoiCountInRadius: c.PoiCountInRadius,
                DensityBonus: Math.Round(c.DensityBonus, 2)))
            // Katkısı yüksek olan üstte: tablo okunduğunda önce "bu evi ne
            // taşıyor" görünsün.
            .OrderByDescending(r => r.Contribution)
            .ToList();

        // Kayıp = bu kriterin kaçırdığı puan. Ağırlığı büyük ama alt skoru
        // düşük olan kriter en çok kaybettirendir — sadece "alt skoru en
        // düşük" demek yanıltıcı olurdu: persona için önemsiz bir kategorinin
        // 0 alması skoru neredeyse hiç düşürmüyor.
        double Loss(ScoreRowDto r) => (PerfectSubScore - r.SubScore) * r.Weight;

        var strengths = rows
            .Where(r => r.SubScore >= 70)
            .OrderByDescending(r => r.Contribution)
            .Take(4)
            .ToList();

        var weaknesses = rows
            .Where(r => r.SubScore < 70)
            .OrderByDescending(Loss)
            .Take(4)
            .ToList();

        // Zayıf halka cezası motorun SON adımında çarpan olarak uygulanıyor,
        // yani kategori katkılarına dağıtılamaz. Ayrı bir satır olarak
        // taşıyoruz ki `Σ katkı + ceza == total` tutsun ve kullanıcı puanın
        // nereye gittiğini görebilsin (01-PROJE-PLANI §6.5'in "CES
        // düzeltmesi" satırıyla aynı fikir).
        WeakLinkPenaltyDto? weakLink = null;
        if (engineResult.WeakLinkCode is not null)
        {
            var label = categories.TryGetValue(engineResult.WeakLinkCode, out var weakCat)
                ? weakCat.DisplayNameTr
                : engineResult.WeakLinkCode;

            weakLink = new WeakLinkPenaltyDto(
                CategoryCode: engineResult.WeakLinkCode,
                Label: label,
                Points: engineResult.WeakLinkPenalty,
                WeightedAverage: engineResult.WeightedAverage,
                Message: $"En zayıf kriterin ({label}) skoru düşük olduğu için "
                       + "toplam puan ayrıca kısıldı — güçlü kriterler bunu tamamen telafi edemiyor.");
        }

        return new Breakdown(engineResult.Total, rows, strengths, weaknesses, weakLink);
    }

    /// <summary>Alt skoru arayüzdeki renk bandına çevirir.</summary>
    private static string StatusOf(double subScore) => subScore switch
    {
        >= 85 => "strong",
        >= 70 => "good",
        >= 45 => "warning",
        _     => "weak",
    };

    /// <summary>
    /// Toplam skoru banda çevirir.
    ///
    /// ⚠️ Eşikler `packages/shared/src/utils.ts` içindeki `scoreBand()` ile
    /// AYNI olmak zorunda — web, mobil ve API aynı evi aynı renkte
    /// göstermeli.
    /// </summary>
    public static string BandOf(double total) => total switch
    {
        >= 85 => "excellent",
        >= 70 => "good",
        >= 55 => "fair",
        _     => "poor",
    };

    /// <summary>
    /// Kiranın kullanıcının bütçe aralığındaki yeri.
    ///
    /// ⚠️ SKORA GİRMEZ — mevcut motor yalnızca POI erişim sürelerini hesaba
    /// katıyor. Panelde ayrı ve açıkça etiketli bir bölüm olarak duruyor ki
    /// kullanıcı "bütçem skorumu düşürmüş" gibi yanlış bir sonuç çıkarmasın.
    /// </summary>
    public static BudgetFitDto BuildBudgetFit(
        decimal monthlyRent,
        decimal? minBudget,
        decimal? maxBudget)
    {
        double? ratio = maxBudget is > 0 ? (double)(monthlyRent / maxBudget.Value) : null;

        if (maxBudget is null && minBudget is null)
        {
            return new BudgetFitDto(monthlyRent, minBudget, maxBudget, null, "unknown",
                "Kira aralığı girilmemiş — bütçe uyumu hesaplanamıyor.");
        }

        if (maxBudget is not null && monthlyRent > maxBudget.Value)
        {
            var fark = monthlyRent - maxBudget.Value;
            return new BudgetFitDto(monthlyRent, minBudget, maxBudget, ratio, "over",
                $"Üst sınırını {fark:N0} ₺ aşıyor.");
        }

        if (minBudget is not null && monthlyRent < minBudget.Value)
        {
            return new BudgetFitDto(monthlyRent, minBudget, maxBudget, ratio, "under",
                "Alt sınırının altında — aradığından daha uygun bir ilan.");
        }

        if (ratio is >= 0.9)
        {
            return new BudgetFitDto(monthlyRent, minBudget, maxBudget, ratio, "tight",
                $"Üst sınırının %{ratio * 100:N0}'ini kullanıyor — sınırda.");
        }

        return new BudgetFitDto(monthlyRent, minBudget, maxBudget, ratio, "fits",
            ratio is not null
                ? $"Üst sınırının %{ratio * 100:N0}'ini kullanıyor — rahat."
                : "Bütçe aralığının içinde.");
    }
}
