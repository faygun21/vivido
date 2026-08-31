using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Vivido.Api.services;

namespace Vivido.Api.Services;

public class JwtService
{
    private readonly JwtOptions _options;

    public JwtService(IOptions<JwtOptions> options)
    {
        _options = options.Value;
    }

    // Kısa ömürlü Access Token üretir
    public string GenerateAccessToken(Guid userId, string email, bool isAdmin)
    {
        // .env / config içindeki gizli anahtarı okuyoruz
        var key = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(_options.Key)
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
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_options.AccessTokenMinutes),
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