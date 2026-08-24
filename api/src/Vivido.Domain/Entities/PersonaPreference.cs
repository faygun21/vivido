namespace Vivido.Domain.Entities;

public class PersonaCategoryWeight
{
    public required string PersonaCode { get; set; }
    public required string CategoryCode { get; set; }
    public double Weight { get; set; }
}