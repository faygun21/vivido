using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Vivido.Api.Services;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

/// <summary>
/// Yönetim uçları. Tümü <c>AdminOnly</c> politikası altında.
///
/// ⚠️ İLK ADMİN NASIL OLUŞUR: <c>BootstrapAdmin:Email</c> ile. Buradaki
/// "admin yap" ucu da <c>AdminOnly</c> istediği için, o yapılandırma boşsa
/// hiç kimse admin olamaz — admin olmak için admin gerekir. Bu değer uzun
/// süre yalnızca <c>appsettings.Development.json</c> içinde tanımlıydı ve
/// panel sunucuda hiç kullanılamadı.
/// </summary>
[ApiController]
[Route("api/v1/admin")]
[Authorize(Policy = "AdminOnly")]
public class AdminController : ControllerBase
{
    /// <summary>Tek sayfada dönebilecek en fazla kayıt.</summary>
    private const int MaxPageSize = 100;
    private const int DefaultPageSize = 25;

    private readonly VividoDbContext _db;
    private readonly ILogger<AdminController> _logger;
    private readonly EmailOptions _email;
    private readonly AuthOptions _auth;

    public AdminController(
        VividoDbContext db,
        ILogger<AdminController> logger,
        IOptions<EmailOptions> email,
        IOptions<AuthOptions> auth)
    {
        _db = db;
        _logger = logger;
        _email = email.Value;
        _auth = auth.Value;
    }

