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
    public DbSet<Neighborhood> Neighborhoods { get; set; }
    public DbSet<FavoriteProperty> FavoriteProperties { get; set; }
    public DbSet<Route> Routes { get; set; }
    public DbSet<RouteStop> RouteStops { get; set; }

    /// <summary>E-posta doğrulama + şifre sıfırlama kodları (K-09).</summary>
    public DbSet<AuthCode> AuthCodes { get; set; } = null!;

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

        builder.Entity<AuthCode>(entity =>
        {
            // Tablo adı açıkça yazılıyor — 03-HAFTA-2-PLANI §6 BE-3 kuralı.
            // Naming convention çoğullaştırma yapmaz, DbSet adına güvenmek
            // sessizce `auth_code` üretebilir.
            entity.ToTable("auth_codes");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");

            entity.HasOne(e => e.User)
                  .WithMany()
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);

            // Doğrulama her zaman "bu kullanıcının bu amaçlı en son kodu"nu
            // arıyor; indeks db/schema/004 içindekiyle aynı.
            entity.HasIndex(e => new { e.UserId, e.Purpose, e.CreatedAt });
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
        builder.Entity<Neighborhood>(entity =>
        {
            entity.ToTable("neighborhoods");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Geom)
                  .HasColumnType("geometry (MultiPolygon, 4326)");
        });

        builder.Entity<FavoriteProperty>(entity =>
        {
            entity.ToTable("favorite_properties");

            // Composite Primary Key (user_id ve property_id birleşimi)
            entity.HasKey(e => new { e.UserId, e.PropertyId });

            // User ile ilişki
            entity.HasOne(e => e.User)
                  .WithMany()
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);

            // Tarih için varsayılan değer
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");
        });

        builder.Entity<Route>(entity =>
        {
            entity.ToTable("routes");
            entity.HasKey(e => e.Id);

            // User ile ilişki
            entity.HasOne(e => e.User)
                  .WithMany() // User tarafında liste tutmuyoruz
                  .HasForeignKey(e => e.UserId)
                  .OnDelete(DeleteBehavior.Cascade);

            // NetTopologySuite ve JSON tiplerinin PostGIS karşılıkları
            entity.Property(e => e.StartGeom)
                  .HasColumnType("geometry(Point, 4326)");

            entity.Property(e => e.Geometry)
                  .HasColumnType("geometry(LineString, 4326)");

            entity.Property(e => e.Steps)
                  .HasColumnType("jsonb"); // OSRM manevra adımları için

            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");
        });

        builder.Entity<RouteStop>(entity =>
        {
            entity.ToTable("route_stops");

            // Composite Primary Key (route_id ve seq birleşimi)
            entity.HasKey(e => new { e.RouteId, e.Seq });

            // Rota içindeki bir evin ikinci kez eklenmemesi için Unique kısıtlaması
            entity.HasIndex(e => new { e.RouteId, e.PropertyId }).IsUnique();

            // Route ile 1-N ilişki
            entity.HasOne(e => e.Route)
                  .WithMany(r => r.Stops)
                  .HasForeignKey(e => e.RouteId)
                  .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
