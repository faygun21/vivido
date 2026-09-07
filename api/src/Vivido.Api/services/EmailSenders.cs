using System.Diagnostics;
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
/// Kurulum adımları: docs/KURULUM.md §2.5 ve .env.example → Email__*.
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

        // ⚠️ GÖNDEREN UYUMSUZLUĞU — SESSİZ TESLİMAT KAYBININ EN SIK SEBEBİ.
        //
        // Gönderen adresi, SMTP'ye giriş yapılan hesaptan FARKLIYSA posta
        // sunucuya sorunsuz teslim edilir (kod 202 döner, log "gönderildi"
        // yazar) ama alıcı tarafta SPF/DKIM hizalaması tutmaz. Gevşek
        // yapılandırılmış alan adları kabul eder, KATI olanlar — özellikle
        // üniversite ve kurum sunucuları — sessizce reddeder ya da
        // karantinaya alır.
        //
        // Belirtisi tam olarak şudur: bazı adreslere ulaşır, bazılarına
        // hiç ulaşmaz. Gönderen tarafında hiçbir hata görünmez.
        if (!string.IsNullOrWhiteSpace(_options.FromAddress) &&
            !string.Equals(
                _options.FromAddress.Trim(),
                _options.User?.Trim(),
                StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning(
                "E-posta gönderen uyumsuzluğu: Email:FromAddress ({From}) ile " +
                "Email:User ({User}) farklı. Gönderim başarılı görünse bile " +
                "katı alan adları (kurum/üniversite) postayı sessizce " +
                "reddedebilir. İkisini aynı yapmak önerilir.",
                _options.FromAddress, _options.User);
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
            var started = Stopwatch.GetTimestamp();
            await client.SendMailAsync(mail, cancellationToken);

            // GÖNDEREN de loglanıyor: "gönderildi ama ulaşmadı" durumunda
            // ilk bakılacak yer burası. Alıcı sunucusunun postayı neden
            // reddettiğini bu satır olmadan tahmin etmek zorunda kalıyorduk.
            //
            // ⚠️ Bu satır "TESLİM EDİLDİ" demek DEĞİL, "SMTP sunucusu kabul
            // etti" demek. Alıcı tarafta karantina/ret sonradan olur ve
            // buraya yansımaz; geri dönen posta gönderen kutusuna düşer.
            _logger.LogInformation(
                "E-posta SMTP'ye teslim edildi: {To} · {Subject} · " +
                "gönderen {From} · {Host}:{Port} · {ElapsedMs} ms",
                message.To,
                message.Subject,
                from,
                _options.Host,
                _options.Port,
                (int)Stopwatch.GetElapsedTime(started).TotalMilliseconds);
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
