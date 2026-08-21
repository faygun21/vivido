namespace Vivido.Domain.Entities;

public class FavoriteProperty
{
    public Guid UserId { get; set; }
    public long PropertyId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation property
    public User User { get; set; } = null!;
}