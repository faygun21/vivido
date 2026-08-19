namespace Vivido.Domain.Entities;

public class RefreshToken
{
    public Guid Id { get; set; } = Guid.NewGuid();
    
    
    public required string TokenHash { get; set; }
    
    public Guid UserId { get; set; }
    
    public User User { get; set; } = null!;
    
    public DateTime ExpiresAt { get; set; }
    
    public DateTime? RevokedAt { get; set; } 
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}