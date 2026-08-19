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
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(o =>
{
    o.SwaggerDoc("v1", new()
    {
        Title = "Vivido API",
        Version = "v1",
        Description = "Kiralık ev bulma, kişiselleştirilmiş skorlama ve ziyaret rotası"
    });
});

// JwtService'i sisteme kaydediyoruz
builder.Services.AddScoped<JwtService>();

// JWT Doğrulama ayarlarını ekliyoruz
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

// Sağlık kontrolleri.
// Hafta 2'de PostGIS, Redis ve OSRM kontrolleri buraya eklenecek.
builder.Services.AddHealthChecks()
    .AddNpgSql(connectionString, name: "database");

// Web ve mobil istemciler için CORS.
// Mobil fiziksel cihazdan geldiğinde origin farklı olur — geliştirmede serbest bırakıyoruz.
const string DevCors = "dev";
builder.Services.AddCors(o => o.AddPolicy(DevCors, p => p
    .AllowAnyOrigin()
    .AllowAnyMethod()
    .AllowAnyHeader()));

// Veritabanı bağlantı dizesini (.env dosyasından) alıyoruz
var connectionString = builder.Configuration.GetConnectionString("Default");

builder.Services.AddDbContext<VividoDbContext>(options =>
    options.UseNpgsql(connectionString, o => o.UseNetTopologySuite())
           .UseSnakeCaseNamingConvention()
);

var app = builder.Build();

// ─── Boru hattı ───
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(o => o.SwaggerEndpoint("/swagger/v1/swagger.json", "Vivido API v1"));
    app.UseCors(DevCors);
    //Kimlik kontrolü için eklenen satırlar
    app.UseAuthentication();
    app.UseAuthorization();
}

app.UseSerilogRequestLogging();

// Uygulama ayakta mı? (yeniden başlatma kararı için)
app.MapHealthChecks("/health/live");

// Bağımlılıklar hazır mı? (trafik almaya hazır mı)
// Hafta 2: DB + Redis + OSRM kontrolleri eklenince anlamlı hale gelecek.
app.MapHealthChecks("/health/ready");

app.MapControllers();

app.Run();

// Entegrasyon testlerinin WebApplicationFactory ile erişebilmesi için.
public partial class Program;
