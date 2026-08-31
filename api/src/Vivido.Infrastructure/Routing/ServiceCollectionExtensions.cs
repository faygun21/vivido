using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Vivido.Infrastructure.Routing;

public static class ServiceCollectionExtensions
{
    /// <summary>
    /// OSRM routing istemcisini kaydeder.
    ///
    /// Yapılandırma önceliği: ortam değişkeni (`Routing__CarUrl`) > appsettings
    /// (`Routing:CarUrl`) > kod içi varsayılan. Konteyner (full profil) ortam
    /// değişkeniyle `osrm-car:5000` / `osrm-foot:5000` verir; host geliştirmesi
    /// `localhost:5002` / `localhost:5001` varsayılanını kullanır.
    /// </summary>
    public static IServiceCollection AddOsrmRouting(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var options = new OsrmOptions
        {
            CarUrl = configuration["Routing:CarUrl"] ?? "http://localhost:5102",
            FootUrl = configuration["Routing:FootUrl"] ?? "http://localhost:5101",
            MaxTableSize = ParseInt(configuration["Routing:MaxTableSize"], 200),
            TimeoutSeconds = ParseInt(configuration["Routing:TimeoutSeconds"], 30),
        };

        services.AddSingleton(options);
        services.AddHttpClient<OsrmClient>(client =>
        {
            client.Timeout = TimeSpan.FromSeconds(options.TimeoutSeconds);
        });

        return services;
    }

    private static int ParseInt(string? raw, int fallback) =>
        int.TryParse(raw, out var value) ? value : fallback;
}
