namespace Vivido.Infrastructure.Routing;

/// <summary>
/// OSRM servis yapılandırması. `Routing__CarUrl` / `Routing__FootUrl` ortam
/// değişkenleri (konteyner/full profili) ya da `Routing:*` appsettings bölümüyle
/// gelir (docs/01-PROJE-PLANI.md §7).
/// </summary>
public sealed class OsrmOptions
{
    /// <summary>
    /// Car profili OSRM kök adresi — host'ta 5102 (docker-compose.yml
    /// `OSRM_CAR_HOST_PORT` varsayılanı, bkz. .env.example), konteynerde
    /// osrm-car:5000.
    /// </summary>
    public string CarUrl { get; set; } = "http://localhost:5102";

    /// <summary>
    /// Foot profili OSRM kök adresi — host'ta 5101 (docker-compose.yml
    /// `OSRM_FOOT_HOST_PORT` varsayılanı, bkz. .env.example), konteynerde
    /// osrm-foot:5000.
    /// </summary>
    public string FootUrl { get; set; } = "http://localhost:5101";

    /// <summary>OSRM /table üst sınırı (osrm-routed --max-table-size, varsayılan 200).</summary>
    public int MaxTableSize { get; set; } = 200;

    /// <summary>
    /// OSRM istek zaman aşımı (saniye).
    ///
    /// Eskiden 30sn'ydi — Çankaya ölçeğinde bir /table ya da /route isteği
    /// normalde milisaniyeler sürer; 30sn "OSRM hiç yanıt vermiyor"
    /// durumunu çok geç fark ettiriyordu (kullanıcı "Rota Oluştur"a bastıktan
    /// sonra donmuş gibi bekliyordu). 10sn, gerçek bir yavaşlığı normal bir
    /// gecikmeden ayırt etmeye yetecek kadar geniş, kullanıcıyı gereksiz
    /// bekletmeyecek kadar dar.
    /// </summary>
    public int TimeoutSeconds { get; set; } = 10;
}

/// <summary>Ulaşım modu → OSRM URL profili eşlemesi.</summary>
public static class RoutingProfile
{
    /// <summary>car.lua profili — OSRM URL'sinde "driving" olarak servis edilir.</summary>
    public const string Driving = "driving";

    /// <summary>foot.lua profili — ETL de aynı adı kullanır (data/scripts/02_build_access_matrix.py).</summary>
    public const string Foot = "foot";

    /// <summary>'car' → "driving", 'foot' → "foot"; bilinmeyen mod güvenli varsayılan olarak car.</summary>
    public static string ForMode(string mode) =>
        string.Equals(mode, "foot", StringComparison.OrdinalIgnoreCase) ? Foot : Driving;
}
