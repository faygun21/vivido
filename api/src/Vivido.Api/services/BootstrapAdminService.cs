using Vivido.Domain.Entities;
using Vivido.Infrastructure.Data;

namespace Vivido.Api.Services;

public class BootstrapAdminService
{
    private readonly VividoDbContext _db;
    private readonly IConfiguration _config;
    private readonly ILogger<BootstrapAdminService> _logger;

    public BootstrapAdminService(
        VividoDbContext db,
        IConfiguration config,
        ILogger<BootstrapAdminService> logger)
    {
        _db = db;
        _config = config;
        _logger = logger;
    }

    public async Task EnsureBootstrapAdminAsync(
        User user,
        CancellationToken ct)
    {
        var bootstrapEmail =
            _config["BootstrapAdmin:Email"]?.Trim();

        if (string.IsNullOrWhiteSpace(bootstrapEmail))
            return;

        if (!string.Equals(
                user.Email,
                bootstrapEmail,
                StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        if (user.IsAdmin)
            return;

        user.IsAdmin = true;

        await _db.SaveChangesAsync(ct);

        _logger.LogInformation(
            "Bootstrap admin yetkisi verildi: {UserId}",
            user.Id
        );
    }
}