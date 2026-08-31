using Microsoft.AspNetCore.Mvc;

namespace Vivido.Api;

/// <summary>
/// RFC 7807 <c>application/problem+json</c> yanıtları üretir.
///
/// Sözleşme (vivido-api-sozlesmesi.md §5, K-D): arayüz Türkçe <c>title</c>
/// metnine göre DEĞİL, makine tarafından okunan <c>code</c> alanına göre
/// dallanır. Metin değişebilir, kod sabittir.
/// </summary>
public static class ApiProblem
{
    public static ObjectResult Build(int status, string title, string code, string? detail = null)
    {
        var problem = new ProblemDetails
        {
            Status = status,
            Title = title,
            Detail = detail,
            Type = $"https://vivido.dev/errors/{code.ToLowerInvariant().Replace('_', '-')}",
        };
        problem.Extensions["code"] = code;

        return new ObjectResult(problem)
        {
            StatusCode = status,
            ContentTypes = { "application/problem+json" },
        };
    }

    public static ObjectResult ProfileNotFound() => Build(
        404,
        "Profil henüz oluşturulmamış",
        "PROFILE_NOT_FOUND",
        "Önce persona seçip profilinizi kaydedin.");

    public static ObjectResult AnchorLimitExceeded(int max) => Build(
        422,
        $"En fazla {max} yer eklenebilir",
        "ANCHOR_LIMIT_EXCEEDED",
        $"Yeni bir yer eklemek için önce mevcut {max} yerden birini silin.");

    public static ObjectResult InvalidAnchorOrder(string detail) => Build(
        422,
        "Sıralama isteği geçersiz",
        "INVALID_ANCHOR_ORDER",
        detail);

    public static ObjectResult LocationSearchUnavailable() => Build(
        503,
        "Konum arama servisi kullanılamıyor",
        "LOCATION_SEARCH_UNAVAILABLE",
        "Lütfen kısa bir süre sonra yeniden deneyin.");

    public static ObjectResult RouteStopLimitExceeded(int min, int max) => Build(
        422,
        "Rota durağı sayısı geçersiz",
        "ROUTE_STOP_LIMIT_EXCEEDED",
        $"Bir rota {min} ile {max} konut arasında içermelidir. (W7: en fazla {max} ev)");

    public static ObjectResult OsrmUnavailable() => Build(
        503,
        "Rota servisi kullanılamıyor",
        "OSRM_UNAVAILABLE",
        "OSRM (Routing) servisine ulaşılamadı ya da yanıt vermedi. Lütfen kısa bir süre sonra yeniden deneyin.");

    /// <summary>
    /// Seçilen konutlar arasında (OSRM'in bildiği yol ağına göre) hiçbir
    /// bağlantı yok — Held-Karp'ın <c>InvalidOperationException</c> fırlattığı
    /// tek durum. 500 değil 422: istemcinin hatası değilse de, "farklı
    /// konutlar seçin" ile çözülebilecek bir durum — sunucu hatası değil.
    /// </summary>
    public static ObjectResult RouteUnreachable() => Build(
        422,
        "Seçilen konutlar arasında bir rota kurulamadı",
        "ROUTE_UNREACHABLE",
        "Seçilen konutlardan bazılarına yol ağı üzerinden ulaşılamıyor. Farklı bir başlangıç noktası ya da konut seçimi deneyin.");

    /// <summary>Rota hesaplama, sunucunun kendi üst sınırı içinde tamamlanamadı (bkz. RoutesController).</summary>
    public static ObjectResult RouteTimeout() => Build(
        504,
        "Rota hesaplama zaman aşımına uğradı",
        "ROUTE_TIMEOUT",
        "Rota servisi beklenenden uzun sürdü. Lütfen kısa bir süre sonra yeniden deneyin.");

    /// <summary>
    /// Beklenmeyen (kodun öngörmediği) bir hata — global exception handler
    /// tarafından kullanılır. Detay kasıtlı olarak İÇERMEZ: iç hata mesajı
    /// (SQL, stack trace vb.) istemciye asla sızdırılmaz, yalnızca loglanır.
    /// </summary>
    public static ObjectResult InternalError() => Build(
        500,
        "Beklenmeyen bir hata oluştu",
        "INTERNAL_ERROR",
        "Sorun devam ederse lütfen destek ekibiyle iletişime geçin.");

    // ─── Kimlik doğrulama (K-09) ───

    public static ObjectResult EmailAlreadyExists(string email) => Build(
        409,
        "Bu e-posta zaten kayıtlı",
        "EMAIL_ALREADY_EXISTS",
        $"{email} adresiyle bir hesap mevcut. Giriş yapmayı ya da şifrenizi sıfırlamayı deneyin.");

    public static ObjectResult InvalidCredentials() => Build(
        401,
        "E-posta veya şifre hatalı",
        "INVALID_CREDENTIALS");

    public static ObjectResult EmailNotVerified() => Build(
        403,
        "E-posta adresi doğrulanmamış",
        "EMAIL_NOT_VERIFIED",
        "Giriş yapabilmek için e-postanıza gönderilen 6 haneli kodu girin.");

    public static ObjectResult InvalidCode() => Build(
        400,
        "Kod geçersiz",
        "INVALID_CODE",
        "Girdiğiniz kod hatalı. Kodu e-postadan kopyalayıp tekrar deneyin.");

    public static ObjectResult CodeExpired() => Build(
        400,
        "Kodun süresi doldu",
        "CODE_EXPIRED",
        "Yeni bir kod isteyip tekrar deneyin.");

    public static ObjectResult TooManyAttempts() => Build(
        429,
        "Çok fazla hatalı deneme",
        "TOO_MANY_ATTEMPTS",
        "Bu kod kilitlendi. Yeni bir kod isteyin.");

    public static ObjectResult ResendTooSoon(int seconds) => Build(
        429,
        "Çok sık kod isteniyor",
        "RESEND_TOO_SOON",
        $"Yeni bir kod istemeden önce {seconds} saniye bekleyin.");

    public static ObjectResult EmailSendFailed() => Build(
        502,
        "Doğrulama e-postası gönderilemedi",
        "EMAIL_SEND_FAILED",
        "E-posta servisi şu anda yanıt vermiyor. Birkaç dakika sonra tekrar deneyin.");

    /// <summary>Alan bazlı doğrulama hatası — istemci `errors` sözlüğünü okur.</summary>
    public static ObjectResult Validation(Dictionary<string, string[]> errors)
    {
        var result = Build(400, "Gönderilen bilgiler geçersiz", "VALIDATION_ERROR");
        ((ProblemDetails)result.Value!).Extensions["errors"] = errors;
        return result;
    }
}
