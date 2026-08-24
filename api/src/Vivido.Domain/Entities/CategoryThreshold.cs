namespace Vivido.Domain.Entities;

public class PoiCategory
{
    public string Code { get; set; } = null!;
    public double TIdealMin { get; set; }
    public double THalfMin { get; set; }
    public double TCutoffMin { get; set; }
    public bool Active { get; set; } = true;
}