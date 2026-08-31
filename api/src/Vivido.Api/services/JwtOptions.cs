using System.ComponentModel.DataAnnotations;

namespace Vivido.Api.services;

/// <summary>
/// JWT yapılandırması — appsettings/env'den <c>Jwt:*</c> bölümüne bağlanır.
///
/// ⭐ NEDEN: eskiden bu değerler <see cref="IConfiguration"/> üzerinden
/// `_config["Jwt:Key"]!` gibi null-forgiving okumalarla, kullanım anında
/// (ilk login isteğinde) çekiliyordu — eksik/bozuk bir değer üretimde
/// kullanıcı giriş yapmaya çalışırken patlıyordu. `ValidateOnStart()` ile
/// birlikte kullanılınca uygulama AÇILIRKEN doğrulanır: yanlış yapılandırma
/// deploy'u durdurur, canlıdaki ilk kullanıcıyı değil.
/// </summary>
public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    /// <summary>HMAC-SHA256 imzalama anahtarı. 32+ karakter — kısa anahtar kaba kuvvetle kırılabilir.</summary>
    [Required(AllowEmptyStrings = false)]
    [MinLength(32, ErrorMessage = "Jwt:Key en az 32 karakter olmalı (HMAC-SHA256 için güvenli anahtar uzunluğu).")]
    public string Key { get; set; } = string.Empty;

    [Required(AllowEmptyStrings = false)]
    public string Issuer { get; set; } = string.Empty;

    [Required(AllowEmptyStrings = false)]
    public string Audience { get; set; } = string.Empty;

    [Range(1, 1440)]
    public int AccessTokenMinutes { get; set; } = 15;

    [Range(0.1, 365)]
    public double RefreshTokenDays { get; set; } = 30;
}
