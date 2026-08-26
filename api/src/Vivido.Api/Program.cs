using System.Net.Http.Headers;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using Vivido.Api.Services;
using Vivido.Application.Abstractions;
using Vivido.Application.dtos.location;
using Vivido.Infrastructure.Data;
using Vivido.Infrastructure.Services;
using Vivido.Api.services;


var builder = WebApplication.CreateBuilder(args);

// ─── Loglama ───
builder.Host.UseSerilog((ctx, cfg) => cfg
    .ReadFrom.Configuration(ctx.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console());

// ─── Servisler ───

// 1. ÖNCE DEĞİŞKENİ TANIMLIYORUZ
var connectionString = builder.Configuration.GetConnectionString("Default");
// Bağlantı sorunlarını teşhis etmeye yarıyor, ama parolayı OLDUĞU GİBİ
// yazdırmak kimlik bilgisini stdout'a ve CI loglarına düşürür. Parolayı
// maskeleyip geri kalanı bırakıyoruz — teşhis değeri aynı, sızıntı yok.
Console.WriteLine(
    "---> Veritabanı bağlantısı: "
    + System.Text.RegularExpressions.Regex.Replace(
        connectionString ?? "(tanımsız)",
        @"(?i)(password\s*=\s*)[^;]*",
        "$1***"));

// 2. SONRA VERİTABANI BAĞLANTISINI KURUYORUZ
builder.Services.AddDbContext<VividoDbContext>(options =>
    options.UseNpgsql(connectionString, o => o.UseNetTopologySuite())
           .UseSnakeCaseNamingConvention()
);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddMemoryCache();
// Scoring servisini Scoped olarak kaydediyoruz (Her HTTP isteğinde bir kez üretilir)
builder.Services.AddScoped<PropertyScoringService>();
// W6 gerekçe tablosu: skorun SATIR SATIR açıklaması. Formülü yeniden
// hesaplamaz, ScoringEngine.CalculateBreakdown'ı etiketler.
builder.Services.AddScoped<PropertyScoreBreakdownService>();
// Konut adresi: en yakın adlı sokak (streets, KNN) + mahalle.
// Ters geokodlama YOK — gerekçe db/schema/009_add_streets.sql başlığında.
builder.Services.AddScoped<PropertyAddressService>();
// R-105: yerel mahallelerden sonra Photon, sonuç/hizmet yoksa Nominatim denenir.
// Her sağlayıcının adresi yapılandırmadan değiştirilebilir veya kurum içine alınabilir.
builder.Services.AddScoped<ILocationSearchService, LocationSearchService>();
builder.Services.AddHttpClient<PhotonGeocodingProvider>(client =>
{
    var baseUrl = builder.Configuration["Geocoding:Photon:BaseUrl"]
        ?? "https://photon.komoot.io/";
    var userAgent = builder.Configuration["Geocoding:UserAgent"]
        ?? "Vivido/1.0 (+https://github.com/faygun21/vivido)";

    client.BaseAddress = new Uri(baseUrl);
    client.DefaultRequestHeaders.UserAgent.ParseAdd(userAgent);
    client.DefaultRequestHeaders.AcceptLanguage.Add(new StringWithQualityHeaderValue("tr"));
    client.Timeout = TimeSpan.FromSeconds(8);
});
builder.Services.AddHttpClient<NominatimGeocodingProvider>(client =>
{
    var baseUrl = builder.Configuration["Geocoding:Nominatim:BaseUrl"]
        ?? "https://nominatim.openstreetmap.org/";
    var userAgent = builder.Configuration["Geocoding:UserAgent"]
        ?? "Vivido/1.0 (+https://github.com/faygun21/vivido)";

    client.BaseAddress = new Uri(baseUrl);
    client.DefaultRequestHeaders.UserAgent.ParseAdd(userAgent);
    client.DefaultRequestHeaders.AcceptLanguage.Add(new StringWithQualityHeaderValue("tr"));
    client.Timeout = TimeSpan.FromSeconds(8);
});
builder.Services.AddScoped<IGeocodingProvider>(services =>
    services.GetRequiredService<PhotonGeocodingProvider>());
builder.Services.AddScoped<IGeocodingProvider>(services =>
    services.GetRequiredService<NominatimGeocodingProvider>());
// ─── SWAGGER AYARLARI ───
builder.Services.AddSwaggerGen(o =>
{
    o.SwaggerDoc("v1", new()
    {
        Title = "Vivido API",
        Version = "v1",
        Description = "Kiralık ev bulma, kişiselleştirilmiş skorlama ve ziyaret rotası"
    });
});
// JwtService'i sisteme kaydetme
builder.Services.AddScoped<JwtService>();

// ─── E-posta doğrulama ve şifre sıfırlama (K-09) ───
builder.Services.Configure<AuthOptions>(builder.Configuration.GetSection(AuthOptions.SectionName));
builder.Services.Configure<EmailOptions>(builder.Configuration.GetSection(EmailOptions.SectionName));

// Sağlayıcı seçimi açılışta bir kez yapılır. `console` (varsayılan) hiçbir
// kimlik bilgisi istemez ve kodu API konsoluna basar — ekipteki herkesin
// SMTP hesabı olmadan akışı denemesi için.
var emailOptions = builder.Configuration.GetSection(EmailOptions.SectionName).Get<EmailOptions>()
                   ?? new EmailOptions();
if (emailOptions.IsSmtp)
{
    builder.Services.AddScoped<IEmailSender, SmtpEmailSender>();
}
else
{
    builder.Services.AddScoped<IEmailSender, ConsoleEmailSender>();
}
Console.WriteLine($"---> E-posta sağlayıcısı: {(emailOptions.IsSmtp ? $"smtp ({emailOptions.Host})" : "console (e-posta GÖNDERİLMEZ, kod loglara basılır)")}");

builder.Services.AddScoped<AuthCodeService>();

// JWT Doğrulama ayarlarını ekleme
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"]!))
        };
    });

