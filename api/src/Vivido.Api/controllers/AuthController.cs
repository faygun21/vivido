using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Vivido.Application.DTOs.Auth;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;
using Vivido.Api.Services;
using Vivido.Api.services;
using System.Security.Cryptography;
using System.Text;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/auth")]
// Kaba kuvvet koruması: kayıt/giriş/kod uçları IP başına sınırlı — bkz.
// Program.cs "auth" rate limiter policy'si.
[EnableRateLimiting("auth")]
public class AuthController : ControllerBase
{
    /// <summary>Görünen ad için üst sınır — <c>users.display_name</c> sınırsız <c>text</c>.</summary>
    private const int MaxDisplayNameLength = 100;

    /// <summary>
    /// Var olmayan kullanıcı için çalıştırılan sahte parola hash'i —
    /// bkz. <see cref="Login"/> içindeki zamanlama notu.
    ///
    /// Sabit bir dizge gömmek yerine AÇILIŞTA üretiliyor: BCrypt'in
    /// varsayılan iş faktörü kütüphane sürümüyle değişebilir ve elle
    /// yazılmış bir hash o gün sessizce "gerçek doğrulamadan daha ucuz"
    /// hâle gelir — yani korumak istediğimiz zamanlama farkı geri döner.
    /// Aynı çağrıyla üretince maliyet her zaman eşleşir.
    /// </summary>
    private static readonly string DummyPasswordHash =
        BCrypt.Net.BCrypt.HashPassword(
            Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
        );

    private readonly VividoDbContext _context;
    private readonly JwtService _jwtService;
    private readonly JwtOptions _jwtOptions;
    private readonly AuthCodeService _codes;
    private readonly AuthOptions _authOptions;
    private readonly ILogger<AuthController> _logger;
    private readonly BootstrapAdminService _bootstrapAdmin;

