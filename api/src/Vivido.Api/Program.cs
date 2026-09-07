using System.Net.Http.Headers;
using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.HttpOverrides;
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
    // Zaman aşımı YOK bırakılırsa (SonarQube uyarısı) bu regex teorik
    // olarak felaketsel geri izleme (catastrophic backtracking) ile
    // sonsuza kadar takılabilir — burada girdi bizim kendi yapılandırma
    // dizgimiz olduğu için pratikte risksiz, ama savunma amaçlı bir üst
    // sınır ucuz bir güvence.
    + System.Text.RegularExpressions.Regex.Replace(
        connectionString ?? "(tanımsız)",
        @"(?i)(password\s*=\s*)[^;]*",
        "$1***",
        System.Text.RegularExpressions.RegexOptions.None,
        TimeSpan.FromMilliseconds(500)));

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

    // `RejectionStatusCode` yalnızca durum kodunu ayarlar, GÖVDE üretmez —
    // varsayılanla 429 yanıtı boş dönerdi, `ApiProblem` sözleşmesini
    // (her hatada makine-okunur `code` alanı) burada kırardı. İstemci
    // diğer her hatada olduğu gibi `problem.code === 'TOO_MANY_REQUESTS'`
    // ile dallanabilsin diye açıkça yazıyoruz.
    options.OnRejected = async (context, cancellationToken) =>
    {
        var problem = ApiProblem.Build(
            StatusCodes.Status429TooManyRequests,
            "Çok fazla istek",
            "TOO_MANY_REQUESTS",
            "Kısa bir süre bekleyip tekrar deneyin.");

        context.HttpContext.Response.ContentType = "application/problem+json";
        await context.HttpContext.Response.WriteAsJsonAsync(problem.Value, cancellationToken);
    };

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

    // "geocoding" → /locations/search. Bu uç DIŞARIYA istek doğuruyor
    // (Photon, sonra Nominatim). Sınırsız bırakıldığında giriş yapmış tek
    // bir kullanıcı, her tuş vuruşunda tetiklenen aramayla Nominatim'in
    // kullanım politikasını (saniyede en fazla 1 istek) aşabilir ve
    // Vivido'nun sunucu IP'si kalıcı olarak engellenir — o andan sonra
    // konum araması HERKES için çalışmaz. Kendi veritabanımızı değil, ÜÇÜNCÜ
    // TARAFI koruyan bir sınır; bu yüzden "public-map"ten belirgin şekilde dar.
    options.AddPolicy("geocoding", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ClientKey(ctx),
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = 30,
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

// ─── FORWARDED HEADERS ───
//
// Üretimde bir reverse proxy/load balancer (Nginx, ALB, Cloudflare vb.)
// arkasında çalışılıyorsa `ctx.Connection.RemoteIpAddress` (yukarıdaki rate
// limiter'ın IP başına partition anahtarı) HER istekte proxy'nin KENDİ
// IP'sini görür — "auth" limiti (10/dk) o zaman proxy arkasındaki TÜM
// kullanıcılar arasında paylaşılan tek bir sayaca döner, bir kullanıcının
// yanlış şifre denemesi başkasını da kilitleyebilir.
//
// `ForwardedHeaders:KnownProxies` / `:KnownNetworks` yapılandırılmadıysa
// (varsayılan, örn. yerel geliştirme) bu middleware'in hiçbir etkisi yoktur —
// ASP.NET Core `X-Forwarded-For` başlığını yalnızca BİLİNEN/güvenilen bir
// proxy'den geldiğinde kabul eder, aksi halde sahte bir başlıkla IP taklit
// edilebilmesin diye tamamen YOK sayar.
//
// ⭐ NEDEN AĞ (CIDR) DESTEĞİ DE VAR: staging/production'da tek ingress Caddy
// ve API'ye YALNIZCA docker köprü ağından erişilebiliyor (bkz.
// deploy/docker-compose.prod.yml — api servisinde `ports:` yok). Caddy'nin
// konteyner IP'si ise SABİT DEĞİL: compose her `up`ta farklı bir adres
// verebiliyor, dolayısıyla tek tek IP yazmak (`KnownProxies`) ilk yeniden
// başlatmada sessizce geçersizleşirdi. Ağın tamamını güvenmek burada
// güvenli, çünkü o ağa yalnızca bizim konteynerlerimiz bağlı.
//
// ⚠️ Bu ayar YAPILANDIRILMAZSA rate limiter'ın IP başına bölümlemesi
// (`ClientKey`) HER istekte Caddy'nin IP'sini görür ve "auth" limiti (10/dk)
// tüm kullanıcıların PAYLAŞTIĞI tek bir sayaca döner: bir kişinin yanlış
// şifre denemeleri herkesin girişini kilitler ve kaba kuvvet koruması
// saldırgan başına değil, sistem geneli olur.
var forwardedHeadersOptions = new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
};

// `KnownProxies`/`KnownIPNetworks` BOŞ DEĞİL başlar (varsayılan: loopback),
// bu yüzden "yapılandırıldı mı" sorusunu listelerin uzunluğuyla değil kendi
// sayacımızla cevaplıyoruz — aksi halde aşağıdaki uyarı hiç basılmazdı.
var trustedHopCount = 0;

foreach (var proxy in (builder.Configuration["ForwardedHeaders:KnownProxies"] ?? string.Empty)
             .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
{
    if (System.Net.IPAddress.TryParse(proxy, out var ip))
    {
        forwardedHeadersOptions.KnownProxies.Add(ip);
        trustedHopCount++;
    }
    else
    {
        Console.WriteLine(
            $"---> UYARI: ForwardedHeaders:KnownProxies içindeki '{proxy}' " +
            "geçerli bir IP değil, yok sayıldı.");
    }
}

foreach (var network in (builder.Configuration["ForwardedHeaders:KnownNetworks"] ?? string.Empty)
             .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
{
    // "172.16.0.0/12" biçiminde CIDR bekleniyor.
    if (System.Net.IPNetwork.TryParse(network, out var parsed))
    {
        forwardedHeadersOptions.KnownIPNetworks.Add(parsed);
        trustedHopCount++;
    }
    else
    {
        Console.WriteLine(
            $"---> UYARI: ForwardedHeaders:KnownNetworks içindeki '{network}' " +
            "geçerli bir CIDR değil, yok sayıldı.");
    }
}

if (trustedHopCount > 0)
{
    app.Logger.LogInformation(
        "ForwardedHeaders etkin: {Count} güvenilen proxy/ağ tanımlı.",
        trustedHopCount);
}
else if (!app.Environment.IsDevelopment())
{
    app.Logger.LogWarning(
        "ForwardedHeaders:KnownProxies/KnownNetworks TANIMSIZ. Ters vekil " +
        "arkasındaysanız istek sınırları (rate limit) IP başına DEĞİL, tüm " +
        "kullanıcılar için TEK sayaç olarak çalışır.");
}

app.UseForwardedHeaders(forwardedHeadersOptions);

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