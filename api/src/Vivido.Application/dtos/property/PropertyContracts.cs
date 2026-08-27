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
    /// Yoğunluk bonusu, puan cinsinden (±3). 0 = etkisiz. "300 m'de 1
    /// market" ile "5 market" artık aynı skoru vermiyor; kullanıcı farkı
    /// görebilsin.
    /// </summary>
    double DensityBonus
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

/// <summary>
/// GeoJSON MultiPolygon — anchor koridoru artık kopuk parçalardan oluşabilir
/// (OSRM'in rota bulamadığı bacaklar ayrı birer daire olarak kalır), bu
/// yüzden HER ZAMAN MultiPolygon: tek parçalı koridorlar da 1 elemanlı bir
/// MultiPolygon'a sarılıyor. Her polygon tek dış halka, delik yok.
/// `{ type: "MultiPolygon", coordinates: [[[[lon,lat],...]], ...] }`.
/// </summary>
public record PolygonGeoJsonDto(
    string Type,
    List<List<List<double[]>>> Coordinates
);

/// <summary>
/// `GET /properties/top` yanıtı.
///
/// Anchor (özel yer) koridorunda hiç ev yoksa <c>Items</c> boş olabilir —
/// bu durumda <c>NearestFallback</c>, koridora EN YAKIN bütçeye uygun evi
/// taşır ("burada yok ama en yakını şu" demek için). Anchor'lar yoksa ya
/// da <c>showAll=true</c> ile filtre kapatıldıysa <c>CorridorPolygon</c> null.
///
/// ⚠️ GEÇİCİ: <c>CorridorPolygon</c> şu an bilerek kullanıcıya haritada
/// GÖSTERİLİYOR — mentor alanın nasıl hesaplandığını gözle kontrol etmek
/// istedi. Onay sonrası bu alan gizlenecek (frontend'de render edilmeyecek),
/// DTO'dan çıkarmaya gerek yok.
/// </summary>
public record TopPropertiesResponseDto(
    IReadOnlyList<PropertySummaryDto> Items,
    PropertySummaryDto? NearestFallback,
    PolygonGeoJsonDto? CorridorPolygon
);

/// <summary>
/// `GET /properties` yanıtı — harita pinleri + (varsa) anchor koridoru.
/// Bkz. <see cref="TopPropertiesResponseDto"/>'daki "GEÇİCİ" notu; aynısı
/// burada da geçerli.
/// </summary>
public record PropertiesMapResponseDto(
    IReadOnlyList<PropertyMapItemDto> Items,
    PolygonGeoJsonDto? CorridorPolygon
);
