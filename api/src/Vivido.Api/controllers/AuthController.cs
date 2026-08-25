using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Vivido.Application.DTOs.Auth;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;
using Vivido.Api.Services;
using System.Security.Cryptography;
using System.Text;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/auth")]
public class AuthController : ControllerBase
{
    private readonly VividoDbContext _context;
    private readonly JwtService _jwtService;
    private readonly IConfiguration _config;
    private readonly AuthCodeService _codes;
    private readonly AuthOptions _authOptions;
    private readonly ILogger<AuthController> _logger;

    public AuthController(
        VividoDbContext context,
        JwtService jwtService,
        IConfiguration config,
        AuthCodeService codes,
        IOptions<AuthOptions> authOptions,
        ILogger<AuthController> logger)
    {
        _context = context;
        _jwtService = jwtService;
        _config = config;
        _codes = codes;
        _authOptions = authOptions.Value;
        _logger = logger;
    }

    // ══════════════════════════════════════════════════════════════
    //  Kayıt
    // ══════════════════════════════════════════════════════════════

    /// <summary>
    /// Yeni hesap açar.
    ///
    /// <c>Auth:RequireEmailVerification</c> açıkken (varsayılan) token DÖNMEZ:
    /// kullanıcı satırı doğrulanmamış olarak yaratılır, e-postaya 6 haneli kod
    /// gider ve yanıt <b>202 + verification_required</b> olur. Kapalıyken eski
    /// davranış sürer: <b>201 + token</b> (K-09).
    /// </summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request, CancellationToken ct)
    {
        var email = NormalizeEmail(request.Email);

        var errors = new Dictionary<string, string[]>();
        if (!IsValidEmail(email)) errors["email"] = ["Geçerli bir e-posta adresi girin."];
        if (!IsValidPassword(request.Password))
    errors["password"] = ["Parola en az 8 karakter olmalı; büyük harf, küçük harf, rakam ve özel karakter içermeli."];
        if (errors.Count > 0) return ApiProblem.Validation(errors);

        // citext sütunu büyük/küçük harf duyarsız karşılaştırır; NormalizeEmail
        // ayrıca baştaki/sondaki boşluğu alıyor. İkisi birden olmadan
        // " Ali@X.com " ile "ali@x.com" İKİ AYRI hesap açardı.
        var existing = await _context.Users.SingleOrDefaultAsync(u => u.Email == email, ct);

        if (existing != null && existing.EmailVerifiedAt != null)
        {
            return ApiProblem.EmailAlreadyExists(email);
        }

        User user;
        if (existing != null)
        {
            // Doğrulanmamış kayıt: e-posta rezerve edilmiş ama hesap hiç
            // etkinleşmemiş. Kullanıcı muhtemelen kodu kaçırdı ve baştan
            // deniyor — 409 ile duvara toslatmak yerine kaydı tazeliyoruz.
            // Güvenlik açığı değil: hesap sahibi olduğunu ancak e-postasındaki
            // kodu girerek kanıtlayabiliyor.
            existing.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);
            existing.DisplayName = string.IsNullOrWhiteSpace(request.DisplayName)
                ? existing.DisplayName
                : request.DisplayName!.Trim();
            user = existing;
        }
        else
        {
            user = new User
            {
                Email = email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
                DisplayName = string.IsNullOrWhiteSpace(request.DisplayName)
                    ? null
                    : request.DisplayName!.Trim(),
                EmailVerifiedAt = _authOptions.RequireEmailVerification ? null : DateTime.UtcNow,
            };
            _context.Users.Add(user);
        }

        try
        {
            await _context.SaveChangesAsync(ct);
        }
        catch (DbUpdateException ex) when (IsUniqueViolation(ex))
        {
            // Yarış durumu: iki istek aynı anda "kullanıcı yok" gördü.
            // users.email UNIQUE olduğu için ikincisi burada patlar —
            // yakalanmazsa 500 dönerdi, oysa bu tam olarak 409'dur.
            return ApiProblem.EmailAlreadyExists(email);
        }

