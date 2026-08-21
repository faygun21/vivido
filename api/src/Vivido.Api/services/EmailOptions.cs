namespace Vivido.Api.Services;

/// <summary>
/// E-posta gönderim ayarları — <c>Email:*</c> bölümünden okunur.
///
/// Ortam değişkeni karşılıkları (.env):
///   Email__Provider, Email__Host, Email__Port, Email__User,
///   Email__Password, Email__FromAddress, Email__FromName
/// </summary>
public class EmailOptions
{
    public const string SectionName = "Email";

    /// <summary>
    /// <c>console</c> → e-posta gönderilmez, kod API konsoluna basılır.
    ///   Kimlik bilgisi olmadan geliştirme yapabilmek için varsayılan bu.
    /// <c>smtp</c> → gerçek gönderim (Gmail uygulama şifresi vb.).
    /// </summary>
    public string Provider { get; set; } = "console";

    public string Host { get; set; } = "smtp.gmail.com";

    /// <summary>587 = STARTTLS. Gmail 465'i (implicit SSL) SmtpClient ile desteklemez.</summary>
    public int Port { get; set; } = 587;

    /// <summary>Gmail adresinin tamamı: ornek@gmail.com</summary>
    public string User { get; set; } = "";

    /// <summary>
    /// Gmail hesabının normal şifresi DEĞİL — 16 haneli "Uygulama Şifresi".
    /// Google 2024'ten beri normal şifreyle SMTP girişini reddediyor.
    /// </summary>
    public string Password { get; set; } = "";

    public string FromAddress { get; set; } = "";

    public string FromName { get; set; } = "Vivido";

    /// <summary>Gmail 587'de STARTTLS zorunlu; kapatmak için sebep yok.</summary>
    public bool UseStartTls { get; set; } = true;

    public bool IsSmtp => string.Equals(Provider, "smtp", StringComparison.OrdinalIgnoreCase);
}

/// <summary>
/// Kimlik doğrulama davranış anahtarları — <c>Auth:*</c>.
/// </summary>
public class AuthOptions
{
    public const string SectionName = "Auth";

    /// <summary>
    /// Açıkken kayıt token DÖNMEZ; kullanıcı e-postasındaki kodu girene
    /// kadar giriş yapamaz (K-09). Kapatmak eski davranışa (201 + token)
    /// döner — kabul kriteri W1'in ilk hâli.
    /// </summary>
    public bool RequireEmailVerification { get; set; } = true;

    /// <summary>Doğrulama kodunun geçerlilik süresi (dakika).</summary>
    public int VerificationCodeMinutes { get; set; } = 15;

    /// <summary>Şifre sıfırlama kodunun geçerlilik süresi (dakika).</summary>
    public int PasswordResetCodeMinutes { get; set; } = 15;

    /// <summary>Aynı kod için izin verilen yanlış deneme sayısı.</summary>
    public int MaxCodeAttempts { get; set; } = 5;

    /// <summary>İki kod isteği arasındaki en kısa süre (saniye).</summary>
    public int ResendCooldownSeconds { get; set; } = 60;
}
