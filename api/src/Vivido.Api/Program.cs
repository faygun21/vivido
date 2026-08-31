using System.Net.Http.Headers;
using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using Vivido.Api;
using Vivido.Api.Services;
using Vivido.Application.Abstractions;
using Vivido.Application.dtos.location;
using Vivido.Infrastructure.Data;
using Vivido.Infrastructure.Routing;
using Vivido.Infrastructure.Services;
using Vivido.Api.services;

var builder = WebApplication.CreateBuilder(args);

// ─── Loglama ───
builder.Host.UseSerilog((ctx, cfg) => cfg
    .ReadFrom.Configuration(ctx.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console());

// ─── Servisler ───

var connectionString = builder.Configuration.GetConnectionString("Default");

Console.WriteLine(
    "---> Veritabanı bağlantısı: "
    + System.Text.RegularExpressions.Regex.Replace(
        connectionString ?? "(tanımsız)",
        @"(?i)(password\s*=\s*)[^;]*",
        "$1***"));

builder.Services.AddDbContext<VividoDbContext>(options =>
    options.UseNpgsql(connectionString, o => o.UseNetTopologySuite())
           .UseSnakeCaseNamingConvention()
);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddMemoryCache();

// Beklenmeyen (kodun öngörmediği) hatalar için ProblemDetails üretimini
// etkinleştirir — aşağıdaki UseExceptionHandler ile birlikte çalışır.
builder.Services.AddProblemDetails();

// Statik/nadiren değişen anonim uçlar (POI kategorileri vb.) için —
// bkz. PoisController.GetCategories.
builder.Services.AddResponseCaching();

// Scoring
builder.Services.AddScoped<PropertyScoringService>();
builder.Services.AddScoped<PropertyScoreBreakdownService>();
builder.Services.AddScoped<PropertyAddressService>();

// Geocoding
builder.Services.AddScoped<ILocationSearchService, LocationSearchService>();

builder.Services.AddHttpClient<PhotonGeocodingProvider>(client =>
{
    var baseUrl = builder.Configuration["Geocoding:Photon:BaseUrl"]
        ?? "https://photon.komoot.io/";

    var userAgent = builder.Configuration["Geocoding:UserAgent"]
        ?? "Vivido/1.0 (+https://github.com/faygun21/vivido)";

    client.BaseAddress = new Uri(baseUrl);
    client.DefaultRequestHeaders.UserAgent.ParseAdd(userAgent);
    client.DefaultRequestHeaders.AcceptLanguage.Add(
        new StringWithQualityHeaderValue("tr")
    );
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
    client.DefaultRequestHeaders.AcceptLanguage.Add(
        new StringWithQualityHeaderValue("tr")
    );
    client.Timeout = TimeSpan.FromSeconds(8);
});

builder.Services.AddScoped<IGeocodingProvider>(services =>
    services.GetRequiredService<PhotonGeocodingProvider>());

builder.Services.AddScoped<IGeocodingProvider>(services =>
    services.GetRequiredService<NominatimGeocodingProvider>());

// Routing
builder.Services.AddOsrmRouting(builder.Configuration);

// ─── SWAGGER AYARLARI ───
builder.Services.AddSwaggerGen(o =>
{
    o.SwaggerDoc("v1", new()
    {
        Title = "Vivido API",
        Version = "v1",
        Description = "Kiralık ev bulma, kişiselleştirilmiş skorlama ve ziyaret rotası"
    });

    // Aynı isimli DTO'ların Swagger'da çakışmasını önler
    o.CustomSchemaIds(type =>
        type.FullName?.Replace("+", ".") ?? type.Name);
});

// JWT servisi
builder.Services.AddScoped<JwtService>();

// İlk gerçek admin hesabını belirleyen servis
builder.Services.AddScoped<BootstrapAdminService>();

// ─── E-posta doğrulama ve şifre sıfırlama ───
builder.Services.Configure<AuthOptions>(
    builder.Configuration.GetSection(AuthOptions.SectionName)
);

builder.Services.Configure<EmailOptions>(
    builder.Configuration.GetSection(EmailOptions.SectionName)
);

var emailOptions =
    builder.Configuration
        .GetSection(EmailOptions.SectionName)
        .Get<EmailOptions>()
    ?? new EmailOptions();

if (emailOptions.IsSmtp)
{
    builder.Services.AddScoped<IEmailSender, SmtpEmailSender>();
}
else
{
    builder.Services.AddScoped<IEmailSender, ConsoleEmailSender>();
}

Console.WriteLine(
    $"---> E-posta sağlayıcısı: " +
    $"{(emailOptions.IsSmtp
        ? $"smtp ({emailOptions.Host})"
        : "console (e-posta GÖNDERİLMEZ, kod loglara basılır)")}"
);

builder.Services.AddScoped<AuthCodeService>();

