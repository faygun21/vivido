namespace Vivido.Domain.Entities;

/// <summary>
/// Tek kullanımlık 6 haneli doğrulama kodu.
///
/// E-posta doğrulama ve şifre sıfırlama aynı tabloyu paylaşır
/// (<see cref="Purpose"/> ayırır) — bkz. db/schema/004, K-09.
///
/// ⚠️ Ham kod ASLA saklanmaz; <see cref="CodeHash"/> içinde
/// SHA-256(kod + ':' + userId) tutulur.
/// </summary>
public class AuthCode
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid UserId { get; set; }

    /// <summary>'email_verify' | 'password_reset' — <see cref="AuthCodePurpose"/>.</summary>
    public required string Purpose { get; set; }

    public required string CodeHash { get; set; }

    public DateTime ExpiresAt { get; set; }

    /// <summary>Dolu ise kod kullanılmış; ikinci kez kabul edilmez.</summary>
    public DateTime? ConsumedAt { get; set; }

    /// <summary>Yanlış deneme sayısı. Kaba kuvvete karşı üst sınır var.</summary>
    public short Attempts { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User? User { get; set; }
}

/// <summary>
/// <see cref="AuthCode.Purpose"/> değerleri.
///
/// Sabit string yerine burada toplanıyor: veritabanındaki CHECK kısıtı
/// bu iki değeri tanıyor, üçüncüsü yazılırsa INSERT patlar. Yazım hatası
/// derleme zamanında yakalansın diye.
/// </summary>
public static class AuthCodePurpose
{
    public const string EmailVerify = "email_verify";
    public const string PasswordReset = "password_reset";
}
