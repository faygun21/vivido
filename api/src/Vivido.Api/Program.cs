using Serilog;
using Microsoft.EntityFrameworkCore;
using Vivido.Infrastructure.Data;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using Vivido.Api.Services;


var builder = WebApplication.CreateBuilder(args);

// ─── Loglama ───
builder.Host.UseSerilog((ctx, cfg) => cfg
    .ReadFrom.Configuration(ctx.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console());

// ─── Servisler ───

// 1. ÖNCE DEĞİŞKENİ TANIMLIYORUZ
var connectionString = builder.Configuration.GetConnectionString("Default");
Console.WriteLine("---> KULLANILAN BAGLANTI CUMLESI: " + connectionString);

// 2. SONRA VERİTABANI BAĞLANTISINI KURUYORUZ
builder.Services.AddDbContext<VividoDbContext>(options =>
    options.UseNpgsql(connectionString, o => o.UseNetTopologySuite())
           .UseSnakeCaseNamingConvention()
);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
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