using System.Net;
using System.Net.Mail;
using System.Text;
using Microsoft.Extensions.Options;
using Vivido.Application.Abstractions;

namespace Vivido.Api.Services;

/// <summary>
/// Geliştirme gönderici: e-posta göndermez, gövdeyi API konsoluna basar.
///
/// Neden var: ekipteki yedi kişinin hepsinin SMTP kimlik bilgisi olması
/// gerekmesin. `pnpm dev:api` çalıştıran herkes kayıt olabilir, kodu
/// konsoldan okur, akışın tamamını dener.
///
/// ⚠️ Production'da seçilirse uyarı basar — kod loglara düşüyor demektir.
/// </summary>
public class ConsoleEmailSender : IEmailSender
{
    private readonly ILogger<ConsoleEmailSender> _logger;

    public ConsoleEmailSender(ILogger<ConsoleEmailSender> logger, IHostEnvironment environment)
    {
        _logger = logger;

        if (!environment.IsDevelopment())
        {
            _logger.LogWarning(
                "Email:Provider=console ve ortam {Environment}. Doğrulama kodları " +
                "e-posta yerine loglara yazılıyor — bu bir güvenlik açığıdır.",
                environment.EnvironmentName);
        }
    }

    public Task SendAsync(EmailMessage message, CancellationToken cancellationToken = default)
    {
        // Serilog konsol formatı uzun metni sıkıştırıyor; çerçeve içinde
        // basmak kodu göz taramasıyla bulunabilir kılıyor.
        _logger.LogInformation(
            "\n┌─ E-POSTA (gönderilmedi, Email:Provider=console) ─────────────\n" +
            "│ Kime : {To}\n" +
            "│ Konu : {Subject}\n" +
            "├───────────────────────────────────────────────────────────────\n" +
            "{Body}\n" +
            "└───────────────────────────────────────────────────────────────",
            message.To, message.Subject, message.TextBody);

        return Task.CompletedTask;
    }
}

/// <summary>
/// SMTP gönderici — Gmail "Uygulama Şifresi" ile çalışır.
///
/// Kurulum adımları: README §2.5 ve .env.example → Email__*.
///
/// Neden System.Net.Mail.SmtpClient: .NET tarafından "obsolete değil ama
/// yeni kod için önerilmez" diye işaretli, çünkü modern SMTP uzantılarının
/// tamamını desteklemiyor. Bizim ihtiyacımız (STARTTLS + AUTH LOGIN, Gmail'e
/// düz metin/HTML e-posta) tam olarak desteklediği yüzey. MailKit eklemek
/// projeye yeni bir NuGet bağımlılığı getirirdi; getirisi yok.
/// </summary>
public class SmtpEmailSender : IEmailSender
{
    private readonly EmailOptions _options;
    private readonly ILogger<SmtpEmailSender> _logger;

    public SmtpEmailSender(IOptions<EmailOptions> options, ILogger<SmtpEmailSender> logger)
    {
        _options = options.Value;
        _logger = logger;

        if (string.IsNullOrWhiteSpace(_options.User) || string.IsNullOrWhiteSpace(_options.Password))
        {
            // Fırlatmıyoruz: API'nin açılışta ölmesi, e-posta dışındaki her
            // şeyi de durdurur. Gönderim anında zaten hata alınacak.
            _logger.LogError(
                "Email:Provider=smtp ama Email:User / Email:Password boş. " +
                "Doğrulama e-postaları gönderilemeyecek.");
        }
    }

    public async Task SendAsync(EmailMessage message, CancellationToken cancellationToken = default)
    {
        var from = string.IsNullOrWhiteSpace(_options.FromAddress)
            ? _options.User
            : _options.FromAddress;

        using var mail = new MailMessage
        {
            From = new MailAddress(from, _options.FromName, Encoding.UTF8),
            Subject = message.Subject,
            Body = message.TextBody,
            IsBodyHtml = false,

            // ⚠️ Açıkça UTF-8 vermek ZORUNLU. Varsayılan bırakılırsa
            // SmtpClient konu ve gövdeyi sistem ANSI kod sayfasıyla
            // kodlamaya kalkışabiliyor ve "doğrulama" karşı tarafta
            // "doÄŸrulama" olarak görünüyor. Türkçe içerikte sessiz bir
            // bozulma — geliştirici konsolunda hiç görünmez, yalnızca
            // gerçek gönderimde ortaya çıkar.
            SubjectEncoding = Encoding.UTF8,
            BodyEncoding = Encoding.UTF8,
            HeadersEncoding = Encoding.UTF8,
        };
        mail.To.Add(message.To);

        // Düz metin gövde + HTML alternatif view: HTML'i engelleyen
        // istemcilerde de kod okunabilir kalır, spam puanı düşer.
        mail.AlternateViews.Add(AlternateView.CreateAlternateViewFromString(
            message.HtmlBody, Encoding.UTF8, "text/html"));

        using var client = new SmtpClient(_options.Host, _options.Port)
        {
            EnableSsl = _options.UseStartTls,
            Credentials = new NetworkCredential(_options.User, _options.Password),
            DeliveryMethod = SmtpDeliveryMethod.Network,
        };

        try
        {
            await client.SendMailAsync(mail, cancellationToken);
            _logger.LogInformation("E-posta gönderildi: {To} · {Subject}", message.To, message.Subject);
        }
        catch (SmtpException ex)
        {
            // Parolayı loglamamak için istisnayı olduğu gibi basmıyoruz;
            // SmtpException.Message kimlik bilgisi içermez.
            _logger.LogError(ex,
                "SMTP gönderimi başarısız ({StatusCode}). Gmail kullanıyorsan: " +
                "2FA açık mı ve Email__Password 16 haneli UYGULAMA ŞİFRESİ mi?",
                ex.StatusCode);
            throw;
        }
    }
}
