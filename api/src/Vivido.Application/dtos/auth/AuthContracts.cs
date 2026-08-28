namespace Vivido.Application.DTOs.Auth;

//Request
public record RegisterRequest(string Email, string Password, string? DisplayName);

public record LoginRequest(string Email, string Password);

public record RefreshRequest(string RefreshToken);

/// <summary>Kayıt sonrası e-postaya gelen 6 haneli kod (K-09).</summary>
public record VerifyEmailRequest(string Email, string Code);

/// <summary>Kod gelmediyse / süresi dolduysa yenisini ister.</summary>
public record ResendVerificationRequest(string Email);

/// <summary>"Şifremi unuttum" — e-postaya sıfırlama kodu gönderir.</summary>
public record ForgotPasswordRequest(string Email);

/// <summary>Kod + yeni şifre ile sıfırlamayı tamamlar.</summary>
public record ResetPasswordRequest(string Email, string Code, string NewPassword);

//Response
public record TokenPair(string AccessToken, string RefreshToken, int ExpiresIn);

//kullanıcı id'si string (uuid) formatında dönmeli, C# Guid tipini otomatik çevirir
public record AuthUser(
    Guid Id,
    string Email,
    string? DisplayName,
    bool EmailVerified,
    bool IsAdmin
);

//register ve login işlemleri aynı gövdeyi dönmelidir
public record AuthResponse(AuthUser User, TokenPair Tokens);

/// <summary>
/// Doğrulama bekleyen kayıt yanıtı — HTTP 202.
///
/// <see cref="AuthResponse"/> ile aynı uç noktadan dönebildiği için
/// istemci ikisini HTTP durum koduyla ayırır: 201 → token geldi,
/// 202 → önce kod girilecek. Gövdede ayrıca <see cref="Status"/> var ki
/// Swagger'a bakan biri de farkı görsün.
/// </summary>
public record PendingVerificationResponse(
    string Status,
    string Email,
    int ExpiresInMinutes,
    string Message)
{
    public const string VerificationRequired = "verification_required";

    public static PendingVerificationResponse For(string email, int minutes) => new(
        VerificationRequired,
        email,
        minutes,
        $"{email} adresine 6 haneli bir doğrulama kodu gönderdik. Kod {minutes} dakika geçerli.");
}

/// <summary>Gövdesi olmayan başarı yanıtları için ortak zarf.</summary>
public record MessageResponse(string Status, string Message);
