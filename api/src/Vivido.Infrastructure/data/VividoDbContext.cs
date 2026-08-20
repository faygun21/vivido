using Microsoft.EntityFrameworkCore;
using Vivido.Domain.Entities;

namespace Vivido.Infrastructure.Data; 

public class VividoDbContext : DbContext
{
    public VividoDbContext(DbContextOptions<VividoDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users { get; set; } = null!;
    public DbSet<Persona> Personas { get; set; }
    public DbSet<RefreshToken> RefreshTokens { get; set; } = null!;

    public DbSet<UserProfile> UserProfiles { get; set; }
    public DbSet<Anchor> Anchors { get; set; }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<User>(entity =>
        {
            entity.ToTable("users"); 
            entity.Property(e => e.Email).HasColumnType("citext"); 
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()"); 
        });

        builder.Entity<RefreshToken>(entity =>
        {
            entity.ToTable("refresh_tokens"); 
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");
        });

        // --- BURASI EKLENECEK ---
        builder.Entity<Persona>(entity =>
        {
            entity.ToTable("personas");
            entity.HasKey(e => e.Code); // Persona tablosunun birincil anahtarı
        });
        // -------------------------

        builder.Entity<UserProfile>(entity =>
        {
            entity.ToTable("user_profiles");
            entity.HasKey(e => e.Id);
            
            // Persona ile ilişki
            entity.HasOne(e => e.Persona)
                  .WithMany()
                  .HasForeignKey(e => e.PersonaCode)
                  .HasPrincipalKey(p => p.Code);
        });

        builder.Entity<Anchor>(entity =>
        {
            entity.ToTable("anchors");
            entity.HasKey(e => e.Id);

            // UserProfile ile 1-N ilişki ve Cascade silme
            entity.HasOne(e => e.Profile)
                  .WithMany(p => p.Anchors)
                  .HasForeignKey(e => e.ProfileId)
                  .OnDelete(DeleteBehavior.Cascade);

            // PostGIS Point geometry alanı tanımı (NTS ile uyumlu)
            entity.Property(e => e.Geom)
                  .HasColumnType("geometry (Point, 4326)");
        });
    }
}