using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Api.DTOs.Auth;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;
using Vivido.Api.Services;
using System.Security.Cryptography;
using System.Text;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/auth")]
public class AuthController : ControllerBase
{
    private readonly VividoDbContext _context;
    private readonly JwtService _jwtService;
    private readonly IConfiguration _config;

    public AuthController(VividoDbContext context, JwtService jwtService, IConfiguration config)
    {
        _context = context;
        _jwtService = jwtService;
        _config = config;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
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

        var newUser = new User
        {
            Email = request.Email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            DisplayName = request.DisplayName
        };

        _context.Users.Add(newUser);
        await _context.SaveChangesAsync();

        var accessToken = _jwtService.GenerateAccessToken(newUser.Id, newUser.Email);
        var rawRefreshToken = _jwtService.GenerateRefreshToken();
        var expiresIn = int.Parse(_config["Jwt:AccessTokenMinutes"]!) * 60; 

        var refreshTokenEntity = new RefreshToken
        {
            UserId = newUser.Id,
            TokenHash = HashToken(rawRefreshToken), // BCrypt yerine veritabanında aranabilir SHA256 kullanıyoruz
            ExpiresAt = DateTime.UtcNow.AddDays(double.Parse(_config["Jwt:RefreshTokenDays"]!))
        };
        
        _context.RefreshTokens.Add(refreshTokenEntity);
        await _context.SaveChangesAsync();

        var authUser = new AuthUser(newUser.Id, newUser.Email, newUser.DisplayName);
        return Created(string.Empty, new AuthResponse(authUser, new TokenPair(accessToken, rawRefreshToken, expiresIn)));
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var user = await _context.Users.SingleOrDefaultAsync(u => u.Email == request.Email);

        // Kullanıcı yoksa veya şifre yanlışsa sözleşme gereği aynı hatayı dönüyoruz
        if (user == null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            return Unauthorized(new 
            {
                type = "https://vivido.dev/errors/invalid-credentials",
                title = "Giriş başarısız",
                status = 401,
                code = "INVALID_CREDENTIALS"
            });
        }

        var accessToken = _jwtService.GenerateAccessToken(user.Id, user.Email);
        var rawRefreshToken = _jwtService.GenerateRefreshToken();
        var expiresIn = int.Parse(_config["Jwt:AccessTokenMinutes"]!) * 60;

        var refreshTokenEntity = new RefreshToken
        {
            UserId = user.Id,
            TokenHash = HashToken(rawRefreshToken),
            ExpiresAt = DateTime.UtcNow.AddDays(double.Parse(_config["Jwt:RefreshTokenDays"]!))
        };
        
        _context.RefreshTokens.Add(refreshTokenEntity);
        await _context.SaveChangesAsync();

        var authUser = new AuthUser(user.Id, user.Email, user.DisplayName);
        return Ok(new AuthResponse(authUser, new TokenPair(accessToken, rawRefreshToken, expiresIn)));
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh([FromBody] RefreshRequest request)
    {
        var hash = HashToken(request.RefreshToken);
        
        // Token'ı ve sahibini veritabanında arıyoruz
        var storedToken = await _context.RefreshTokens
            .Include(rt => rt.User)
            .SingleOrDefaultAsync(rt => rt.TokenHash == hash);

        // Token bulunamazsa veya iptal edilmişse hata dön (Rotasyon güvenliği)[cite: 2]
        if (storedToken == null || storedToken.RevokedAt != null)
        {
            return Unauthorized(new { type = "https://vivido.dev/errors/token-revoked", title = "Geçersiz token", status = 401, code = "TOKEN_REVOKED" });
        }

        // Token'ın süresi dolmuşsa hata dön[cite: 2]
        if (storedToken.ExpiresAt < DateTime.UtcNow)
        {
            return Unauthorized(new { type = "https://vivido.dev/errors/token-expired", title = "Token süresi dolmuş", status = 401, code = "TOKEN_EXPIRED" });
        }

        // Rotasyon Kuralı: Kullanılan eski token'ı iptal et[cite: 1, 2]
        storedToken.RevokedAt = DateTime.UtcNow;

        // Yeni token çiftini üret
        var accessToken = _jwtService.GenerateAccessToken(storedToken.User.Id, storedToken.User.Email);
        var newRawRefreshToken = _jwtService.GenerateRefreshToken();
        var expiresIn = int.Parse(_config["Jwt:AccessTokenMinutes"]!) * 60;

        var newRefreshTokenEntity = new RefreshToken
        {
            UserId = storedToken.UserId,
            TokenHash = HashToken(newRawRefreshToken),
            ExpiresAt = DateTime.UtcNow.AddDays(double.Parse(_config["Jwt:RefreshTokenDays"]!))
        };

        _context.RefreshTokens.Add(newRefreshTokenEntity);
        await _context.SaveChangesAsync();

        var authUser = new AuthUser(storedToken.User.Id, storedToken.User.Email, storedToken.User.DisplayName);
        return Ok(new AuthResponse(authUser, new TokenPair(accessToken, newRawRefreshToken, expiresIn)));
    }

    // Refresh token'ları veritabanında hızlıca bulabilmek için SHA256 ile şifreleyen yardımcı metot
    private static string HashToken(string token)
    {
        using var sha256 = SHA256.Create();
        var bytes = Encoding.UTF8.GetBytes(token);
        var hash = sha256.ComputeHash(bytes);
        return Convert.ToBase64String(hash);
    }
}