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
    public DbSet<FavoriteProperty> FavoriteProperties { get; set; }

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

        builder.Entity<Persona>(entity =>
        {
            entity.ToTable("personas");
            // ⚠️ personas tablosunun PK'sı `code` (text). EF'in varsayılan
            // konvansiyonu `Id` adlı bir özellik arar, bulamayınca TÜM model
            // doğrulaması patlar ve veritabanına giden HER sorgu 500 döner —
            // register dahil. Anahtarı açıkça bildirmek zorunlu.
            //
            // Not: Aynı düzeltme `yazilim` dalında da bağımsız olarak yapıldı;
            // merge sırasında gerekçeyi taşıyan bu sürüm korundu.
            entity.HasKey(e => e.Code);
            entity.Property(e => e.Code).HasColumnName("code");
        });

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

        builder.Entity<FavoriteProperty>(entity =>
        {
            entity.ToTable("favorite_properties");
            entity.HasKey(e => new { e.UserId, e.PropertyId }); // Composite key

            // User ile 1-N ilişki
            entity.HasOne(e => e.User)
                  .WithMany()
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });
    }
}