using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Api.DTOs.Auth;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;
using Vivido.Api.Services; 

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/auth")]
public class AuthController : ControllerBase
{
    private readonly VividoDbContext _context;
    private readonly JwtService _jwtService;
    private readonly IConfiguration _config;

    // 1. Sınıfın kurucusuna (constructor) JwtService ve Ayarları (IConfiguration) enjekte ediyoruz
    public AuthController(VividoDbContext context, JwtService jwtService, IConfiguration config)
    {
        _context = context;
        _jwtService = jwtService;
        _config = config;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        // 1. E-posta Zaten Var Mı Kontrolü
        bool userExists = await _context.Users.AnyAsync(u => u.Email == request.Email);
        if (userExists)
        {
            return Conflict(new 
            {
                type = "https://vivido.dev/errors/email-already-exists",
                title = "Bu e-posta zaten kayıtlı",
                status = 409,
                detail = $"{request.Email} adresiyle bir hesap mevcut.",
                code = "EMAIL_ALREADY_EXISTS"
            });
        }

        // 2. Yeni Kullanıcıyı Oluştur ve Şifreyi Kriptola (BCrypt)
        var newUser = new User
        {
            Email = request.Email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            DisplayName = request.DisplayName
        };

        _context.Users.Add(newUser);
        await _context.SaveChangesAsync(); // Kullanıcının Id'si (Guid) oluşsun diye önce bunu kaydediyoruz

        // 3. Gerçek Token'ları Üret
        var accessToken = _jwtService.GenerateAccessToken(newUser.Id, newUser.Email);
        var rawRefreshToken = _jwtService.GenerateRefreshToken();
        
        // Sözleşmeye göre süre "saniye" (expiresIn) cinsinden döner
        var expiresIn = int.Parse(_config["Jwt:AccessTokenMinutes"]!) * 60; 

        // 4. Güvenlik Kuralı: Refresh Token'ı hash'leyerek veritabanına kaydet
        var refreshTokenEntity = new RefreshToken
        {
            UserId = newUser.Id,
            TokenHash = BCrypt.Net.BCrypt.HashPassword(rawRefreshToken),
            ExpiresAt = DateTime.UtcNow.AddDays(double.Parse(_config["Jwt:RefreshTokenDays"]!))
        };
        
        _context.RefreshTokens.Add(refreshTokenEntity);
        await _context.SaveChangesAsync();

        // 5. Yanıtı Hazırla (Kullanıcıya açık halini SADECE bir kere, burada döner)
        var authUser = new AuthUser(newUser.Id, newUser.Email, newUser.DisplayName);
        var tokenPair = new TokenPair(accessToken, rawRefreshToken, expiresIn);

        return Created(string.Empty, new AuthResponse(authUser, tokenPair));
    }
}