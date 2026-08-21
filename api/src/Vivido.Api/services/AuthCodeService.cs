using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Vivido.Application.Abstractions;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Services;

/// <summary>
/// Tek kullanımlık 6 haneli kodların üretimi, gönderimi ve doğrulanması.
///
/// E-posta doğrulama ve şifre sıfırlama aynı mantığı paylaşır; ikisini
/// ayrı yazmak aynı kaba kuvvet korumasını iki kez yazmak demekti (K-09).
/// </summary>
public class AuthCodeService
{
    private readonly VividoDbContext _context;
    private readonly IEmailSender _email;
    private readonly AuthOptions _options;

    public AuthCodeService(
        VividoDbContext context,
        IEmailSender email,
        IOptions<AuthOptions> options)
    {
        _context = context;
        _email = email;
        _options = options.Value;
    }

    /// <summary>Kod isteme sonucu.</summary>
    public enum IssueResult
    {
        Sent,
        /// <summary>Çok sık istendi — <c>ResendCooldownSeconds</c> dolmadı.</summary>
        TooSoon,
    }

    /// <summary>Kod doğrulama sonucu.</summary>
    public enum VerifyResult
    {
        Valid,
        /// <summary>Kod yok, yanlış veya zaten kullanılmış.</summary>
        Invalid,
        Expired,
        /// <summary>Deneme hakkı bitti; yeni kod istenmeli.</summary>
        TooManyAttempts,
    }

    /// <summary>
    /// Kullanıcı için yeni bir kod üretir, eskilerini iptal eder ve e-postayı gönderir.
    /// </summary>
    public async Task<IssueResult> IssueAsync(
        User user,
        string purpose,
        CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;

        var lastCode = await _context.AuthCodes
            .Where(c => c.UserId == user.Id && c.Purpose == purpose)
            .OrderByDescending(c => c.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);

        // Soğuma süresi: "kodu tekrar gönder" düğmesine basılı tutan biri
        // hem kendi gelen kutusunu doldurur hem Gmail'in günlük kotasını yer.
        if (lastCode != null &&
            lastCode.CreatedAt.AddSeconds(_options.ResendCooldownSeconds) > now)
        {
            return IssueResult.TooSoon;
        }

        // Yeni kod üretilince eskiler geçersiz olmalı. Aksi halde kullanıcı
        // 3 kod isteyip 3'ünü de kullanabilirdi — deneme hakkı üçe katlanırdı.
        await _context.AuthCodes
            .Where(c => c.UserId == user.Id && c.Purpose == purpose && c.ConsumedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(c => c.ConsumedAt, now), cancellationToken);

        var rawCode = GenerateCode();
        var minutes = purpose == AuthCodePurpose.PasswordReset
            ? _options.PasswordResetCodeMinutes
            : _options.VerificationCodeMinutes;

        var entity = new AuthCode
        {
            UserId = user.Id,
            Purpose = purpose,
            CodeHash = HashCode(rawCode, user.Id),
            ExpiresAt = now.AddMinutes(minutes),
            CreatedAt = now,
        };
        _context.AuthCodes.Add(entity);
        await _context.SaveChangesAsync(cancellationToken);

        var message = purpose == AuthCodePurpose.PasswordReset
            ? BuildPasswordResetEmail(user.Email, rawCode, minutes)
            : BuildVerificationEmail(user.Email, rawCode, minutes);

        try
        {
            await _email.SendAsync(message, cancellationToken);
        }
        catch
        {
            // Gönderilemeyen kodun satırı kalırsa iki zarar birden olur:
            // kullanıcının elinde olmayan bir kod geçerli sayılır ve soğuma
            // süresi "tekrar gönder"i 60 saniye bloklar. Satırı geri alıyoruz;
            // kullanıcı hemen yeniden deneyebilsin.
            _context.AuthCodes.Remove(entity);
            await _context.SaveChangesAsync(cancellationToken);
            throw;
        }

        return IssueResult.Sent;
    }

    /// <summary>
    /// Kodu doğrular ve geçerliyse TÜKETİR (ikinci kez kabul edilmez).
    /// </summary>
    public async Task<VerifyResult> ConsumeAsync(
        User user,
        string purpose,
        string submittedCode,
        CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;

        var code = await _context.AuthCodes
            .Where(c => c.UserId == user.Id && c.Purpose == purpose && c.ConsumedAt == null)
            .OrderByDescending(c => c.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);

        if (code == null) return VerifyResult.Invalid;

        if (code.ExpiresAt < now) return VerifyResult.Expired;

        if (code.Attempts >= _options.MaxCodeAttempts)
        {
            return VerifyResult.TooManyAttempts;
        }

        var submittedHash = HashCode(Normalize(submittedCode), user.Id);

        // Sabit zamanlı karşılaştırma: string eşitliği ilk farklı karakterde
        // döner ve teorik olarak kod karakter karakter tahmin edilebilir.
        var matches = CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(submittedHash),
            Encoding.UTF8.GetBytes(code.CodeHash));

