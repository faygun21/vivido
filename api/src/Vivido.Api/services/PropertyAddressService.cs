namespace Vivido.Api.services;

using Microsoft.EntityFrameworkCore;
using Vivido.Application.dtos.property;
using Vivido.Infrastructure.Data;

/// <summary>
/// Konutun adresini üretir: en yakın adlı sokak + mahalle.
///
/// NEDEN HAM SQL
/// PostGIS'in KNN operatörü (<c>geom &lt;-&gt; geom</c>) LINQ'te ifade
/// edilemiyor. Alternatif <c>ST_Distance</c> ile sıralamaktı ama o, GiST
/// indeksini KULLANMAZ: her konut için 6.845 sokak parçasının tamamı
/// taranırdı. KNN operatörü indeksten sırayla okuduğu için ilk satırı
/// bulunca duruyor.
///
/// NEDEN TERS GEOKODLAMA DEĞİL — bkz. db/schema/009_add_streets.sql başlığı.
/// Özet: Nominatim saniyede 1 istek sınırlı ve toplu geokodlamayı yasaklıyor;
/// 20 konutluk liste 20 saniye sürerdi ve IP yasağı konum aramasını da
/// birlikte öldürürdü. Aynı OSM verisi zaten yerelde.
/// </summary>
public class PropertyAddressService
{
    private readonly VividoDbContext _context;

    public PropertyAddressService(VividoDbContext context)
    {
        _context = context;
    }

    /// <summary>Tüm konutlar Çankaya kesitinden üretiliyor — sabit.</summary>
    private const string District = "Çankaya";
    private const string City = "Ankara";

    /// <summary>
    /// Sokak araması için yarıçap, derece cinsinden (~330 m).
    ///
    /// Sınır olmadan KNN her zaman BİR sokak döner — konut şehir dışında
    /// olsa bile kilometrelerce uzaktaki bir sokağı adres diye yazardı.
    /// `&amp;&amp;` (bbox kesişimi) GiST indeksini kullanır, `ST_DWithin`in
    /// geography'ye çevirme maliyetini ödemeye gerek yok.
    /// </summary>
    private const double SearchRadiusDeg = 0.003;

    private sealed record AddressRow(long PropertyId, string? StreetName, string? NeighborhoodName);

    /// <summary>
    /// Verilen konutların adreslerini TEK sorguda çeker.
    ///
    /// Konut başına ayrı sorgu N+1 demekti: 20 konutluk liste 20 gidiş-dönüş.
    /// </summary>
    public async Task<Dictionary<long, PropertyAddressDto>> GetAddressesAsync(
        IReadOnlyCollection<long> propertyIds,
        CancellationToken ct = default)
    {
        var result = new Dictionary<long, PropertyAddressDto>();
        if (propertyIds.Count == 0) return result;

        var ids = propertyIds.ToArray();

        // `streets` boş olabilir (05_load_streets.sh çalıştırılmadıysa) —
        // o durumda alt sorgu NULL döner ve adres mahalleye düşer. Hata YOK,
        // sadece sokak adı görünmez.
        // ⚠️ Sütun takma adları snake_case OLMAK ZORUNDA. DbContext
        // `UseSnakeCaseNamingConvention()` kullanıyor ve bu, ham SQL
        // sonuçlarının eşlenmesinde de geçerli: `AS "StreetName"` yazınca EF
        // `street_name` sütununu arar ve "The required column ... was not
        // present" ile patlar.
        var rows = await _context.Database
            .SqlQuery<AddressRow>($"""
                SELECT p.id AS property_id,
                       (SELECT s.name
                          FROM streets s
                         WHERE s.geom && ST_Expand(p.geom, {SearchRadiusDeg})
                         ORDER BY s.geom <-> p.geom
                         LIMIT 1) AS street_name,
                       n.name AS neighborhood_name
                  FROM properties p
                  LEFT JOIN neighborhoods n ON n.id = p.neighborhood_id
                 WHERE p.id = ANY({ids})
                """)
            .ToListAsync(ct);

        foreach (var row in rows)
        {
            result[row.PropertyId] = new PropertyAddressDto(
                StreetName: row.StreetName,
                NeighborhoodName: NormalizeNeighborhood(row.NeighborhoodName),
                DistrictName: District,
                CityName: City);
        }

        return result;
    }

    /// <summary>Tek konut için kısayol.</summary>
    public async Task<PropertyAddressDto> GetAddressAsync(long propertyId, CancellationToken ct = default)
    {
        var addresses = await GetAddressesAsync(new[] { propertyId }, ct);
        return addresses.TryGetValue(propertyId, out var address)
            ? address
            : new PropertyAddressDto(null, null, District, City);
    }

    /// <summary>
    /// OSM'den gelen mahalle adları "Kurtuluş" gibi çıplak geliyor; kullanıcı
    /// bir adreste "Kurtuluş Mah." görmeyi bekler. Zaten "Mahallesi" ile
    /// bitenlere ikinci kez eklemiyoruz.
    /// </summary>
    private static string? NormalizeNeighborhood(string? name)
    {
        if (string.IsNullOrWhiteSpace(name)) return null;

        var trimmed = name.Trim();
        if (trimmed.EndsWith("Mah.", StringComparison.OrdinalIgnoreCase) ||
            trimmed.EndsWith("Mahallesi", StringComparison.OrdinalIgnoreCase))
        {
            return trimmed;
        }

        return $"{trimmed} Mah.";
    }
}
