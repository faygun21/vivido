using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace Vivido.Api.Services;

public class JwtService
{
    private readonly IConfiguration _config;

    public JwtService(IConfiguration config)
    {
        _config = config;
    }

    // Kısa ömürlü Access Token üretir
    public string GenerateAccessToken(Guid userId, string email, bool isAdmin)
    {
        // .env / config içindeki gizli anahtarı okuyoruz
        var key = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(_config["Jwt:Key"]!)
        );

        var creds = new SigningCredentials(
            key,
            SecurityAlgorithms.HmacSha256
        );

        var claims = new[]
        {
            // Kullanıcının id'si
            new Claim(
                JwtRegisteredClaimNames.Sub,
                userId.ToString()
            ),

            // Kullanıcının e-postası
            new Claim(
                JwtRegisteredClaimNames.Email,
                email
            ),

            // Kullanıcının rolü
            // isAdmin true ise Admin, değilse User
            new Claim(
                ClaimTypes.Role,
                isAdmin ? "Admin" : "User"
            ),

            // Her token için benzersiz id
            new Claim(
                JwtRegisteredClaimNames.Jti,
                Guid.NewGuid().ToString()
            )
        };

        var token = new JwtSecurityToken(
            issuer: _config["Jwt:Issuer"],
            audience: _config["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(
                double.Parse(_config["Jwt:AccessTokenMinutes"]!)
            ),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    // Uzun ömürlü Refresh Token üretir
    // Bu JWT değildir; güvenli rastgele bir metindir
    public string GenerateRefreshToken()
    {
        return Convert.ToBase64String(
            System.Security.Cryptography.RandomNumberGenerator.GetBytes(64)
        );
    }
}