using Microsoft.EntityFrameworkCore;
using Vivido.Domain.Entities;

namespace Vivido.Infrastructure.Data; 

public class VividoDbContext : DbContext
{
    public VividoDbContext(DbContextOptions<VividoDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users { get; set; } = null!;
    public DbSet<RefreshToken> RefreshTokens { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<User>(entity =>
        {
            entity.ToTable("users"); 
            
            entity.Property(e => e.Email).HasColumnType("citext"); 
            
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()"); 
            entity.Property(e => e.UpdatedAt).HasDefaultValueSql("now()");
        });

        
        builder.Entity<RefreshToken>(entity =>
        {
            entity.ToTable("refresh_tokens"); 
            
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");
        });
    }
}