        if (!_authOptions.RequireEmailVerification)
        {
            // Doğrulama sonradan kapatılmışsa elde doğrulanmamış eski kayıtlar
            // kalabilir. Kapalı moda geçmişken onları "doğrulanmamış" tutmak,
            // arayüzde sebepsiz bir uyarı rozetinden başka bir işe yaramaz.
            user.EmailVerifiedAt ??= DateTime.UtcNow;
            return Created(string.Empty, await IssueSessionAsync(user, ct));
        }

        var failure = await TryIssueCodeAsync(user, AuthCodePurpose.EmailVerify, ct);
        if (failure != null) return failure;

        return Accepted(PendingVerificationResponse.For(email, _authOptions.VerificationCodeMinutes));
    }

    /// <summary>
    /// E-postaya gelen kodu doğrular; başarılıysa hesabı etkinleştirir ve
    /// oturum açar (kullanıcı ayrıca giriş yapmak zorunda kalmaz).
    /// </summary>
    [HttpPost("verify-email")]
    public async Task<IActionResult> VerifyEmail([FromBody] VerifyEmailRequest request, CancellationToken ct)
    {
        var email = NormalizeEmail(request.Email);
        var user = await _context.Users.SingleOrDefaultAsync(u => u.Email == email, ct);

        // Kullanıcı yoksa da INVALID_CODE dönüyoruz: "bu e-posta kayıtlı değil"
        // demek, kayıtlı adresleri tarayan birine bedava bilgi vermek olur.
        if (user == null) return ApiProblem.InvalidCode();

        if (user.EmailVerifiedAt != null)
        {
            // Zaten doğrulanmış — kullanıcı geri tuşuna basmış olabilir.
            // Hata dönmek yerine oturum açmak doğru davranış.
            return Ok(await IssueSessionAsync(user, ct));
        }

        var result = await _codes.ConsumeAsync(user, AuthCodePurpose.EmailVerify, request.Code, ct);
        if (result is not AuthCodeService.VerifyResult.Valid) return CodeProblem(result);

        user.EmailVerifiedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(ct);

        _logger.LogInformation("E-posta doğrulandı: {UserId}", user.Id);
        return Ok(await IssueSessionAsync(user, ct));
    }

    /// <summary>Kod gelmediyse veya süresi dolduysa yenisini gönderir.</summary>
    [HttpPost("resend-verification")]
    public async Task<IActionResult> ResendVerification(
        [FromBody] ResendVerificationRequest request, CancellationToken ct)
    {
        var email = NormalizeEmail(request.Email);
        var user = await _context.Users.SingleOrDefaultAsync(u => u.Email == email, ct);

        // Hesap yok ya da zaten doğrulanmış → sessizce 202. Aksi halde bu uç
        // nokta "hangi e-postalar kayıtlı ve doğrulanmamış" sorusunun
        // cevabını dağıtan bir tarayıcıya dönerdi.
        if (user == null || user.EmailVerifiedAt != null)
        {
            return Accepted(PendingVerificationResponse.For(email, _authOptions.VerificationCodeMinutes));
        }

        var failure = await TryIssueCodeAsync(user, AuthCodePurpose.EmailVerify, ct);
        if (failure != null) return failure;

        return Accepted(PendingVerificationResponse.For(email, _authOptions.VerificationCodeMinutes));
    }

    // ══════════════════════════════════════════════════════════════
    //  Giriş
    // ══════════════════════════════════════════════════════════════

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request, CancellationToken ct)
    {
        var email = NormalizeEmail(request.Email);
        var user = await _context.Users.SingleOrDefaultAsync(u => u.Email == email, ct);

        // Kullanıcı yoksa veya şifre yanlışsa sözleşme gereği aynı hatayı dönüyoruz
        if (user == null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            return ApiProblem.InvalidCredentials();
        }

        // ⚠️ Sıra önemli: doğrulama kontrolü ŞİFREDEN SONRA. Önce yapılsaydı,
        // şifreyi bilmeyen biri "bu adres kayıtlı ama doğrulanmamış" bilgisini
        // öğrenirdi.
        if (_authOptions.RequireEmailVerification && user.EmailVerifiedAt == null)
        {
            return ApiProblem.EmailNotVerified();
        }

        return Ok(await IssueSessionAsync(user, ct));
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh([FromBody] RefreshRequest request, CancellationToken ct)
    {
        var hash = HashToken(request.RefreshToken);

        // Token'ı ve sahibini veritabanında arıyoruz
        var storedToken = await _context.RefreshTokens
            .Include(rt => rt.User)
            .SingleOrDefaultAsync(rt => rt.TokenHash == hash, ct);

        // Token bulunamazsa veya iptal edilmişse hata dön (Rotasyon güvenliği)
        if (storedToken == null || storedToken.RevokedAt != null)
        {
            return ApiProblem.Build(401, "Geçersiz token", "TOKEN_REVOKED");
        }

        // Token'ın süresi dolmuşsa hata dön
        if (storedToken.ExpiresAt < DateTime.UtcNow)
        {
            return ApiProblem.Build(401, "Token süresi dolmuş", "TOKEN_EXPIRED");
        }

        // Rotasyon Kuralı: Kullanılan eski token'ı iptal et
        storedToken.RevokedAt = DateTime.UtcNow;

        return Ok(await IssueSessionAsync(storedToken.User!, ct));
    }

    // ══════════════════════════════════════════════════════════════
    //  Şifre sıfırlama
    // ══════════════════════════════════════════════════════════════

    /// <summary>
    /// "Şifremi unuttum" — e-postaya 6 haneli sıfırlama kodu gönderir.
    ///
    /// ⚠️ Hesap var olmasa bile <b>her zaman 202</b> döner. Farklı yanıt
    /// vermek, bu uç noktayı "bu e-posta sistemde kayıtlı mı?" sorusuna
    /// cevap veren bir araca çevirirdi.
    /// </summary>
    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(
        [FromBody] ForgotPasswordRequest request, CancellationToken ct)
    {
        var email = NormalizeEmail(request.Email);
        var user = await _context.Users.SingleOrDefaultAsync(u => u.Email == email, ct);

        if (user != null)
        {
            try
            {
                await _codes.IssueAsync(user, AuthCodePurpose.PasswordReset, ct);
            }
            catch (Exception ex)
            {
                // Kullanıcıya yansıtmıyoruz (bkz. yukarıdaki not) ama sessizce
                // yutmak da olmaz — operasyon tarafı görmeli.
                _logger.LogError(ex, "Şifre sıfırlama e-postası gönderilemedi: {UserId}", user.Id);
            }
        }

        return Accepted(new MessageResponse(
            "reset_code_sent",
            $"{email} adresi kayıtlıysa 6 haneli bir sıfırlama kodu gönderdik. " +
            $"Kod {_authOptions.PasswordResetCodeMinutes} dakika geçerli."));
    }

    /// <summary>Kod + yeni şifre ile sıfırlamayı tamamlar.</summary>
    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(
        [FromBody] ResetPasswordRequest request, CancellationToken ct)
    {
       if (!IsValidPassword(request.NewPassword))
{
    return ApiProblem.Validation(new()
    {
        ["newPassword"] = ["Parola en az 8 karakter olmalı; büyük harf, küçük harf, rakam ve özel karakter içermeli."],
    });
}

        var email = NormalizeEmail(request.Email);
        var user = await _context.Users.SingleOrDefaultAsync(u => u.Email == email, ct);
        if (user == null) return ApiProblem.InvalidCode();

        var result = await _codes.ConsumeAsync(user, AuthCodePurpose.PasswordReset, request.Code, ct);
        if (result is not AuthCodeService.VerifyResult.Valid) return CodeProblem(result);

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);

        // Şifreyi sıfırlayan kişi çoğunlukla hesabının ele geçirildiğinden
        // şüpheleniyor. Açık refresh token'ları iptal etmezsek saldırgan
        // 14 gün boyunca oturumda kalmaya devam ederdi (K-03).
        var now = DateTime.UtcNow;
        await _context.RefreshTokens
            .Where(rt => rt.UserId == user.Id && rt.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(rt => rt.RevokedAt, now), ct);

        // Sıfırlama kodunu e-postasından okuyabilen kişi adresin sahibidir;
        // hesap doğrulanmamışsa bu aynı zamanda doğrulama kanıtıdır.
        user.EmailVerifiedAt ??= now;

        await _context.SaveChangesAsync(ct);

        _logger.LogInformation("Şifre sıfırlandı, tüm oturumlar kapatıldı: {UserId}", user.Id);
        return Ok(new MessageResponse(
            "password_reset",
            "Şifreniz güncellendi. Yeni şifrenizle giriş yapabilirsiniz."));
    }

    // ══════════════════════════════════════════════════════════════
    //  Yardımcılar
    // ══════════════════════════════════════════════════════════════

    /// <summary>Yeni access + refresh token çifti üretir ve kaydeder.</summary>
    private async Task<AuthResponse> IssueSessionAsync(User user, CancellationToken ct)
    {
        var accessToken = _jwtService.GenerateAccessToken(user.Id, user.Email);
        var rawRefreshToken = _jwtService.GenerateRefreshToken();
        var expiresIn = int.Parse(_config["Jwt:AccessTokenMinutes"]!) * 60;

        _context.RefreshTokens.Add(new RefreshToken
        {
            UserId = user.Id,
            // BCrypt yerine veritabanında aranabilir SHA256 kullanıyoruz
            TokenHash = HashToken(rawRefreshToken),
            ExpiresAt = DateTime.UtcNow.AddDays(double.Parse(_config["Jwt:RefreshTokenDays"]!)),
        });
        await _context.SaveChangesAsync(ct);

        var authUser = new AuthUser(user.Id, user.Email, user.DisplayName, user.EmailVerifiedAt != null);
        return new AuthResponse(authUser, new TokenPair(accessToken, rawRefreshToken, expiresIn));
    }

    /// <summary>
    /// Kod üretip gönderir. Başarılıysa <c>null</c>, aksi halde döndürülecek
    /// hata yanıtını verir.
    /// </summary>
    private async Task<IActionResult?> TryIssueCodeAsync(User user, string purpose, CancellationToken ct)
    {
        try
        {
            var result = await _codes.IssueAsync(user, purpose, ct);
            return result == AuthCodeService.IssueResult.TooSoon
                ? ApiProblem.ResendTooSoon(_authOptions.ResendCooldownSeconds)
                : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Doğrulama e-postası gönderilemedi: {UserId}", user.Id);
            return ApiProblem.EmailSendFailed();
        }
    }

    private static ObjectResult CodeProblem(AuthCodeService.VerifyResult result) => result switch
    {
        AuthCodeService.VerifyResult.Expired => ApiProblem.CodeExpired(),
        AuthCodeService.VerifyResult.TooManyAttempts => ApiProblem.TooManyAttempts(),
        _ => ApiProblem.InvalidCode(),
    };
