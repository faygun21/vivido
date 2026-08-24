namespace Vivido.Application.Abstractions;

/// <summary>
/// Tek bir e-posta gönderir.
///
/// Arayüz <c>Vivido.Application</c> içinde, implementasyonlar
/// <c>Vivido.Api/services</c> altında (SMTP + konsol). Böylece uygulama
/// katmanı hangi sağlayıcının kullanıldığını bilmez; sağlayıcı değişince
/// (Gmail SMTP → SendGrid → Gmail API) buraya dokunulmaz.
///
/// ⚠️ Bu arayüz BİLEREK hiçbir Microsoft.Extensions.* tipine bağlı değil —
/// Vivido.Application'ın paket bağımlılığı yok, öyle kalmalı.
/// </summary>
public interface IEmailSender
{
    Task SendAsync(EmailMessage message, CancellationToken cancellationToken = default);
}

/// <param name="To">Alıcı adresi.</param>
/// <param name="Subject">Konu satırı.</param>
/// <param name="HtmlBody">HTML gövde.</param>
/// <param name="TextBody">
/// Düz metin karşılığı. HTML'i engelleyen istemciler ve spam filtreleri
/// için gerekli; boş bırakılırsa e-posta "sadece HTML" olur ve spam puanı yükselir.
/// </param>
public record EmailMessage(string To, string Subject, string HtmlBody, string TextBody);
