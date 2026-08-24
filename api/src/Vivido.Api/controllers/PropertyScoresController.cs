using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;
using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/properties/{propertyId:long}/score")]
public class PropertyScoresController : ControllerBase
{
    private readonly VividoDbContext _db;
    private const string CurrentVersion = "v1";

    public PropertyScoresController(VividoDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> Get(long propertyId, [FromQuery] Guid? profileId)
    {
        if (profileId == null || profileId == Guid.Empty)
            return BadRequest(new { message = "Geçerli bir profileId belirtilmelidir" });

        // Try cache
        var cache = await _db.ScoreCaches.FirstOrDefaultAsync(c => c.PropertyId == propertyId && c.ProfileId == profileId && c.ScoringVersion == CurrentVersion);
        if (cache != null)
        {
            Response.Headers["X-Cache"] = "HIT";
            // return cached payload (score + breakdown)
            object? breakdown = null;
            if (!string.IsNullOrEmpty(cache.Breakdown))
            {
                            try { breakdown = JsonSerializer.Deserialize<object>(cache.Breakdown); } catch { breakdown = null; }
            }
            return Ok(new { score = Math.Round(cache.Score, 2), breakdown });
        }

        // Load profile
        var profile = await _db.UserProfiles.AsNoTracking().FirstOrDefaultAsync(p => p.Id == profileId);
        if (profile == null)
        {
            // Per spec: return 200 OK with score 0.0
            Response.Headers["X-Cache"] = "MISS";
            return Ok(new { score = 0.0, breakdown = new object[] { } });
        }

        // Get persona preferences (weights)
        var personaCode = profile.PersonaCode;
        var weights = await _db.PersonaCategoryWeights.Where(pp => pp.PersonaCode == personaCode).ToListAsync();

        // Get poi categories and property accesses for categories present in weights
        var categories = await _db.PoiCategories.Where(c => c.Active).ToListAsync();
        var accesses = await _db.PropertyPoiAccesses.Where(pd => pd.PropertyId == propertyId).ToListAsync();

        var breakdownList = new List<object>();
        var scoreInputs = new List<(double score, double weight)>();

        foreach (var pref in weights)
        {
            var cat = categories.FirstOrDefault(t => t.Code == pref.CategoryCode);
            var access = accesses.FirstOrDefault(d => d.CategoryCode == pref.CategoryCode);
            if (cat == null || access == null)
            {
                breakdownList.Add(new { category = pref.CategoryCode, score = 0.0, weight = pref.Weight, duration = access?.DurationMin });
                scoreInputs.Add((0.0, pref.Weight));
                continue;
            }

            var catScore = Vivido.Scoring.ScoringEngine.CalculateCategoryScore(access.DurationMin, cat.TIdealMin, cat.THalfMin, cat.TCutoffMin);
            breakdownList.Add(new { category = pref.CategoryCode, score = Math.Round(catScore, 2), weight = pref.Weight, duration = access.DurationMin });
            scoreInputs.Add((catScore, pref.Weight));
        }

        var overall = Vivido.Scoring.ScoringEngine.CalculateWeightedScore(scoreInputs);
        var overallRounded = Math.Round(overall, 2);

        // Persist to cache
        var newCache = new ScoreCache
        {
            PropertyId = propertyId,
            ProfileId = profileId.Value,
        ScoringVersion = CurrentVersion,
            Score = overallRounded,
        };
        newCache.SetBreakdown(breakdownList);
        _db.ScoreCaches.Add(newCache);
        await _db.SaveChangesAsync();

        Response.Headers["X-Cache"] = "MISS";
        return Ok(new { score = overallRounded, breakdown = breakdownList });
    }
}