    public AuthController(
        VividoDbContext context,
        JwtService jwtService,
        IOptions<JwtOptions> jwtOptions,
        AuthCodeService codes,
        IOptions<AuthOptions> authOptions,
        ILogger<AuthController> logger,
        BootstrapAdminService bootstrapAdmin)
    {
        _context = context;
        _jwtService = jwtService;
        _jwtOptions = jwtOptions.Value;
        _codes = codes;
        _authOptions = authOptions.Value;
        _logger = logger;
        _bootstrapAdmin = bootstrapAdmin;
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
    public async Task<IActionResult> Register(
        [FromBody] RegisterRequest request,
        CancellationToken ct)
    {
        var email = NormalizeEmail(request.Email);

        var errors = new Dictionary<string, string[]>();

        if (!IsValidEmail(email))
            errors["email"] = ["Geçerli bir e-posta adresi girin."];

        if (!IsValidPassword(request.Password))
        {
            errors["password"] =
            [
                "Parola en az 8 karakter olmalı; büyük harf, küçük harf, rakam ve özel karakter içermeli."
            ];
        }

        // `display_name` şemada sınırsız `text`. Üst sınır olmadan kayıt ucu,
        // istek gövdesi sınırına (~30 MB) kadar her şeyi kabul edip
        // veritabanına yazıyordu — kimlik doğrulaması İSTEMEYEN bir uçtan
        // bedava disk doldurma. Ayrıca bu değer admin panelinde listeleniyor.
        if (request.DisplayName is { } displayName &&
            displayName.Trim().Length > MaxDisplayNameLength)
        {
            errors["displayName"] =
            [
                $"Görünen ad en fazla {MaxDisplayNameLength} karakter olabilir."
            ];
        }

        if (errors.Count > 0)
            return ApiProblem.Validation(errors);

        // citext sütunu büyük/küçük harf duyarsız karşılaştırır; NormalizeEmail
        // ayrıca baştaki/sondaki boşluğu alıyor.
        var existing = await _context.Users
            .SingleOrDefaultAsync(u => u.Email == email, ct);

        if (existing != null && existing.EmailVerifiedAt != null)
        {
            return ApiProblem.EmailAlreadyExists(email);
        }

        User user;

        if (existing != null)
        {
            // Doğrulanmamış kayıt tekrar deneniyorsa bilgileri güncelliyoruz.
            existing.PasswordHash =
                BCrypt.Net.BCrypt.HashPassword(request.Password);

            existing.DisplayName =
                string.IsNullOrWhiteSpace(request.DisplayName)
                    ? existing.DisplayName
                    : request.DisplayName!.Trim();

            user = existing;
        }
        else
        {
            user = new User
            {
                Email = email,

                PasswordHash =
                    BCrypt.Net.BCrypt.HashPassword(request.Password),

                DisplayName =
                    string.IsNullOrWhiteSpace(request.DisplayName)
                        ? null
                        : request.DisplayName!.Trim(),

                EmailVerifiedAt =
                    _authOptions.RequireEmailVerification
                        ? null
                        : DateTime.UtcNow
            };

            _context.Users.Add(user);
        }

        try
        {
            await _context.SaveChangesAsync(ct);
        }
        catch (DbUpdateException ex) when (IsUniqueViolation(ex))
        {
            return ApiProblem.EmailAlreadyExists(email);
        }

        if (!_authOptions.RequireEmailVerification)
        {
            user.EmailVerifiedAt ??= DateTime.UtcNow;

            return Created(
                string.Empty,
                await IssueSessionAsync(user, ct)
            );
        }

        var failure = await TryIssueCodeAsync(
            user,
            AuthCodePurpose.EmailVerify,
            ct
        );

        if (failure != null)
            return failure;

        return Accepted(
            PendingVerificationResponse.For(
                email,
                _authOptions.VerificationCodeMinutes
            )
        );
    }

    /// <summary>
    /// E-postaya gelen kodu doğrular; başarılıysa hesabı etkinleştirir ve
    /// oturum açar.
    /// </summary>
    [HttpPost("verify-email")]
    public async Task<IActionResult> VerifyEmail(
        [FromBody] VerifyEmailRequest request,
        CancellationToken ct)
    {
        var email = NormalizeEmail(request.Email);

        var user = await _context.Users
            .SingleOrDefaultAsync(u => u.Email == email, ct);

        // Kullanıcı yoksa da INVALID_CODE dönüyoruz.
        if (user == null)
            return ApiProblem.InvalidCode();

        if (user.EmailVerifiedAt != null)
        {
            // Zaten doğrulanmış kullanıcı pasifse yeni oturum açtırma.
            if (!user.IsActive)
            {
                return ApiProblem.Build(
                    403,
                    "Hesabınız pasif durumda.",
                    "ACCOUNT_INACTIVE"
                );
            }

            return Ok(await IssueSessionAsync(user, ct));
        }

        var result = await _codes.ConsumeAsync(
            user,
            AuthCodePurpose.EmailVerify,
            request.Code,
            ct
        );

        if (result is not AuthCodeService.VerifyResult.Valid)
            return CodeProblem(result);

        user.EmailVerifiedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync(ct);

        _logger.LogInformation(
            "E-posta doğrulandı: {UserId}",
            user.Id
        );

        if (!user.IsActive)
        {
            return ApiProblem.Build(
                403,
                "Hesabınız pasif durumda.",
                "ACCOUNT_INACTIVE"
            );
        }

        return Ok(await IssueSessionAsync(user, ct));
    }

    /// <summary>
    /// Kod gelmediyse veya süresi dolduysa yenisini gönderir.
    /// </summary>
    [HttpPost("resend-verification")]
    public async Task<IActionResult> ResendVerification(
        [FromBody] ResendVerificationRequest request,
        CancellationToken ct)
    {
        var email = NormalizeEmail(request.Email);

        var user = await _context.Users
            .SingleOrDefaultAsync(u => u.Email == email, ct);

        if (user == null || user.EmailVerifiedAt != null)
        {
            return Accepted(
                PendingVerificationResponse.For(
                    email,
                    _authOptions.VerificationCodeMinutes
                )
            );
        }

        var failure = await TryIssueCodeAsync(
            user,
            AuthCodePurpose.EmailVerify,
            ct
        );

        if (failure != null)
            return failure;

        return Accepted(
            PendingVerificationResponse.For(
                email,
                _authOptions.VerificationCodeMinutes
            )
        );
    }

    // ══════════════════════════════════════════════════════════════
    //  Giriş
    // ══════════════════════════════════════════════════════════════

    [HttpPost("login")]
    public async Task<IActionResult> Login(
        [FromBody] LoginRequest request,
        CancellationToken ct)
    {
        var email = NormalizeEmail(request.Email);

        var user = await _context.Users
            .SingleOrDefaultAsync(u => u.Email == email, ct);

        // ⭐ KULLANICI SIZINTISI (user enumeration) — zamanlama üzerinden.
        //
        // Eskiden `user == null` kısa devre yapıyordu: kayıtlı OLMAYAN bir
        // e-posta için yanıt anında dönüyor, kayıtlı olan için BCrypt
        // doğrulaması (bilerek yavaş, ~100–300 ms) çalışıyordu. İkisi
        // arasındaki fark ölçülebilir büyüklükte; saldırgan sadece süreye
        // bakarak "bu adres Vivido'da kayıtlı mı" sorusunu güvenilir biçimde
        // cevaplayabiliyordu. Yanıt gövdesi aynı olduğu hâlde sızıntı devam
        // ediyordu.
        //
        // Çözüm: kullanıcı yoksa da AYNI maliyetli işi yap. `DummyPasswordHash`
        // gerçek bir hesaba ait değil; tek amacı BCrypt'i çalıştırmak.
        bool passwordMatches;

        if (user is null)
        {
            _ = BCrypt.Net.BCrypt.Verify(request.Password, DummyPasswordHash);
            passwordMatches = false;
        }
        else
        {
            passwordMatches = BCrypt.Net.BCrypt.Verify(
                request.Password,
                user.PasswordHash
            );
        }

        if (user is null || !passwordMatches)
        {
            return ApiProblem.InvalidCredentials();
        }

        if (_authOptions.RequireEmailVerification &&
            user.EmailVerifiedAt == null)
        {
            return ApiProblem.EmailNotVerified();
        }

        // Admin tarafından pasif yapılan kullanıcı yeni oturum açamaz.
        if (!user.IsActive)
        {
            return ApiProblem.Build(
                403,
                "Hesabınız pasif durumda.",
                "ACCOUNT_INACTIVE"
            );
        }

        return Ok(await IssueSessionAsync(user, ct));
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh(
        [FromBody] RefreshRequest request,
        CancellationToken ct)
    {
        var hash = HashToken(request.RefreshToken);

        var storedToken = await _context.RefreshTokens
            .Include(rt => rt.User)
            .SingleOrDefaultAsync(
                rt => rt.TokenHash == hash,
                ct
            );

        if (storedToken == null ||
            storedToken.RevokedAt != null)
        {
            return ApiProblem.Build(
                401,
                "Geçersiz token",
                "TOKEN_REVOKED"
            );
        }

        if (storedToken.ExpiresAt < DateTime.UtcNow)
        {
            return ApiProblem.Build(
                401,
                "Token süresi dolmuş",
                "TOKEN_EXPIRED"
            );
        }

        // Kullanıcı sonradan pasif yapılmışsa refresh ile yeni access token alamaz.
        if (storedToken.User == null ||
            !storedToken.User.IsActive)
        {
            storedToken.RevokedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync(ct);

            return ApiProblem.Build(
                403,
                "Hesabınız pasif durumda.",
                "ACCOUNT_INACTIVE"
            );
        }

        // Refresh token rotasyonu.
        storedToken.RevokedAt = DateTime.UtcNow;

        return Ok(
            await IssueSessionAsync(
                storedToken.User,
                ct
            )
        );
    }

    // ══════════════════════════════════════════════════════════════
    //  Şifre sıfırlama
    // ══════════════════════════════════════════════════════════════

    [HttpPost("forgot-password")]
    public async Task<IActionResult> ForgotPassword(
        [FromBody] ForgotPasswordRequest request,
        CancellationToken ct)
    {
        var email = NormalizeEmail(request.Email);

        var user = await _context.Users
            .SingleOrDefaultAsync(u => u.Email == email, ct);

        if (user != null)
        {
            try
            {
                await _codes.IssueAsync(
                    user,
                    AuthCodePurpose.PasswordReset,
                    ct
                );
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Şifre sıfırlama e-postası gönderilemedi: {UserId}",
                    user.Id
                );
            }
        }

        return Accepted(
            new MessageResponse(
                "reset_code_sent",
                $"{email} adresi kayıtlıysa 6 haneli bir sıfırlama kodu gönderdik. " +
                $"Kod {_authOptions.PasswordResetCodeMinutes} dakika geçerli."
            )
        );
    }

    [HttpPost("reset-password")]
    public async Task<IActionResult> ResetPassword(
        [FromBody] ResetPasswordRequest request,
        CancellationToken ct)
    {
        if (!IsValidPassword(request.NewPassword))
        {
            return ApiProblem.Validation(
                new Dictionary<string, string[]>
                {
                    ["newPassword"] =
                    [
                        "Parola en az 8 karakter olmalı; büyük harf, küçük harf, rakam ve özel karakter içermeli."
                    ]
                }
            );
        }

        var email = NormalizeEmail(request.Email);

        var user = await _context.Users
            .SingleOrDefaultAsync(u => u.Email == email, ct);

        if (user == null)
            return ApiProblem.InvalidCode();

        var result = await _codes.ConsumeAsync(
            user,
            AuthCodePurpose.PasswordReset,
            request.Code,
            ct
        );

        if (result is not AuthCodeService.VerifyResult.Valid)
            return CodeProblem(result);

        user.PasswordHash =
            BCrypt.Net.BCrypt.HashPassword(
                request.NewPassword
            );

        var now = DateTime.UtcNow;

        await _context.RefreshTokens
            .Where(
                rt =>
                    rt.UserId == user.Id &&
                    rt.RevokedAt == null
            )
            .ExecuteUpdateAsync(
                s => s.SetProperty(
                    rt => rt.RevokedAt,
                    now
                ),
                ct
            );

        user.EmailVerifiedAt ??= now;

        await _context.SaveChangesAsync(ct);

        _logger.LogInformation(
            "Şifre sıfırlandı, tüm oturumlar kapatıldı: {UserId}",
            user.Id
        );

        return Ok(
            new MessageResponse(
                "password_reset",
                "Şifreniz güncellendi. Yeni şifrenizle giriş yapabilirsiniz."
            )
        );
    }

    // ══════════════════════════════════════════════════════════════
    //  Yardımcılar
    // ══════════════════════════════════════════════════════════════

    /// <summary>
    /// Yeni access + refresh token çifti üretir ve kaydeder.
    /// </summary>
    private async Task<AuthResponse> IssueSessionAsync(
        User user,
        CancellationToken ct)
    {
        // İlk gerçek admin olarak ayarlanan e-posta ile eşleşiyorsa
        // kullanıcıya admin yetkisi ver.
        await _bootstrapAdmin.EnsureBootstrapAdminAsync(
            user,
            ct
        );

        var accessToken =
            _jwtService.GenerateAccessToken(
                user.Id,
                user.Email,
                user.IsAdmin
            );

        var rawRefreshToken =
            _jwtService.GenerateRefreshToken();

        var expiresIn = _jwtOptions.AccessTokenMinutes * 60;

        _context.RefreshTokens.Add(
            new RefreshToken
            {
                UserId = user.Id,

                TokenHash =
                    HashToken(rawRefreshToken),

                ExpiresAt =
                    DateTime.UtcNow.AddDays(_jwtOptions.RefreshTokenDays)
            }
        );

        await _context.SaveChangesAsync(ct);

        var authUser = new AuthUser(
            user.Id,
            user.Email,
            user.DisplayName,
            user.EmailVerifiedAt != null,
            user.IsAdmin
        );

        return new AuthResponse(
            authUser,
            new TokenPair(
                accessToken,
                rawRefreshToken,
                expiresIn
            )
        );
    }

    private async Task<IActionResult?> TryIssueCodeAsync(
        User user,
        string purpose,
        CancellationToken ct)
    {
        try
        {
            var result = await _codes.IssueAsync(
                user,
                purpose,
                ct
            );

            return result ==
                   AuthCodeService.IssueResult.TooSoon
                ? ApiProblem.ResendTooSoon(
                    _authOptions.ResendCooldownSeconds
                )
                : null;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Doğrulama e-postası gönderilemedi: {UserId}",
                user.Id
            );

            return ApiProblem.EmailSendFailed();
        }
    }

