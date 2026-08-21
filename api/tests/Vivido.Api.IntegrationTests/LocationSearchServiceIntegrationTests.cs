using System.Net;
using System.Text;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Npgsql;
using Testcontainers.PostgreSql;
using Vivido.Infrastructure.Data;
using Vivido.Infrastructure.Services;

namespace Vivido.Api.IntegrationTests;

public class LocationSearchServiceIntegrationTests
{
    [Fact]
    [Trait("Category", "Integration")]
    public async Task MahalleAdresVeKonumAramasiCalisir()
    {
        await using var postgis = new PostgreSqlBuilder("postgis/postgis:16-3.4")
            .WithDatabase("vivido_location_test")
            .WithUsername("vivido")
            .WithPassword("R105-test-password")
            .Build();
        await postgis.StartAsync();

        await using (var connection = new NpgsqlConnection(postgis.GetConnectionString()))
        {
            await connection.OpenAsync();
            await using var command = connection.CreateCommand();
            command.CommandText = """
                CREATE EXTENSION IF NOT EXISTS postgis;
                CREATE TABLE neighborhoods (
                    id bigserial PRIMARY KEY,
                    name text NOT NULL,
                    geom geometry(MultiPolygon, 4326) NOT NULL,
                    rent_index numeric(5,3) NOT NULL DEFAULT 1.000,
                    data_version text NOT NULL
                );
                INSERT INTO neighborhoods (name, geom, data_version)
                VALUES (
                    'Kavaklıdere',
                    ST_Multi(ST_GeomFromText(
                        'POLYGON((32.85 39.90, 32.87 39.90, 32.87 39.92, 32.85 39.92, 32.85 39.90))',
                        4326)),
                    'test-v1'
                );
                """;
            await command.ExecuteNonQueryAsync();
        }

        var options = new DbContextOptionsBuilder<VividoDbContext>()
            .UseNpgsql(postgis.GetConnectionString(), npgsql => npgsql.UseNetTopologySuite())
            .UseSnakeCaseNamingConvention()
            .Options;
        await using var context = new VividoDbContext(options);
        using var cache = new MemoryCache(new MemoryCacheOptions());
        var geocoderHandler = new StubGeocoderHandler();
        using var httpClient = new HttpClient(geocoderHandler)
        {
            BaseAddress = new Uri("https://example.test/"),
        };
        var service = new LocationSearchService(context, httpClient, cache);

        var byName = await service.SearchAsync("Kavaklidere", 5);

        geocoderHandler.RequestCount.Should().Be(0, "yerel sonuçlar dış servise gitmemelidir");

        var byAddress = await service.SearchAsync("Atatürk Bulvarı 10", 5);
        var cachedAddress = await service.SearchAsync("Atatürk Bulvarı 10", 5);

        byName.Items.Should().ContainSingle();
        byName.Items[0].Kind.Should().Be("neighborhood");
        byName.Items[0].Neighborhood.Should().Be("Kavaklıdere");
        byName.Items[0].Bounds.Should().NotBeNull();
        byAddress.Items.Should().ContainSingle();
        byAddress.Items[0].Kind.Should().Be("address");
        byAddress.Items[0].Source.Should().Be("nominatim");
        cachedAddress.Should().BeEquivalentTo(byAddress);
        geocoderHandler.RequestCount.Should().Be(1, "aynı adres sorgusu cache'den dönmelidir");
        geocoderHandler.LastRequestUri.Should().Contain("bounded=1");
        geocoderHandler.LastRequestUri.Should().Contain("countrycodes=tr");
    }

    private sealed class StubGeocoderHandler : HttpMessageHandler
    {
        public int RequestCount { get; private set; }
        public string? LastRequestUri { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            RequestCount++;
            LastRequestUri = request.RequestUri?.ToString();

            const string responseBody = """
                [{
                  "place_id": 123,
                  "osm_type": "way",
                  "osm_id": 456,
                  "lat": "39.9200",
                  "lon": "32.8550",
                  "display_name": "10, Atatürk Bulvarı, Kızılay, Çankaya, Ankara, Türkiye",
                  "type": "house",
                  "addresstype": "house",
                  "boundingbox": ["39.9199", "39.9201", "32.8549", "32.8551"],
                  "address": { "road": "Atatürk Bulvarı", "suburb": "Kızılay" }
                }]
                """;
            HttpResponseMessage response = new(HttpStatusCode.OK)
            {
                Content = new StringContent(responseBody, Encoding.UTF8, "application/json"),
            };
            return Task.FromResult(response);
        }
    }
}