    /// <summary>
    /// Kullanıcıları sayfalı ve aranabilir biçimde listeler.
    ///
    /// ⚠️ Eskiden TÜM kullanıcılar tek istekte dönüyordu ve arama yalnızca
    /// tarayıcıda yapılıyordu: kullanıcı sayısı arttıkça hem yanıt büyür hem
    /// de "arama" gelmemiş kayıtları bulamaz hâle gelirdi. Filtre artık
    /// veritabanında.
    /// </summary>
    [HttpGet("users")]
    public async Task<IActionResult> GetUsers(
        [FromQuery] string? search = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = DefaultPageSize,
        CancellationToken ct = default)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, MaxPageSize);

        var query = _db.Users.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            // `email` sütunu citext: karşılaştırma zaten büyük/küçük harf
            // duyarsız. DisplayName için ILIKE'a karşılık gelen EF çevirisi
            // kullanılıyor.
            query = query.Where(u =>
                EF.Functions.ILike(u.Email, $"%{term}%") ||
                (u.DisplayName != null &&
                 EF.Functions.ILike(u.DisplayName, $"%{term}%")));
        }

        var total = await query.CountAsync(ct);

        var items = await query
            .OrderByDescending(u => u.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(u => new AdminUserDto(
                u.Id,
                u.Email,
                u.DisplayName,
                u.IsAdmin,
                u.IsActive,
                // ⭐ Doğrulama durumu ARTIK GÖRÜNÜR. Panelde yokken, kaydolup
                // kodu hiç alamamış kullanıcıyı normal kullanıcıdan ayırmanın
                // yolu yoktu.
                u.EmailVerifiedAt,
                u.CreatedAt))
            .ToListAsync(ct);

        return Ok(new AdminUserPageDto(items, page, pageSize, total));
    }

    /// <summary>
    /// Tek kullanıcının destek görünümü: profili, önemli konumları, favori
    /// ve rota sayıları.
    ///
    /// ⚠️ NEDEN VAR: "skorlar bana yanlış geliyor" diyen bir kullanıcıya
    /// bakmanın hiçbir yolu yoktu. Skor tamamen profile bağlı (persona
    /// ağırlıkları, kriter sırası, bütçe, önemli konumlar); bunları
    /// görmeden şikâyeti değerlendirmek mümkün değil.
    ///
    /// ⛔ Parola/token DÖNMEZ. Favori ve rotaların yalnızca SAYISI veriliyor,
    /// içerikleri değil — destek için sayı yeterli, ötesi gereksiz bir
    /// mahremiyet ihlali olurdu.
    /// </summary>
    [HttpGet("users/{id:guid}")]
    public async Task<IActionResult> GetUserDetail(
        Guid id,
        CancellationToken ct = default)
    {
        var user = await _db.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == id, ct);

        if (user is null)
            return ApiProblem.Build(404, "Kullanıcı bulunamadı", "USER_NOT_FOUND");

        var profile = await _db.UserProfiles
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.UserId == id, ct);

        AdminProfileDto? profileDto = null;

        if (profile is not null)
        {
            var order = await _db.UserProfileCategoryOrders
                .AsNoTracking()
                .Where(o => o.ProfileId == profile.Id)
                .OrderBy(o => o.Priority)
                .Select(o => o.CategoryCode)
                .ToListAsync(ct);

            var anchors = await _db.Anchors
                .AsNoTracking()
                .Where(a => a.ProfileId == profile.Id)
                .OrderBy(a => a.Priority)
                .Select(a => new AdminAnchorDto(a.Label, a.Mode, a.Priority))
                .ToListAsync(ct);

            profileDto = new AdminProfileDto(
                profile.PersonaCode,
                profile.MinMonthlyBudget,
                profile.MaxMonthlyBudget,
                order,
                anchors);
        }

        var favoriteCount = await _db.FavoriteProperties.CountAsync(f => f.UserId == id, ct);
        var routeCount = await _db.Routes.CountAsync(r => r.UserId == id, ct);

        return Ok(new AdminUserDetailDto(
            user.Id,
            user.Email,
            user.DisplayName,
            user.IsAdmin,
            user.IsActive,
            user.EmailVerifiedAt,
            user.CreatedAt,
            profileDto,
            favoriteCount,
            routeCount));
    }

    /// <summary>Admin yetkisi verir / alır.</summary>
    [HttpPatch("users/{id:guid}/admin")]
    public async Task<IActionResult> SetAdmin(
        Guid id,
        [FromBody] SetAdminRequest request,
        CancellationToken ct = default)
    {
        var currentUserId = GetCurrentUserId();
        if (currentUserId is null) return Unauthorized();

        // Kendi yetkisini alması, sistemde hiç admin kalmamasına yol açabilir.
        if (currentUserId == id && !request.IsAdmin)
        {
            return ApiProblem.Build(
                400,
                "Kendi admin yetkinizi kaldıramazsınız",
                "ADMIN_SELF_DEMOTE",
                "Yetkiyi başka bir adminin kaldırması gerekir.");
        }

        var user = await _db.Users.FindAsync([id], ct);
        if (user is null) return ApiProblem.Build(404, "Kullanıcı bulunamadı", "USER_NOT_FOUND");

        user.IsAdmin = request.IsAdmin;
        await _db.SaveChangesAsync(ct);

        // Yetki değişikliği denetim izi: kim, kimi, ne yaptı.
        _logger.LogInformation(
            "Admin yetkisi {Action}: hedef {TargetId} · yapan {ActorId}",
            request.IsAdmin ? "verildi" : "kaldırıldı", id, currentUserId);

        return NoContent();
    }

    /// <summary>Hesabı aktif / pasif yapar.</summary>
    [HttpPatch("users/{id:guid}/active")]
    public async Task<IActionResult> SetActive(
        Guid id,
        [FromBody] SetActiveRequest request,
        CancellationToken ct = default)
    {
        var currentUserId = GetCurrentUserId();
        if (currentUserId is null) return Unauthorized();

        if (currentUserId == id && !request.IsActive)
        {
            return ApiProblem.Build(
                400,
                "Kendi hesabınızı pasif yapamazsınız",
                "ADMIN_SELF_DEACTIVATE",
                "Pasifleştirmeyi başka bir adminin yapması gerekir.");
        }

        var user = await _db.Users.FindAsync([id], ct);
        if (user is null) return ApiProblem.Build(404, "Kullanıcı bulunamadı", "USER_NOT_FOUND");

        user.IsActive = request.IsActive;
        await _db.SaveChangesAsync(ct);

        _logger.LogInformation(
            "Hesap {Action}: hedef {TargetId} · yapan {ActorId}",
            request.IsActive ? "aktifleştirildi" : "pasifleştirildi",
            id, currentUserId);

        return NoContent();
    }

    /// <summary>
    /// Kullanıcının e-postasını ELLE doğrulanmış sayar.
    ///
    /// ⚠️ NEDEN VAR: doğrulama kodu e-postayla gidiyor ve teslimat her zaman
    /// garantili değil. Kurum/üniversite sunucuları otomatik postaları
    /// sessizce reddedebiliyor; gönderen taraf 202 alıyor, kullanıcı kodu
    /// hiç görmüyor. Bu uç olmadan kullanıcı KALICI olarak kilitli kalıyordu:
    /// giriş doğrulama ister, doğrulama gelmeyen kodu ister.
    ///
    /// Kimliği doğrulamak adminin sorumluluğunda — bu yüzden denetim izine
    /// yazılıyor.
    /// </summary>
    [HttpPost("users/{id:guid}/verify-email")]
    public async Task<IActionResult> VerifyEmailManually(
        Guid id,
        CancellationToken ct = default)
    {
        var currentUserId = GetCurrentUserId();
        if (currentUserId is null) return Unauthorized();

        var user = await _db.Users.FindAsync([id], ct);
        if (user is null) return ApiProblem.Build(404, "Kullanıcı bulunamadı", "USER_NOT_FOUND");

        if (user.EmailVerifiedAt != null)
        {
            // Hata değil: istenen sonuç zaten sağlanmış. Aynı düğmeye iki kez
            // basmak kullanıcıya hata göstermemeli.
            return NoContent();
        }

        user.EmailVerifiedAt = DateTime.UtcNow;

        // Bekleyen doğrulama kodları geçersiz kılınıyor: hesap zaten
        // doğrulandı, elde kalan kodun geçerli olmasının bir anlamı yok.
        var pending = await _db.AuthCodes
            .Where(c => c.UserId == id && c.Purpose == AuthCodePurpose.EmailVerify)
            .ToListAsync(ct);
        _db.AuthCodes.RemoveRange(pending);

        await _db.SaveChangesAsync(ct);

        _logger.LogWarning(
            "E-posta ELLE doğrulandı: hedef {TargetId} ({Email}) · yapan {ActorId}. " +
            "Kimlik doğrulama adımı atlandı.",
            id, user.Email, currentUserId);

        return NoContent();
    }

    /// <summary>
    /// E-posta gönderim yapılandırmasının durumu.
    ///
    /// ⚠️ NEDEN VAR: "kod gönderildi ama ulaşmadı" durumunu sunucuya SSH ile
    /// bağlanmadan teşhis edebilmek için. Yanlış yapılandırmanın belirtisi
    /// sessiz oluyor — API 202 döner, log "teslim edildi" yazar, kullanıcı
    /// hiçbir şey almaz.
    ///
    /// ⛔ PAROLA DÖNDÜRÜLMEZ; yalnızca "tanımlı mı" bilgisi verilir.
    /// </summary>
    [HttpGet("email-status")]
    public IActionResult GetEmailStatus()
    {
        var user = _email.User?.Trim() ?? "";
        var from = string.IsNullOrWhiteSpace(_email.FromAddress)
            ? user
            : _email.FromAddress.Trim();

        // Gönderen ile giriş yapılan hesabın farklı olması, teslimatın
        // sessizce kaybolmasının en sık sebebi: alıcı tarafta SPF/DKIM
        // hizalaması tutmaz ve katı alan adları postayı reddeder.
        var senderAligned = string.Equals(from, user, StringComparison.OrdinalIgnoreCase);

        return Ok(new EmailStatusDto(
            _email.Provider,
            _email.Host,
            _email.Port,
            user,
            from,
            !string.IsNullOrWhiteSpace(_email.Password),
            senderAligned,
            _auth.RequireEmailVerification));
    }

    /// <summary>
    /// JWT içindeki kullanıcı id'si.
    ///
    /// ASP.NET "sub" claim'ini NameIdentifier'a map edebildiği için birkaç
    /// adı sırayla deniyoruz.
    /// </summary>
    private Guid? GetCurrentUserId()
    {
        var userIdValue =
            User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? User.FindFirst(JwtRegisteredClaimNames.Sub)?.Value
            ?? User.FindFirst("sub")?.Value;

        return Guid.TryParse(userIdValue, out var userId) ? userId : null;
    }
}