builder.Services.AddAuthorization();

// Sağlık kontrolleri. (Artık connectionString'i tanıyor)
builder.Services.AddHealthChecks()
    .AddNpgSql(connectionString!, name: "database");

// ─── CORS ───
//
// İki ayrı politika, çünkü ihtiyaçlar taban tabana zıt:
//
//   dev  → her origin serbest. Geliştirici :5173, :4173, telefon IP'si,
//          Swagger… hepsinden deniyor; kısıtlamak sadece engel olur.
//   prod → yalnızca AÇIKÇA izin verilen origin'ler. Liste boşsa CORS
//          hiç açılmaz ve DOĞRU varsayılan budur: staging'de web ile API
//          aynı origin'den (Caddy, tek domain) servis ediliyor, tarayıcı
//          CORS'a hiç takılmıyor.
//
// ⚠️ Native mobil uygulama CORS'a TABİ DEĞİLDİR — CORS bir tarayıcı
// mekanizması. Flutter istemcisi için buraya bir şey eklemek gerekmez.
const string DevCors = "dev";
const string ProdCors = "prod";

var allowedOrigins = (builder.Configuration["Cors:AllowedOrigins"] ?? string.Empty)
    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

builder.Services.AddCors(o =>
{
    o.AddPolicy(DevCors, p => p
        .AllowAnyOrigin()
        .AllowAnyMethod()
        .AllowAnyHeader());

    o.AddPolicy(ProdCors, p => p
        .WithOrigins(allowedOrigins)
        .AllowAnyMethod()
        .AllowAnyHeader());
});

var app = builder.Build();

// ─── Boru hattı ───
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(o => o.SwaggerEndpoint("/swagger/v1/swagger.json", "Vivido API v1"));
    app.UseCors(DevCors);
}
else if (allowedOrigins.Length > 0)
{
    // ⚠️ Bu dal ÖNCEDEN YOKTU: CORS tamamen `IsDevelopment()` içindeydi.
    // Web başka bir origin'den sunulsaydı production'da API'ye hiç
    // erişemezdi ve hata tarayıcı konsolunda kalırdı — sunucu logunda
    // görünmeyen türden bir arıza.
    app.UseCors(ProdCors);
    app.Logger.LogInformation(
        "CORS etkin, izinli origin'ler: {Origins}", string.Join(", ", allowedOrigins));
}

// Kimlik kontrolü her ortamda çalışmalı, if bloğundan çıkarıldı
app.UseAuthentication();
app.UseAuthorization();

app.UseSerilogRequestLogging();

app.MapHealthChecks("/health/live");
app.MapHealthChecks("/health/ready");

app.MapControllers();

app.Run();

public partial class Program;