        if (!matches)
        {
            code.Attempts++;
            await _context.SaveChangesAsync(cancellationToken);
            return code.Attempts >= _options.MaxCodeAttempts
                ? VerifyResult.TooManyAttempts
                : VerifyResult.Invalid;
        }

        code.ConsumedAt = now;
        await _context.SaveChangesAsync(cancellationToken);
        return VerifyResult.Valid;
    }

    /// <summary>Kullanıcının girdiği kodu boşluk/tire gürültüsünden arındırır.</summary>
    public static string Normalize(string? code) =>
        new((code ?? string.Empty).Where(char.IsDigit).ToArray());

    // ─────────────────────────────────────────────────────────────

    /// <summary>
    /// 000000–999999 arası kriptografik rastgele kod.
    ///
    /// <c>Random</c> DEĞİL: tahmin edilebilir bir üreteçle şifre sıfırlama
    /// kodu üretmek, kilidi kapıya asmak olur.
    /// </summary>
    private static string GenerateCode() =>
        RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");

    /// <summary>
    /// SHA-256(kod + ':' + userId).
    ///
    /// Kullanıcı kimliği tuz olarak giriyor — 6 haneli kodun 1.000.000
    /// hash'lik tablosu aksi halde saniyeler içinde üretilir ve
    /// veritabanı sızıntısı doğrudan hesap ele geçirmeye dönerdi.
    /// </summary>
    private static string HashCode(string code, Guid userId)
    {
        var bytes = Encoding.UTF8.GetBytes($"{code}:{userId}");
        return Convert.ToBase64String(SHA256.HashData(bytes));
    }

    private EmailMessage BuildVerificationEmail(string to, string code, int minutes) =>
        new(
            To: to,
            Subject: $"Vivido doğrulama kodun: {code}",
            HtmlBody: Template(
                "E-postanı doğrula",
                "Vivido hesabını etkinleştirmek için aşağıdaki kodu uygulamaya gir.",
                code,
                minutes,
                "Bu kaydı sen başlatmadıysan bu e-postayı yok sayabilirsin; hesap etkinleşmez."),
            TextBody:
                $"Vivido doğrulama kodun: {code}\n\n" +
                $"Kod {minutes} dakika geçerlidir.\n" +
                "Bu kaydı sen başlatmadıysan bu e-postayı yok sayabilirsin.");

    private EmailMessage BuildPasswordResetEmail(string to, string code, int minutes) =>
        new(
            To: to,
            Subject: $"Vivido şifre sıfırlama kodun: {code}",
            HtmlBody: Template(
                "Şifreni sıfırla",
                "Yeni şifreni belirlemek için aşağıdaki kodu uygulamaya gir.",
                code,
                minutes,
                "Şifre sıfırlama isteğini sen yapmadıysan bir şey yapmana gerek yok — mevcut şifren geçerli kalır."),
            TextBody:
                $"Vivido şifre sıfırlama kodun: {code}\n\n" +
                $"Kod {minutes} dakika geçerlidir.\n" +
                "İsteği sen yapmadıysan mevcut şifren geçerli kalır.");

    /// <summary>
    /// Ortak HTML iskeleti.
    ///
    /// Satır içi CSS: e-posta istemcileri &lt;style&gt; bloklarını ve harici
    /// stil dosyalarını çoğunlukla siler. Gmail dahil.
    /// </summary>
    private static string Template(
        string heading, string intro, string code, int minutes, string footnote) =>
        $"""
        <div style="font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;max-width:480px;margin:0 auto;padding:28px 24px;color:#16211f">
          <p style="margin:0 0 4px;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:#0b6e60;font-weight:700">Vivido</p>
          <h1 style="margin:0 0 12px;font-size:21px">{heading}</h1>
          <p style="margin:0 0 22px;line-height:1.55;color:#48504e">{intro}</p>
          <p style="margin:0 0 22px;padding:16px;background:#f0f6f4;border:1px solid #cfe3dd;border-radius:12px;text-align:center;font-size:32px;font-weight:800;letter-spacing:.32em;color:#0b3d35">{code}</p>
          <p style="margin:0 0 18px;font-size:14px;color:#48504e">Kod <strong>{minutes} dakika</strong> geçerlidir.</p>
          <p style="margin:0;font-size:13px;color:#7a8481;line-height:1.5">{footnote}</p>
        </div>
        """;
}
