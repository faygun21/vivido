namespace Vivido.Application.dtos.property;

/// <summary>
/// Konutun konum bilgisi.
///
/// `properties` tablosunda adres sütunu YOK — sentetik konutlar gerçek bina
/// poligonlarının içine üretiliyor (K-06) ama adres taşımıyorlar. Sokak adı
/// `streets` tablosundan KNN ile bulunuyor, mahalle ise `neighborhood_id`
/// üzerinden. İkisi de NULL olabilir: `streets` yüklenmemişse
/// (`data/scripts/05_load_streets.sh`) sokak boş kalır ve arayüz mahalleye
/// düşer — hata değil, eksik veri.
///
/// ⚠️ Kapı numarası BİLEREK YOK. Sokak adı sentetik ilanı inandırıcı
/// kılıyor; kapı numarası ise gerçek bir konutu tekil olarak işaret ederdi.
/// </summary>
public record PropertyAddressDto(
    string? StreetName,
    string? NeighborhoodName,
    string DistrictName,
    string CityName
)
{
    /// <summary>Tek satırlık gösterim — arayüzün elle birleştirmesine gerek kalmasın.</summary>
    public string Formatted =>
        string.Join(", ", new[] { StreetName, NeighborhoodName, $"{DistrictName} / {CityName}" }
            .Where(part => !string.IsNullOrWhiteSpace(part)));
}

/// <summary>
/// Gerekçe tablosunun bir satırı (W6).
///
/// `Contribution` alanlarının toplamı `PropertyScoreDetailDto.Total`a eşittir.
/// </summary>
public record ScoreRowDto(
    string CategoryCode,
    string Label,
    double DurationMin,
    double TargetMin,
    double CutoffMin,
    double SubScore,
    double Weight,
    double Contribution,
    /// <summary>`strong` | `good` | `warning` | `weak` — arayüzdeki renk bandı.</summary>
    string Status,
    /// <summary>
    /// Arama yarıçapındaki POI sayısı. ETL bu sütunu doldurmadıysa null —
    /// o durumda yoğunluk çarpanı da devre dışıdır.
    /// </summary>
    int? PoiCountInRadius,
    /// <summary>
    /// Yoğunluk çarpanı (0.9–1.1). 1.0 = etkisiz. "300 m'de 1 market" ile
    /// "5 market" artık aynı skoru vermiyor; kullanıcı farkı görebilsin.
    /// </summary>
    double DensityFactor
);

/// <summary>
/// Zayıf halka cezası — skorun kategori katkılarıyla AÇIKLANAMAYAN kısmı.
///
/// Motor, kullanıcının önemsediği en kötü kategoriye bakıp son skoru çarpan
/// olarak kısıyor (en fazla yarıya). Bu doğrusal olmadığı için katkı
/// satırlarına dağıtılamaz: dağıtsaydık "market 18 puan getirdi" satırının
/// içine sessizce serpiştirilmiş bir ceza olurdu ve kullanıcı puanının nereye
/// gittiğini göremezdi. Bunun yerine AÇIK bir satır olarak duruyor
/// (01-PROJE-PLANI §6.5'teki "CES düzeltmesi" satırıyla aynı fikir).
/// </summary>
public record WeakLinkPenaltyDto(
    string CategoryCode,
    string Label,
    /// <summary>Puan cinsinden ceza — negatif.</summary>
    double Points,
    /// <summary>Ceza uygulanmadan önceki ağırlıklı ortalama.</summary>
    double WeightedAverage,
    string Message
);

/// <summary>
/// Kiranın kullanıcının bütçe aralığındaki yeri.
///
/// ⚠️ Bu bir SKOR BİLEŞENİ DEĞİLDİR. Mevcut skor motoru yalnızca POI
/// erişim sürelerini hesaba katıyor; bütçe skora hiç girmiyor. Panelde
/// ayrı ve açıkça etiketli bir bölüm olarak gösteriliyor ki kullanıcı
/// "bütçem skoru şu kadar düşürmüş" gibi yanlış bir sonuç çıkarmasın.
/// Motor bütçeyi hesaba katmaya başlarsa burası gerekçe satırına dönüşür.
/// </summary>
public record BudgetFitDto(
    decimal MonthlyRent,
    decimal? MinMonthlyBudget,
    decimal? MaxMonthlyBudget,
    /// <summary>Kira / üst bütçe. Bütçe girilmemişse null.</summary>
    double? RatioToMax,
    /// <summary>`under` | `fits` | `tight` | `over` | `unknown`</summary>
    string Status,
    string Message
);

/// <summary>Skorun tamamı ve gerekçesi.</summary>
public record PropertyScoreDetailDto(
    double Total,
    /// <summary>`excellent` | `good` | `fair` | `poor` — packages/shared `scoreBand()` ile aynı eşikler.</summary>
    string Band,
    IReadOnlyList<ScoreRowDto> Rows,
    /// <summary>Katkısı en yüksek satırlar — "neden uygun".</summary>
    IReadOnlyList<ScoreRowDto> Strengths,
    /// <summary>En çok puan kaybettiren satırlar — "neden uygun değil".</summary>
    IReadOnlyList<ScoreRowDto> Weaknesses,
    BudgetFitDto Budget,
    /// <summary>
    /// Zayıf halka cezası. Ceza yoksa (en zayıf kriter de iyiyse) null.
    ///
    /// ⭐ DEĞİŞMEZLİK: <c>Σ Rows.Contribution + (WeakLink?.Points ?? 0) == Total</c>
    /// </summary>
    WeakLinkPenaltyDto? WeakLink
);

/// <summary>
/// Liste ve favori kartlarında kullanılan özet.
/// Detay panelinin tamamını taşımaz; skor kırılımı yalnızca detayda gelir.
/// </summary>
public record PropertySummaryDto(
    string Id,
    string ExternalRef,
    decimal MonthlyRent,
    short AreaM2,
    string RoomCount,
    double Latitude,
    double Longitude,
    double TotalScore,
    string Band,
    PropertyAddressDto Address,
    /// <summary>En yüksek katkılı kriterin adı — kartta ✓ ile gösterilir.</summary>
    string? TopStrength,
    /// <summary>En çok puan kaybettiren kriterin adı — kartta ✗ ile gösterilir.</summary>
    string? TopWeakness,
    bool IsFavorite
);