public record AdminUserDto(
    Guid Id,
    string Email,
    string? DisplayName,
    bool IsAdmin,
    bool IsActive,
    /// <summary>NULL ise kullanıcı e-postasını hiç doğrulamadı.</summary>
    DateTime? EmailVerifiedAt,
    DateTime CreatedAt
);

public record AdminAnchorDto(string Label, string Mode, int Priority);

/// <summary>
/// Skoru belirleyen profil ayarları. Skor şikâyetlerini değerlendirmek için
/// gereken minimum bilgi.
/// </summary>
public record AdminProfileDto(
    string? PersonaCode,
    decimal? MinMonthlyBudget,
    decimal? MaxMonthlyBudget,
    /// <summary>Kriter sırası — önem sırasına göre kategori kodları.</summary>
    IReadOnlyList<string> CategoryOrder,
    IReadOnlyList<AdminAnchorDto> Anchors
);

public record AdminUserDetailDto(
    Guid Id,
    string Email,
    string? DisplayName,
    bool IsAdmin,
    bool IsActive,
    DateTime? EmailVerifiedAt,
    DateTime CreatedAt,
    /// <summary>Kullanıcı hiç profil oluşturmadıysa null.</summary>
    AdminProfileDto? Profile,
    int FavoriteCount,
    int RouteCount
);

public record AdminUserPageDto(
    IReadOnlyList<AdminUserDto> Items,
    int Page,
    int PageSize,
    int Total
);

/// <summary>
/// E-posta yapılandırma durumu. ⛔ Parola İÇERMEZ — yalnızca tanımlı olup
/// olmadığı bildirilir.
/// </summary>
public record EmailStatusDto(
    string Provider,
    string Host,
    int Port,
    string User,
    string FromAddress,
    bool PasswordConfigured,
    /// <summary>
    /// Gönderen adresi, SMTP'ye giriş yapılan hesapla aynı mı? FALSE ise
    /// posta "gönderildi" görünse bile katı alan adları reddedebilir.
    /// </summary>
    bool SenderAligned,
    bool RequireEmailVerification
);

public record SetAdminRequest(bool IsAdmin);

public record SetActiveRequest(bool IsActive);