private static bool IsValidPassword(string? password)
{
    if (string.IsNullOrEmpty(password) || password.Length < 8)
        return false;

    return password.Any(char.IsUpper)
        && password.Any(char.IsLower)
        && password.Any(char.IsDigit)
        && password.Any(ch => !char.IsLetterOrDigit(ch));
}
    /// <summary>
    /// Baştaki/sondaki boşluğu atar.
    ///
    /// Küçük harfe çevirmiyoruz: sütun <c>citext</c>, karşılaştırma zaten
    /// duyarsız. Kullanıcının yazdığı biçim korunur, e-posta ona öyle gider.
    /// </summary>
    private static string NormalizeEmail(string? email) => (email ?? string.Empty).Trim();

    private static bool IsValidEmail(string email)
    {
        if (string.IsNullOrWhiteSpace(email) || email.Length > 254) return false;
        // MailAddress ayrıştırıcısı regex'ten daha güvenilir ve BCL'de hazır.
        return System.Net.Mail.MailAddress.TryCreate(email, out var parsed)
               && parsed.Address == email
               && email.Contains('.', StringComparison.Ordinal);
    }

    /// <summary>Npgsql'in "unique_violation" (SQLSTATE 23505) hatası mı?</summary>
    private static bool IsUniqueViolation(DbUpdateException ex) =>
        ex.InnerException is Npgsql.PostgresException { SqlState: "23505" };

    // Refresh token'ları veritabanında hızlıca bulabilmek için SHA256 ile şifreleyen yardımcı metot
    private static string HashToken(string token) =>
        Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
