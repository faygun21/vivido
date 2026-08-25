namespace Vivido.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;
using System;
using System.Threading.Tasks;
using Vivido.Api.services;
using Vivido.Application.dtos.property;
using Vivido.Infrastructure.Data;

[ApiController]
[Route("api/v1/properties")]
public class PropertiesController : ControllerBase
{
    private const int MaximumPropertyCount = 2000;
    private readonly PropertyScoringService _scoringService;
    private readonly VividoDbContext _context;

    public PropertiesController(PropertyScoringService scoringService, VividoDbContext context)
    {
        _scoringService = scoringService;
        _context = context;
    }

    /// <summary>
    /// R-109/R-110 — harita görünüm alanındaki (bbox) konutları döndürür.
    /// Konut noktaları herkese açık harita verisidir ([AllowAnonymous]);
    /// skor hesaplama ayrıca <c>profileId</c> ister.
    /// </summary>
    [HttpGet]
    [AllowAnonymous]
    [ProducesResponseType<List<MapPropertyDto>>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GetPropertiesForMap(
        [FromQuery] double west,
        [FromQuery] double south,
        [FromQuery] double east,
        [FromQuery] double north,
        CancellationToken cancellationToken)
    {
        if (west < -180 || east > 180 || south < -90 || north > 90 || west >= east || south >= north)
        {
            ModelState.AddModelError("bbox",
                "Geçerli bir sınırlayıcı kutu gerekli: -180 ≤ west < east ≤ 180 ve -90 ≤ south < north ≤ 90.");
        }

        if (!ModelState.IsValid)
        {
            return BadRequest(new ValidationProblemDetails(ModelState)
            {
                Status = StatusCodes.Status400BadRequest,
                Title = "Konut isteği geçersiz",
            });
        }

        var boundsGeom = new GeometryFactory(new PrecisionModel(), 4326)
            .ToGeometry(new Envelope(west, east, south, north));

        var items = await _context.Properties
            .AsNoTracking()
            .Where(p => p.Geom.Intersects(boundsGeom))
            .OrderBy(p => p.Id)
            .Take(MaximumPropertyCount)
            .Select(p => new MapPropertyDto(
                p.Id,
                p.ExternalRef,
                p.Geom.Y,
                p.Geom.X,
                p.MonthlyRent,
                p.AreaM2,
                p.RoomCount,
                p.BuildingAge,
                p.HasElevator,
                p.IsSynthetic))
            .ToListAsync(cancellationToken);

        return Ok(items);
    }

    [HttpGet("{propertyId}/score")]
    public async Task<IActionResult> GetPropertyScore(long propertyId, [FromQuery] Guid profileId)
    {
        if (profileId == Guid.Empty)
        {
            return BadRequest(new { Message = "Geçerli bir profileId belirtilmelidir." });
        }

        try
        {
            // Servisimizi çağırıyoruz (Cache'de varsa oradan, yoksa hesaplayıp dönecek)
            var score = await _scoringService.ScorePropertyAsync(propertyId, profileId);

            return Ok(new
            {
                PropertyId = propertyId,
                ProfileId = profileId,
                Score = score
            });
        }
        catch (Exception ex)
        {
            // Gerçek bir senaryoda burası ILogger ile loglanmalı
            return StatusCode(500, new { Message = "Skor hesaplanırken sunucu tarafında bir hata oluştu.", Details = ex.Message });
        }
    }
}
