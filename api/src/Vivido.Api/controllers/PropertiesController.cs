namespace Vivido.Api.Controllers;

using Microsoft.AspNetCore.Mvc;
using System;
using System.Threading.Tasks;
using Vivido.Api.services;

[ApiController]
[Route("api/[controller]")]
public class PropertiesController : ControllerBase
{
    private readonly PropertyScoringService _scoringService;

    public PropertiesController(PropertyScoringService scoringService)
    {
        _scoringService = scoringService;
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