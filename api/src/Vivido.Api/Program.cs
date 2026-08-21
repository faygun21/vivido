using System.Net.Http.Headers;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Serilog;
using Vivido.Api.Services;
using Vivido.Application.dtos.location;
using Vivido.Infrastructure.Data;
using Vivido.Infrastructure.Services;


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

// R-105 adres/yer adı araması. BaseUrl yapılandırılabilir; böylece üretimde
// kamu Nominatim servisi yerine kurum içi veya farklı bir sağlayıcıya kod
// değişikliği olmadan geçilebilir.
builder.Services.AddHttpClient<ILocationSearchService, LocationSearchService>(client =>
{
    var baseUrl = builder.Configuration["Geocoding:BaseUrl"]
        ?? "https://nominatim.openstreetmap.org/";
    var userAgent = builder.Configuration["Geocoding:UserAgent"]
        ?? "Vivido/1.0 (+https://github.com/faygun21/vivido)";

    client.BaseAddress = new Uri(baseUrl);
    client.DefaultRequestHeaders.UserAgent.ParseAdd(userAgent);
    client.DefaultRequestHeaders.AcceptLanguage.Add(new StringWithQualityHeaderValue("tr"));
    client.Timeout = TimeSpan.FromSeconds(8);
});
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

// Web ve mobil istemciler için CORS.
const string DevCors = "dev";
builder.Services.AddCors(o => o.AddPolicy(DevCors, p => p
    .AllowAnyOrigin()
    .AllowAnyMethod()
    .AllowAnyHeader()));

var app = builder.Build();

// ─── Boru hattı ───
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(o => o.SwaggerEndpoint("/swagger/v1/swagger.json", "Vivido API v1"));
    app.UseCors(DevCors);
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
