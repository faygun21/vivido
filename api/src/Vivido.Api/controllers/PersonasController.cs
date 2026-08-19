using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vivido.Application.dtos.persona; // DTO dosyanın tam namespace'ine göre burayı teyit et
using Vivido.Infrastructure.Data; // VividoDbContext'in bulunduğu namespace

namespace Vivido.Api.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
[AllowAnonymous] 
public class PersonasController : ControllerBase
{
    private readonly VividoDbContext _context;

    public PersonasController(VividoDbContext context)
    {
        _context = context;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<PersonaDto>>> GetPersonas()
    {
        var personas = await _context.Personas
            .AsNoTracking()
            .Select(p => new PersonaDto(
                p.Code,
                p.DisplayNameTr,
                p.DescriptionTr,
                p.Icon
            ))
            .ToListAsync();

        return Ok(personas);
    }
}