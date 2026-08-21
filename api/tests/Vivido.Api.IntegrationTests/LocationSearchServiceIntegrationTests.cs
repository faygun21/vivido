using System.Net;
using System.Text;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;
using Testcontainers.PostgreSql;
using Vivido.Application.dtos.location;
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
        var photonHandler = new StubGeocoderHandler(
            """{ "error": "temporary unavailable" }""",
            HttpStatusCode.ServiceUnavailable);
        var nominatimHandler = new StubGeocoderHandler("""
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
            """);
        using var photonClient = new HttpClient(photonHandler)
        {
            BaseAddress = new Uri("https://photon.example.test/"),
        };
        using var nominatimClient = new HttpClient(nominatimHandler)
        {
            BaseAddress = new Uri("https://nominatim.example.test/"),
        };
        IGeocodingProvider[] providers =
        [
            new PhotonGeocodingProvider(photonClient, cache),
            new NominatimGeocodingProvider(nominatimClient, cache),
        ];
        var service = new LocationSearchService(
            context,
            providers,
            NullLogger<LocationSearchService>.Instance);

        var byName = await service.SearchAsync("Kavaklidere", 5);

        photonHandler.RequestCount.Should().Be(0, "yerel sonuçlar dış servise gitmemelidir");
        nominatimHandler.RequestCount.Should().Be(0, "yerel sonuçlar dış servise gitmemelidir");

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
        photonHandler.RequestCount.Should().Be(2, "Photon hatasında Nominatim zinciri yine çalışmalıdır");
        nominatimHandler.RequestCount.Should().Be(1, "Nominatim sonucu cache'den dönmelidir");
        photonHandler.LastRequestUri.Should().Contain("bbox=");
        photonHandler.LastRequestUri.Should().Contain("countrycode=TR");
        nominatimHandler.LastRequestUri.Should().Contain("bounded=1");
        nominatimHandler.LastRequestUri.Should().Contain("countrycodes=tr");
    }

    [Fact]
    public async Task PhotonGeoJsonSonucunuOrtakSozlesmeyeDonusturur()
    {
        var handler = new StubGeocoderHandler("""
            {
              "type": "FeatureCollection",
              "features": [{
                "type": "Feature",
                "geometry": { "type": "Point", "coordinates": [32.805, 39.895] },
                "properties": {
                  "name": "1602. Sokak",
                  "district": "Çankaya",
                  "city": "Ankara",
                  "country": "Türkiye",
                  "osm_key": "highway",
                  "osm_value": "residential",
                  "osm_type": "W",
                  "osm_id": 1602,
                  "extent": [32.804, 39.896, 32.806, 39.894]
                }
              }]
            }
            """);
        using var cache = new MemoryCache(new MemoryCacheOptions());
        using var httpClient = new HttpClient(handler)
        {
            BaseAddress = new Uri("https://photon.example.test/"),
        };
        var provider = new PhotonGeocodingProvider(httpClient, cache);

        var results = await provider.SearchAsync("1602. sokak", 5);

        results.Should().ContainSingle();
        results[0].Source.Should().Be("photon");
        results[0].Kind.Should().Be("address");
        results[0].Label.Should().Contain("1602. Sokak");
        results[0].Bounds.Should().NotBeNull();
        handler.LastRequestUri.Should().NotContain("lang=");
    }

    private sealed class StubGeocoderHandler : HttpMessageHandler
    {
        private readonly string _responseBody;
        private readonly HttpStatusCode _statusCode;

        public StubGeocoderHandler(
            string responseBody,
            HttpStatusCode statusCode = HttpStatusCode.OK)
        {
            _responseBody = responseBody;
            _statusCode = statusCode;
        }

        public int RequestCount { get; private set; }
        public string? LastRequestUri { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            RequestCount++;
            LastRequestUri = request.RequestUri?.ToString();

            HttpResponseMessage response = new(_statusCode)
            {
                Content = new StringContent(_responseBody, Encoding.UTF8, "application/json"),
            };
            return Task.FromResult(response);
        }
    }
}
