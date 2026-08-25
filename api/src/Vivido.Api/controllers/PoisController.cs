using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;
using Vivido.Application.dtos.poi;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

/// <summary>
/// R-108/R-110 — harita için POI verileri.
///
/// Bounding box + kategori filtresiyle çalışır; sonuç MapLibre GeoJSON
/// katmanına doğrudan beslenir. POI'ler herkese açık harita verisidir,
/// bu yüzden [AllowAnonymous] — misafir görünümü de POI katmanlarını kullanır.
/// </summary>
[ApiController]
[Route("api/v1/pois")]
public sealed class PoisController : ControllerBase
{
    private const int MaximumPoiCount = 5000;
    private readonly VividoDbContext _context;

    public PoisController(VividoDbContext context)
    {
        _context = context;
    }

    /// <summary>Görünüm alanındaki (bbox) ve istenen kategorilerdeki POI'leri döndürür.</summary>
    [HttpGet]
    [AllowAnonymous]
    [ProducesResponseType<List<PoiDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GetPois(
        [FromQuery] double west,
        [FromQuery] double south,
        [FromQuery] double east,
        [FromQuery] double north,
        [FromQuery] string? categories,
        CancellationToken cancellationToken)
    {
        if (west < -180 || east > 180 || south < -90 || north > 90 || west >= east || south >= north)
        {
            ModelState.AddModelError("bbox",
                "Geçerli bir sınırlayıcı kutu gerekli: -180 ≤ west < east ≤ 180 ve -90 ≤ south < north ≤ 90.");
        }

        var categorySet = ParseCategories(categories);

        // Bilinmeyen kategori kodu istenirse sessizce boş sonuç dönmek yerine
        // açık bir doğrulama hatası ver — katman paneli yalnızca bilinen kodları gönderir.
        if (categorySet.Count > 0)
        {
            var knownCodes = await _context.PoiCategories
                .AsNoTracking()
                .Where(c => c.Active)
                .Select(c => c.Code)
                .ToListAsync(cancellationToken);
            var known = new HashSet<string>(knownCodes, StringComparer.Ordinal);
            var unknown = categorySet
                .Where(code => !known.Contains(code))
                .OrderBy(code => code, StringComparer.Ordinal)
                .ToList();

            if (unknown.Count > 0)
            {
                ModelState.AddModelError("categories",
                    $"Bilinmeyen kategori kodu: {string.Join(", ", unknown)}.");
            }
        }

        if (!ModelState.IsValid)
        {
            return ApiProblem.Validation(ModelState.ToDictionary(
                kvp => kvp.Key,
                kvp => kvp.Value!.Errors.Select(e => e.ErrorMessage).ToArray()));
        }

        // SRID 4326'da bbox poligonu: GiST indeksini kullanan ST_Intersects ile eşleşir.
        var boundsGeom = new GeometryFactory(new PrecisionModel(), 4326)
            .ToGeometry(new Envelope(west, east, south, north));

        var query = _context.Pois
            .AsNoTracking()
            .Where(p => p.Geom.Intersects(boundsGeom));

        if (categorySet.Count > 0)
        {
            query = query.Where(p => categorySet.Contains(p.CategoryCode));
        }

        var items = await query
            .OrderBy(p => p.Id)
            .Take(MaximumPoiCount)
            .Select(p => new PoiDto(p.Id, p.Name, p.CategoryCode, p.Geom.Y, p.Geom.X))
            .ToListAsync(cancellationToken);

        return Ok(items);
    }

    /// <summary>Katman paneli için aktif POI kategorileri (kod + Türkçe ad).</summary>
    [HttpGet("categories")]
    [AllowAnonymous]
    [ProducesResponseType<List<PoiCategoryDto>>(StatusCodes.Status200OK)]
    public async Task<IActionResult> GetCategories(CancellationToken cancellationToken)
    {
        var categories = await _context.PoiCategories
            .AsNoTracking()
            .Where(c => c.Active)
            .OrderBy(c => c.Code)
            .Select(c => new PoiCategoryDto(c.Code, c.DisplayNameTr))
            .ToListAsync(cancellationToken);

        return Ok(categories);
    }

    private static HashSet<string> ParseCategories(string? categories)
    {
        var result = new HashSet<string>(StringComparer.Ordinal);
        if (string.IsNullOrWhiteSpace(categories)) return result;

        foreach (var part in categories.Split(',',
                     StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            result.Add(part);
        }

        return result;
    }
}
