namespace Vivido.Domain.Entities;

public class Persona
{
    public required string Code { get; set; }
    public required string DisplayNameTr { get; set; }
    public required string DescriptionTr { get; set; }
    public string? Icon { get; set; }
}