namespace Vivido.Domain.Entities;

public class User
{

    public Guid Id { get; set; } = Guid.NewGuid();

    public required string Email { get; set; }

    public required string PasswordHash { get; set; }

    public string? DisplayName { get; set; }

    public bool IsAdmin { get; set; } = false;

     public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// E-posta doğrulama zamanı. NULL ise hesap doğrulanmamıştır ve
    /// <c>Auth:RequireEmailVerification</c> açıkken giriş
    /// 403 <c>EMAIL_NOT_VERIFIED</c> ile reddedilir (K-09).
    /// </summary>
    public DateTime? EmailVerifiedAt { get; set; }
}