// ─── JWT yapılandırması ───
//
// ⭐ ValidateOnStart(): Jwt:Key eksik/kısa ya da Issuer/Audience boşsa
// uygulama AÇILIRKEN çöker — eskiden bu değerler kullanım anında (ilk
// login isteğinde) okunuyordu, yanlış yapılandırma canlıdaki ilk
// kullanıcıyı etkiliyordu. Artık deploy başarısız olur, kullanıcı hiç
// etkilenmez.
builder.Services
    .AddOptions<JwtOptions>()
    .Bind(builder.Configuration.GetSection(JwtOptions.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();

var jwtOptions = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>() ?? new JwtOptions();

// ─── JWT DOĞRULAMA ───
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,

            ValidIssuer = jwtOptions.Issuer,
            ValidAudience = jwtOptions.Audience,

            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwtOptions.Key)
            )
        };
    });

// ─── YETKİLENDİRME ───
// [Authorize]              → giriş yapmış kullanıcı
// AdminOnly policy         → Role = Admin olan kullanıcı
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy(
        "AdminOnly",
        policy => policy.RequireRole("Admin")
    );
});

// Sağlık kontrolleri
builder.Services.AddHealthChecks()
    .AddNpgSql(connectionString!, name: "database");

// ─── RATE LIMITING ───
//
// Öncesinde HİÇBİR uçta istek sınırı yoktu: /auth/login şifre denemesini
// hiç kısıtlamıyordu (kaba kuvvet), [AllowAnonymous] harita/POI uçları da
// (kimlik doğrulama istemedikleri için) sınırsız DB/PostGIS yüküne açıktı.
// IP başına iki ayrı politika:
//   "auth"       → /auth/* (kayıt, giriş, kod doğrulama) — dar pencere
//   "public-map" → [AllowAnonymous] harita/POI uçları — daha geniş pencere
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    static string ClientKey(HttpContext ctx) =>
        ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";

    options.AddPolicy("auth", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ClientKey(ctx),
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 10,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0,
        }));

    options.AddPolicy("public-map", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ClientKey(ctx),
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 120,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0,
        }));
});

// ─── CORS ───
const string DevCors = "dev";
const string ProdCors = "prod";

var allowedOrigins =
    (builder.Configuration["Cors:AllowedOrigins"] ?? string.Empty)
    .Split(
        ',',
        StringSplitOptions.RemoveEmptyEntries |
        StringSplitOptions.TrimEntries
    );

builder.Services.AddCors(o =>
{
    o.AddPolicy(
        DevCors,
        p => p
            .AllowAnyOrigin()
            .AllowAnyMethod()
            .AllowAnyHeader()
    );

    o.AddPolicy(
        ProdCors,
        p => p
            .WithOrigins(allowedOrigins)
            .AllowAnyMethod()
            .AllowAnyHeader()
    );
});

var app = builder.Build();

// ─── Merkezi hata yönetimi ───
//
// Controller'lardaki try/catch + ApiProblem.* çağrıları yalnızca ÖNGÖRÜLEN
// hataları (validasyon, "bulunamadı" vb.) kapsıyordu — öngörülmeyen HER hata
// (bir null-ref, EF Core istisnası, hiç düşünülmemiş bir kenar durumu) çıplak,
// açıklamasız bir 500 olarak dönüyordu. Bu son bir ağ: hiçbir controller
// yakalamadıysa buraya düşer, detay sızdırmadan INTERNAL_ERROR döner ve tam
// istisna loglanır.
//
// ⚠️ Burada istisna TİPİNE göre özel ApiProblem'lere dallanmıyoruz —
// örn. InvalidOperationException onlarca farklı (rotayla ilgisiz) yerden de
// gelebilir; öyle bir eşleme yanlış senaryoda yanlış hata koduna yol açardı.
// Rotaya özgü ROUTE_UNREACHABLE, kaynağında (RoutesController) hedefli bir
// try/catch ile üretiliyor — bkz. oradaki not.
app.UseExceptionHandler(errorApp => errorApp.Run(async context =>
{
    var exception = context.Features.Get<IExceptionHandlerFeature>()?.Error;

    context.RequestServices
        .GetRequiredService<ILogger<Program>>()
        .LogError(exception, "Beklenmeyen hata: {Path}", context.Request.Path);

    var problem = ApiProblem.InternalError();

    context.Response.ContentType = "application/problem+json";
    context.Response.StatusCode = problem.StatusCode!.Value;
    await context.Response.WriteAsJsonAsync(problem.Value);
}));

// ─── Boru hattı ───
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();

    app.UseSwaggerUI(o =>
        o.SwaggerEndpoint(
            "/swagger/v1/swagger.json",
            "Vivido API v1"
        )
    );

    app.UseCors(DevCors);
}
else if (allowedOrigins.Length > 0)
{
    app.UseCors(ProdCors);

    app.Logger.LogInformation(
        "CORS etkin, izinli origin'ler: {Origins}",
        string.Join(", ", allowedOrigins)
    );
}

// Authentication önce, Authorization sonra
app.UseAuthentication();
app.UseAuthorization();

app.UseRateLimiter();
app.UseResponseCaching();

app.UseSerilogRequestLogging();

app.MapHealthChecks("/health/live");
app.MapHealthChecks("/health/ready");

app.MapControllers();

app.Run();

public partial class Program;