    private static ObjectResult CodeProblem(
        AuthCodeService.VerifyResult result)
        => result switch
        {
            AuthCodeService.VerifyResult.Expired
                => ApiProblem.CodeExpired(),

            AuthCodeService.VerifyResult.TooManyAttempts
                => ApiProblem.TooManyAttempts(),

            _ => ApiProblem.InvalidCode()
        };

    private static bool IsValidPassword(
        string? password)
    {
        if (string.IsNullOrEmpty(password) ||
            password.Length < 8)
        {
            return false;
        }

        return password.Any(char.IsUpper)
            && password.Any(char.IsLower)
            && password.Any(char.IsDigit)
            && password.Any(
                ch => !char.IsLetterOrDigit(ch)
            );
    }

    private static string NormalizeEmail(
        string? email)
        => (email ?? string.Empty).Trim();

    private static bool IsValidEmail(
        string email)
    {
        if (string.IsNullOrWhiteSpace(email) ||
            email.Length > 254)
        {
            return false;
        }

        return System.Net.Mail.MailAddress.TryCreate(
                   email,
                   out var parsed
               )
               && parsed.Address == email
               && email.Contains(
                   '.',
                   StringComparison.Ordinal
               );
    }

    private static bool IsUniqueViolation(
        DbUpdateException ex)
        => ex.InnerException
            is Npgsql.PostgresException
            {
                SqlState: "23505"
            };

    private static string HashToken(
        string token)
        => Convert.ToBase64String(
            SHA256.HashData(
                Encoding.UTF8.GetBytes(token)
            )
        );
}