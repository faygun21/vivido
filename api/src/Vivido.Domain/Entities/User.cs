namespace Vivido.Domain.Entities;

public class User
{
    
    public Guid Id { get; set; } = Guid.NewGuid();
    
    public required string Email { get; set; }
    
    public required string PasswordHash { get; set; }
    
    public string? DisplayName { get; set; } 
    
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    
    
}