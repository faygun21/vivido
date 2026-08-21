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

    // Persona için tanımlı yaşam kriterleri ve başlangıç ağırlıkları
    public DbSet<PersonaCategoryWeight> PersonaCategoryWeights { get; set; } = null!;

    // Kullanıcının kişisel kriter önem sırası
    public DbSet<UserProfileCategoryOrder> UserProfileCategoryOrders { get; set; } = null!;

    public DbSet<RefreshToken> RefreshTokens { get; set; } = null!;

    public DbSet<UserProfile> UserProfiles { get; set; }
    public DbSet<Anchor> Anchors { get; set; }

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<User>(entity =>
        {
            entity.ToTable("users");

            entity.Property(e => e.Email)
                  .HasColumnType("citext");

            entity.Property(e => e.CreatedAt)
                  .HasDefaultValueSql("now()");
        });

        builder.Entity<RefreshToken>(entity =>
        {
            entity.ToTable("refresh_tokens");

            entity.Property(e => e.CreatedAt)
                  .HasDefaultValueSql("now()");
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

            entity.Property(e => e.Code)
                  .HasColumnName("code");
        });

        // Persona yaşam kriterleri ve başlangıç önem seviyeleri
        builder.Entity<PersonaCategoryWeight>(entity =>
        {
            entity.ToTable("persona_category_weights");

            // Bu tabloda tek bir Id yok.
            // Bir kaydı persona + kategori ikilisi benzersiz yapıyor.
            entity.HasKey(e => new
            {
                e.PersonaCode,
                e.CategoryCode
            });

            entity.Property(e => e.PersonaCode)
                  .HasColumnName("persona_code");

            entity.Property(e => e.CategoryCode)
                  .HasColumnName("category_code");

            entity.Property(e => e.Weight)
                  .HasColumnName("weight")
                  .HasColumnType("numeric(4,3)");

            // Her ağırlık bir persona'ya aittir.
            entity.HasOne(e => e.Persona)
                  .WithMany()
                  .HasForeignKey(e => e.PersonaCode)
                  .HasPrincipalKey(p => p.Code);
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

        // Kullanıcının yaşam kriterleri için kişisel önem sırası
        builder.Entity<UserProfileCategoryOrder>(entity =>
        {
            entity.ToTable("user_profile_category_order");

            // Bir profil aynı kategoriyi yalnızca bir kez içerebilir.
            entity.HasKey(e => new
            {
                e.ProfileId,
                e.CategoryCode
            });

            entity.Property(e => e.ProfileId)
                  .HasColumnName("profile_id");

            entity.Property(e => e.CategoryCode)
                  .HasColumnName("category_code");

            entity.Property(e => e.Priority)
                  .HasColumnName("priority");

            // Her sıra kaydı bir kullanıcı profiline aittir.
            entity.HasOne(e => e.Profile)
                  .WithMany()
                  .HasForeignKey(e => e.ProfileId)
                  .OnDelete(DeleteBehavior.Cascade);

            // Aynı profil içinde iki kriter aynı sırada olamaz.
            entity.HasIndex(e => new
            {
                e.ProfileId,
                e.Priority
            })
            .IsUnique();
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