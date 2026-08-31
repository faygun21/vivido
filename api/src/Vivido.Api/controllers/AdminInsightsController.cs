using System.Diagnostics;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Api.services;
using Vivido.Infrastructure.Data;
using Vivido.Infrastructure.Routing;

namespace Vivido.Api.Controllers;

/// <summary>
/// Sistem sağlığı ve kullanım metrikleri.
///
/// Kullanıcı yönetiminden AYRI bir sınıf: ikisi farklı sorulara cevap
/// veriyor ("bu kullanıcıya ne yapayım?" ile "sistem ayakta mı?") ve tek
/// dosyada toplamak ikisini de okunmaz hâle getirirdi. Rota öneki aynı,
/// yetki aynı.
/// </summary>
[ApiController]
[Route("api/v1/admin")]
[Authorize(Policy = "AdminOnly")]
public class AdminInsightsController : ControllerBase
{
    private readonly VividoDbContext _db;
    private readonly OsrmOptions _osrm;
    private readonly IHttpClientFactory _httpFactory;

    public AdminInsightsController(
        VividoDbContext db,
        OsrmOptions osrm,
        IHttpClientFactory httpFactory)
    {
        _db = db;
        _osrm = osrm;
        _httpFactory = httpFactory;
    }

    /// <summary>
    /// Bağımlı servislerin ve veri kümesinin durumu.
    ///
    /// ⚠️ NEDEN VAR: bu projede OSRM İKİ GÜN çöküktü ve kimse fark etmedi —
    /// site tamamen sağlıklı görünürken yalnızca "Rota Oluştur" 503
    /// dönüyordu. Arıza sessiz olduğu için ancak kullanıcı şikâyet edince
    /// ortaya çıktı. Bu uç, o sessizliği kırmak için var.
    /// </summary>
    [HttpGet("system-health")]
    public async Task<IActionResult> GetSystemHealth(CancellationToken ct)
    {
        // Servisleri PARALEL yokluyoruz: sırayla yapılsaydı biri zaman
        // aşımına uğradığında panel saniyelerce boş beklerdi.
        var osrmCar = ProbeOsrmAsync(_osrm.CarUrl, RoutingProfile.Driving, ct);
        var osrmFoot = ProbeOsrmAsync(_osrm.FootUrl, RoutingProfile.Foot, ct);
        var database = ProbeDatabaseAsync(ct);

        await Task.WhenAll(osrmCar, osrmFoot, database);

        // Veri sayımları tek turda; hepsi indeksli COUNT, maliyeti düşük.
        var propertyCount = await _db.Properties.CountAsync(ct);
        var poiCount = await _db.Pois.CountAsync(ct);
        var neighborhoodCount = await _db.Neighborhoods.CountAsync(ct);
        var accessCount = await _db.PropertyPoiAccesses.CountAsync(ct);

        // Veri sürümü: konutlardan okunuyor. Farklı sürümler bir arada
        // görünüyorsa ETL yarım kalmış demektir — bu yüzden tek değer değil
        // DAĞILIM döndürüyoruz.
        var dataVersions = await _db.Properties
            .GroupBy(p => p.DataVersion)
            .Select(g => new DataVersionCountDto(g.Key, g.Count()))
            .ToListAsync(ct);

        return Ok(new SystemHealthDto(
            await osrmCar,
            await osrmFoot,
            await database,
            new DataCountsDto(
                propertyCount,
                poiCount,
                neighborhoodCount,
                accessCount,
                dataVersions)));
    }

    /// <summary>
    /// Kullanım ve skor metrikleri.
    ///
    /// Skor dağılımı, motor kalibrasyonu değiştiğinde etkisini görmeyi
    /// sağlıyor: bu projede bir güncelleme medyanı 93.8'den 75.1'e indirdi
    /// ve o an ölçmek için elle SQL yazmak gerekmişti.
    /// </summary>
    [HttpGet("metrics")]
    public async Task<IActionResult> GetMetrics(CancellationToken ct)
    {
        var userCount = await _db.Users.CountAsync(ct);
        var verifiedCount = await _db.Users.CountAsync(u => u.EmailVerifiedAt != null, ct);
        var adminCount = await _db.Users.CountAsync(u => u.IsAdmin, ct);
        var profileCount = await _db.UserProfiles.CountAsync(ct);
        var anchorCount = await _db.Anchors.CountAsync(ct);
        var favoriteCount = await _db.FavoriteProperties.CountAsync(ct);
        var routeCount = await _db.Routes.CountAsync(ct);

        var personaCounts = await _db.UserProfiles
            .Where(p => p.PersonaCode != null)
            .GroupBy(p => p.PersonaCode!)
            .Select(g => new PersonaCountDto(g.Key, g.Count()))
            .OrderByDescending(x => x.Count)
            .ToListAsync(ct);

        // ⚠️ Skorlar ScoreCache'ten okunuyor, canlı hesaplanmıyor: 6.000
        // konutu her panel açılışında yeniden skorlamak saniyeler sürerdi.
        // Önbellek boşsa dağılım da boş döner — bu bir hata değil, "henüz
        // kimse skorlamayı tetiklemedi" demek.
        var scores = await _db.ScoreCaches
            .Select(s => s.TotalScore)
            .ToListAsync(ct);

        return Ok(new MetricsDto(
            new UserMetricsDto(
                userCount,
                verifiedCount,
                adminCount,
                profileCount,
                anchorCount,
                favoriteCount,
                routeCount,
                personaCounts),
            BuildScoreDistribution(scores)));
    }

