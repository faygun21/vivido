using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Vivido.Application.dtos.location;

namespace Vivido.Api.Controllers;

/// <summary>
/// R-105 mahalle, adres ve yer adı araması.
///
/// ⚠️ Bu uç ÜÇÜNCÜ TARAF servislere (Photon, ardından Nominatim) istek
/// doğuruyor — kendi veritabanımıza değil. Nominatim'in kullanım politikası
/// saniyede en fazla 1 istek diyor ve aşan IP'leri kalıcı olarak
/// engelliyor. Arayüz her tuş vuruşunda arama tetiklediği için, giriş
/// yapmış TEK bir kullanıcı bile sınırsız bırakıldığında Vivido'nun sunucu
/// IP'sini yaktırabilir; o andan sonra konum araması HERKES için biter.
/// Bu yüzden `[Authorize]` yetmiyor, ayrıca IP başına sınırlı — bkz.
/// Program.cs "geocoding" policy'si.
/// </summary>
[ApiController]
[Route("api/v1/locations")]
[Authorize]
[EnableRateLimiting("geocoding")]
public sealed class LocationsController : ControllerBase
{
    private const int MaximumQueryLength = 200;
    private const int MaximumResultCount = 10;
    private readonly ILocationSearchService _locationSearch;

    public LocationsController(ILocationSearchService locationSearch)
    {
        _locationSearch = locationSearch;
    }

    /// <summary>
    /// Haritanın merkezleyebileceği mahalle, adres veya yer adı sonuçlarını döndürür.
    /// </summary>
    [HttpGet("search")]
    [ProducesResponseType<LocationSearchResponseDto>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> Search(
        [FromQuery(Name = "q")] string? query,
        [FromQuery] int limit = 5,
        CancellationToken cancellationToken = default)
    {
        var trimmedQuery = query?.Trim();
        if (string.IsNullOrWhiteSpace(trimmedQuery) || trimmedQuery.Length < 2)
        {
            ModelState.AddModelError("q", "Arama metni en az 2 karakter olmalıdır.");
        }
        else if (trimmedQuery.Length > MaximumQueryLength)
        {
            ModelState.AddModelError("q", $"Arama metni en fazla {MaximumQueryLength} karakter olabilir.");
        }

        if (limit is < 1 or > MaximumResultCount)
        {
            ModelState.AddModelError("limit", $"Sonuç sayısı 1 ile {MaximumResultCount} arasında olmalıdır.");
        }

        if (!ModelState.IsValid)
        {
            return BadRequest(new ValidationProblemDetails(ModelState)
            {
                Status = StatusCodes.Status400BadRequest,
                Title = "Konum arama isteği geçersiz",
            });
        }

        try
        {
            var response = await _locationSearch.SearchAsync(
                trimmedQuery!,
                limit,
                cancellationToken);
            return Ok(response);
        }
        catch (LocationSearchUnavailableException)
        {
            return ApiProblem.LocationSearchUnavailable();
        }
    }
}
