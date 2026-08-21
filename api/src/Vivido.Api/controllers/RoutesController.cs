using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Application.Dtos.Route;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/routes")]
[Authorize] // Sadece giriş yapmış kullanıcılar
public class RoutesController : ControllerBase
{
    private readonly VividoDbContext _context;

    public RoutesController(VividoDbContext context)
    {
        _context = context;
    }

    private Guid GetUserId()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.Parse(userIdStr!);
    }

    // GET: /api/v1/routes
    [HttpGet]
    public async Task<IActionResult> GetRoutes()
    {
        var userId = GetUserId();
        
        var routes = await _context.Routes
            .Where(r => r.UserId == userId)
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new RouteListResponse
            {
                Id = r.Id,
                Name = r.Name,
                Mode = r.Mode,
                TotalDistanceM = r.TotalDistanceM,
                TotalDurationS = r.TotalDurationS,
                CreatedAt = r.CreatedAt,
                StopCount = r.Stops.Count
            })
            .ToListAsync();

        return Ok(routes);
    }

    // GET: /api/v1/routes/{id}
    [HttpGet("{id}")]
    public async Task<IActionResult> GetRoute(Guid id)
    {
        var userId = GetUserId();

        var route = await _context.Routes
            .Include(r => r.Stops)
            .FirstOrDefaultAsync(r => r.Id == id && r.UserId == userId);

        if (route == null)
        {
            return NotFound(); // RFC 7807 problem+json yapısına Hafta 2'de bağlanacak
        }

        var response = new RouteDetailResponse
        {
            Id = route.Id,
            Name = route.Name,
            Mode = route.Mode,
            TotalDistanceM = route.TotalDistanceM,
            TotalDurationS = route.TotalDurationS,
            CreatedAt = route.CreatedAt,
            StopCount = route.Stops.Count,
            StartLabel = route.StartLabel,
            Start = new CoordinateDto 
            { 
                Lat = route.StartGeom.Y, 
                Lon = route.StartGeom.X 
            },
            Steps = route.Steps, // JSONB verisi otomatik deserialize edilir
            Stops = route.Stops.OrderBy(s => s.Seq).Select(s => new RouteStopDto
            {
                Seq = s.Seq,
                PropertyId = s.PropertyId,
                ScoreSnapshot = s.ScoreSnapshot,
                LegDistanceM = s.LegDistanceM,
                LegDurationS = s.LegDurationS,
                VisitedAt = s.VisitedAt
            }).ToList()
        };

        return Ok(response);
    }

    // DELETE: /api/v1/routes/{id}
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteRoute(Guid id)
    {
        var userId = GetUserId();

        var route = await _context.Routes
            .FirstOrDefaultAsync(r => r.Id == id && r.UserId == userId);

        if (route != null)
        {
            _context.Routes.Remove(route);
            await _context.SaveChangesAsync();
        }

        return NoContent(); // 204 Başarılı silme
    }
}