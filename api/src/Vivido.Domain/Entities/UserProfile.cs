namespace Vivido.Domain.Entities;

public class UserProfile
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }

    public required string FirstName { get; set; }
    public required string LastName { get; set; }

    public required string PersonaCode { get; set; }
    public decimal? MonthlyBudget { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public Persona Persona { get; set; } = null!;
    public ICollection<Anchor> Anchors { get; set; } = new List<Anchor>();
}