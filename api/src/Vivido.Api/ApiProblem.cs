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
}
