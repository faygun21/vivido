using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Api.DTOs.Auth;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;
using BCrypt.Net;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/auth")] // Rehber kuralı: Tüm auth endpointleri bu yolun altında[cite: 1]
public class AuthController : ControllerBase
{
    private readonly VividoDbContext _context;

    // Veritabanı bağlantımızı (DbContext) içeri alıyoruz (Dependency Injection)
    public AuthController(VividoDbContext context)
    {
        _context = context;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        // 1. E-posta Zaten Var Mı Kontrolü
        bool userExists = await _context.Users.AnyAsync(u => u.Email == request.Email);
        if (userExists)
        {
            // Sözleşmeye tam uyumlu RFC 7807 hata formatı[cite: 1, 2]
            return Conflict(new 
            {
                type = "https://vivido.dev/errors/email-already-exists",
                title = "Bu e-posta zaten kayıtlı",
                status = 409,
                detail = $"{request.Email} adresiyle bir hesap mevcut.",
                code = "EMAIL_ALREADY_EXISTS"
            });
        }

        // 2. Yeni Kullanıcıyı Oluştur ve Şifreyi Güvenli Hale Getir (BCrypt)[cite: 1]
        var newUser = new User
        {
            Email = request.Email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            DisplayName = request.DisplayName
        };

        _context.Users.Add(newUser);
        await _context.SaveChangesAsync();

        // 3. Kullanıcı Bilgisini Hazırla
        var authUser = new AuthUser(newUser.Id, newUser.Email, newUser.DisplayName);
        
        // ŞİMDİLİK JWT Token üretimini boş (dummy) bırakıyoruz, bir sonraki adımda gerçek JWT yazacağız.
        var dummyTokens = new TokenPair("gecici_access_token", "gecici_refresh_token", 900);

        // Sözleşme Kuralı: Kayıt işlemi başarılıysa 201 Created dönmeli[cite: 1, 2]
        return Created(string.Empty, new AuthResponse(authUser, dummyTokens));
    }
}