    /// <summary>
    /// Skorları bantlara ayırır.
    ///
    /// ⚠️ EŞİKLER BURADA TEKRAR YAZILMIYOR: <see cref="PropertyScoreBreakdownService.BandOf"/>
    /// kullanılıyor. Eşikleri kopyalamak, panelin gösterdiği dağılımın
    /// kullanıcının gördüğü rozetlerden sessizce ayrılmasına yol açardı —
    /// aynı ev panelde "İyi", detay ekranında "Orta" görünürdü.
    ///
    /// O fonksiyon da `packages/shared/src/utils.ts` `scoreBand()` ve
    /// mobildeki `AppColors.band()` ile senkron tutuluyor.
    /// </summary>
    private static ScoreDistributionDto BuildScoreDistribution(List<decimal> scores)
    {
        if (scores.Count == 0)
            return new ScoreDistributionDto(0, 0, 0, 0, 0, null, 0, 0);

        var sorted = scores.OrderBy(x => x).ToList();
        var median = sorted.Count % 2 == 1
            ? sorted[sorted.Count / 2]
            : (sorted[sorted.Count / 2 - 1] + sorted[sorted.Count / 2]) / 2;

        var bands = scores
            .GroupBy(s => PropertyScoreBreakdownService.BandOf((double)s))
            .ToDictionary(g => g.Key, g => g.Count());

        int Band(string name) => bands.TryGetValue(name, out var count) ? count : 0;

        return new ScoreDistributionDto(
            Band("excellent"),
            Band("good"),
            Band("fair"),
            Band("poor"),
            scores.Count,
            (double)Math.Round(median, 1),
            // Uç değerler kalibrasyon sorununun en hızlı göstergesi: çok
            // sayıda konut tam 100 alıyorsa tavan yumuşatma çalışmıyor
            // demektir (bu projede bir ara 767 konut 100 alıyordu).
            scores.Count(s => s >= 99.995m),
            scores.Count(s => s <= 0.005m));
    }

    private async Task<ServiceProbeDto> ProbeOsrmAsync(
        string baseUrl,
        string profile,
        CancellationToken ct)
    {
        // Çankaya içinden kısa bir rota: veri yüklüyse milisaniyeler sürer.
        var url =
            $"{baseUrl.TrimEnd('/')}/route/v1/{profile}/32.85,39.92;32.86,39.93";

        return await ProbeAsync(url, ct);
    }

    private async Task<ServiceProbeDto> ProbeAsync(string url, CancellationToken ct)
    {
        var started = Stopwatch.GetTimestamp();
        try
        {
            using var client = _httpFactory.CreateClient();
            // Panel bekletmesin: sağlık yoklaması uzun sürerse zaten "sorun
            // var" demektir, cevabı beklemeye gerek yok.
            client.Timeout = TimeSpan.FromSeconds(5);

            using var response = await client.GetAsync(url, ct);
            var ms = (int)Stopwatch.GetElapsedTime(started).TotalMilliseconds;

            return response.IsSuccessStatusCode
                ? new ServiceProbeDto(true, ms, null)
                : new ServiceProbeDto(false, ms, $"HTTP {(int)response.StatusCode}");
        }
        catch (Exception ex)
        {
            return new ServiceProbeDto(
                false,
                (int)Stopwatch.GetElapsedTime(started).TotalMilliseconds,
                ex is TaskCanceledException ? "Zaman aşımı" : ex.GetType().Name);
        }
    }

    private async Task<ServiceProbeDto> ProbeDatabaseAsync(CancellationToken ct)
    {
        var started = Stopwatch.GetTimestamp();
        try
        {
            await _db.Database.ExecuteSqlRawAsync("SELECT 1", ct);
            return new ServiceProbeDto(
                true,
                (int)Stopwatch.GetElapsedTime(started).TotalMilliseconds,
                null);
        }
        catch (Exception ex)
        {
            return new ServiceProbeDto(
                false,
                (int)Stopwatch.GetElapsedTime(started).TotalMilliseconds,
                ex.GetType().Name);
        }
    }
}

/// <summary>Tek bir bağımlılığın yoklama sonucu.</summary>
public record ServiceProbeDto(bool Healthy, int ElapsedMs, string? Error);

public record DataVersionCountDto(string DataVersion, int Count);

public record DataCountsDto(
    int Properties,
    int Pois,
    int Neighborhoods,
    int AccessRows,
    IReadOnlyList<DataVersionCountDto> DataVersions
);

public record SystemHealthDto(
    ServiceProbeDto OsrmCar,
    ServiceProbeDto OsrmFoot,
    ServiceProbeDto Database,
    DataCountsDto Data
);

public record PersonaCountDto(string PersonaCode, int Count);

public record UserMetricsDto(
    int Users,
    int Verified,
    int Admins,
    int Profiles,
    int Anchors,
    int Favorites,
    int Routes,
    IReadOnlyList<PersonaCountDto> Personas
);

public record ScoreDistributionDto(
    int Excellent,
    int Good,
    int Fair,
    int Poor,
    int Total,
    double? Median,
    /// <summary>Tam 100 alan konut sayısı — tavan yumuşatma göstergesi.</summary>
    int AtCeiling,
    /// <summary>0 alan konut sayısı.</summary>
    int AtFloor
);

public record MetricsDto(UserMetricsDto Users, ScoreDistributionDto Scores);
