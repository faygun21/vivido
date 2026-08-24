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
    public DbSet<Neighborhood> Neighborhoods { get; set; }
    public DbSet<FavoriteProperty> FavoriteProperties { get; set; }
    public DbSet<Route> Routes { get; set; }
    public DbSet<RouteStop> RouteStops { get; set; }
    public DbSet<PoiCategory> PoiCategories { get; set; } = null!;
    public DbSet<PropertyPoiAccess> PropertyPoiAccesses { get; set; } = null!;
    public DbSet<ScoreCache> ScoreCaches { get; set; } = null!;

    /// <summary>E-posta doğrulama + şifre sıfırlama kodları (K-09).</summary>
    public DbSet<AuthCode> AuthCodes { get; set; } = null!;
    public DbSet<Property> Properties { get; set; } = null!;
    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // ScoreCache için bileşik anahtar (Composite Key) tanımı
        builder.Entity<ScoreCache>()
            .HasKey(sc => new { sc.PropertyId, sc.ProfileId, sc.ScoringVersion });

        // PropertyPoiAccess için bileşik anahtar tanımı (Testin patlama sebebini çözen eksik parça)
        builder.Entity<PropertyPoiAccess>(entity =>
        {
            entity.ToTable("property_poi_access");
            entity.HasKey(e => new { e.PropertyId, e.CategoryCode });
        });

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

        builder.Entity<AuthCode>(entity =>
        {
            entity.ToTable("auth_codes");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");

            entity.HasOne(e => e.User)
                  .WithMany()
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => new { e.UserId, e.Purpose, e.CreatedAt });
        });

        builder.Entity<Persona>(entity =>
        {
            entity.ToTable("personas");
            entity.HasKey(e => e.Code);
            entity.Property(e => e.Code).HasColumnName("code");
        });

        // Persona yaşam kriterleri ve başlangıç önem seviyeleri
        builder.Entity<PersonaCategoryWeight>(entity =>
        {
            entity.ToTable("persona_category_weights");
            
            entity.HasKey(e => new { e.PersonaCode, e.CategoryCode });
            
            entity.Property(e => e.PersonaCode).HasColumnName("persona_code");
            entity.Property(e => e.CategoryCode).HasColumnName("category_code");
            entity.Property(e => e.Weight).HasColumnName("weight").HasColumnType("numeric(4,3)");

            entity.HasOne(e => e.Persona)
                  .WithMany()
                  .HasForeignKey(e => e.PersonaCode)
                  .HasPrincipalKey(p => p.Code);
        });

        builder.Entity<UserProfile>(entity =>
        {
            entity.ToTable("user_profiles");
            entity.HasKey(e => e.Id);

            entity.HasOne(e => e.Persona)
                  .WithMany()
                  .HasForeignKey(e => e.PersonaCode)
                  .HasPrincipalKey(p => p.Code);
        });

        // Kullanıcının yaşam kriterleri için kişisel önem sırası
        builder.Entity<UserProfileCategoryOrder>(entity =>
        {
            entity.ToTable("user_profile_category_order");
            entity.HasKey(e => new { e.ProfileId, e.CategoryCode });
            
            entity.Property(e => e.ProfileId).HasColumnName("profile_id");
            entity.Property(e => e.CategoryCode).HasColumnName("category_code");
            entity.Property(e => e.Priority).HasColumnName("priority");

            entity.HasOne(e => e.Profile)
                  .WithMany()
                  .HasForeignKey(e => e.ProfileId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => new { e.ProfileId, e.Priority }).IsUnique();
        });

        builder.Entity<Anchor>(entity =>
        {
            entity.ToTable("anchors");
            entity.HasKey(e => e.Id);
            
            entity.HasOne(e => e.Profile)
                  .WithMany(p => p.Anchors)
                  .HasForeignKey(e => e.ProfileId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.Property(e => e.Geom).HasColumnType("geometry (Point, 4326)");
        });

        builder.Entity<Neighborhood>(entity =>
        {
            entity.ToTable("neighborhoods");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Geom).HasColumnType("geometry (MultiPolygon, 4326)");
        });

        builder.Entity<FavoriteProperty>(entity =>
        {
            entity.ToTable("favorite_properties");
            entity.HasKey(e => new { e.UserId, e.PropertyId });
            
            entity.HasOne(e => e.User)
                  .WithMany()
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
                  
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");
        });

        builder.Entity<Route>(entity =>
        {
            entity.ToTable("routes");
            entity.HasKey(e => e.Id);

            entity.HasOne(e => e.User)
                  .WithMany()
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.Property(e => e.StartGeom).HasColumnType("geometry(Point, 4326)");
            entity.Property(e => e.Geometry).HasColumnType("geometry(LineString, 4326)");
            entity.Property(e => e.Steps).HasColumnType("jsonb");
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");
        });

        builder.Entity<RouteStop>(entity =>
        {
            entity.ToTable("route_stops");
            entity.HasKey(e => new { e.RouteId, e.Seq });
            entity.HasIndex(e => new { e.RouteId, e.PropertyId }).IsUnique();

            entity.HasOne(e => e.Route)
                  .WithMany(r => r.Stops)
                  .HasForeignKey(e => e.RouteId)
                  .OnDelete(DeleteBehavior.Cascade);
        });
    }
}