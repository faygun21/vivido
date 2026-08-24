using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Vivido.Infrastructure.Data;
using Vivido.Domain.Entities;

namespace Vivido.Api.IntegrationTests;

public class PropertyScoreIntegrationTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public PropertyScoreIntegrationTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Scenario1_HappyPath_calculates_and_caches()
    {
        var profileId = Guid.Parse("550e8400-e29b-41d4-a716-446655440000");
        var factory2 = _factory.WithWebHostBuilder(builder =>
        {
            builder.UseSetting("environment", "IntegrationTests");
            builder.ConfigureServices(services =>
            {
                // Replace DB with InMemory
                var descriptors = services.Where(d => d.ServiceType == typeof(DbContextOptions<VividoDbContext>) || d.ServiceType == typeof(VividoDbContext)).ToList();
                foreach (var d in descriptors) services.Remove(d);

                services.AddDbContext<VividoDbContext>(options =>
                {
                    options.UseInMemoryDatabase("test_db_scenario1");
                });
            });
        });

        using var client = factory2.CreateClient();
        // seed data after host built
        using (var scope = factory2.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<VividoDbContext>();

            // Seed profile + persona
            db.Personas.Add(new Persona { Code = "ogrenci", DisplayNameTr = "Öğrenci", DescriptionTr = "" });
            db.UserProfiles.Add(new UserProfile { Id = profileId, UserId = Guid.NewGuid(), PersonaCode = "ogrenci" });

            // Seed poi categories
            db.PoiCategories.Add(new PoiCategory { Code = "kampus", TIdealMin = 10, THalfMin = 30, TCutoffMin = 60, Active = true });
            db.PoiCategories.Add(new PoiCategory { Code = "metro", TIdealMin = 5, THalfMin = 15, TCutoffMin = 30, Active = true });

            // Seed persona weights
            db.PersonaCategoryWeights.Add(new PersonaCategoryWeight { PersonaCode = "ogrenci", CategoryCode = "kampus", Weight = 1.0 });
            db.PersonaCategoryWeights.Add(new PersonaCategoryWeight { PersonaCode = "ogrenci", CategoryCode = "metro", Weight = 0.5 });

            // Seed property poi accesses for property 1001
            db.PropertyPoiAccesses.Add(new PropertyPoiAccess { PropertyId = 1001, CategoryCode = "kampus", DurationMin = 30 });
            db.PropertyPoiAccesses.Add(new PropertyPoiAccess { PropertyId = 1001, CategoryCode = "metro", DurationMin = 5 });

            db.SaveChanges();
        }

        // First request (should compute and insert cache)
        var resp1 = await client.GetAsync($"/api/properties/1001/score?profileId={profileId}");
        resp1.StatusCode.Should().Be(HttpStatusCode.OK);
        resp1.Headers.TryGetValues("X-Cache", out var header1).Should().BeTrue();
        header1!.First().Should().Be("MISS");

        var body1 = await resp1.Content.ReadFromJsonAsync<JsonElement>();
        var score1 = body1.GetProperty("score").GetDouble();
        Math.Round(score1, 2).Should().BeApproximately(66.67, 0.01);

        // Second request (should be cache hit)
        var resp2 = await client.GetAsync($"/api/properties/1001/score?profileId={profileId}");
        resp2.StatusCode.Should().Be(HttpStatusCode.OK);
        resp2.Headers.TryGetValues("X-Cache", out var header2).Should().BeTrue();
        header2!.First().Should().Be("HIT");

        var body2 = await resp2.Content.ReadFromJsonAsync<JsonElement>();
        var score2 = body2.GetProperty("score").GetDouble();
        Math.Round(score2, 2).Should().BeApproximately(66.67, 0.01);

    }

    [Fact]
    public async Task Scenario4_CutoffExceeded_category_score_zero_and_overall_recomputed()
    {
        var profileId = Guid.Parse("550e8400-e29b-41d4-a716-446655440000");
        var factory2 = _factory.WithWebHostBuilder(builder =>
        {
            builder.UseSetting("environment", "IntegrationTests");
            builder.ConfigureServices(services =>
            {
                var descriptors = services.Where(d => d.ServiceType == typeof(DbContextOptions<VividoDbContext>) || d.ServiceType == typeof(VividoDbContext)).ToList();
                foreach (var d in descriptors) services.Remove(d);
                services.AddDbContext<VividoDbContext>(options => options.UseInMemoryDatabase("test_db_scenario4"));
            });
        });

        using var client = factory2.CreateClient();
        using (var scope = factory2.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<VividoDbContext>();

            db.Personas.Add(new Persona { Code = "ogrenci", DisplayNameTr = "Öğrenci", DescriptionTr = "" });
            db.UserProfiles.Add(new UserProfile { Id = profileId, UserId = Guid.NewGuid(), PersonaCode = "ogrenci" });

            db.PoiCategories.Add(new PoiCategory { Code = "kampus", TIdealMin = 10, THalfMin = 30, TCutoffMin = 60, Active = true });
            db.PoiCategories.Add(new PoiCategory { Code = "metro", TIdealMin = 5, THalfMin = 15, TCutoffMin = 30, Active = true });

            db.PersonaCategoryWeights.Add(new PersonaCategoryWeight { PersonaCode = "ogrenci", CategoryCode = "kampus", Weight = 1.0 });
            db.PersonaCategoryWeights.Add(new PersonaCategoryWeight { PersonaCode = "ogrenci", CategoryCode = "metro", Weight = 0.5 });

            // kampus duration exceed cutoff
            db.PropertyPoiAccesses.Add(new PropertyPoiAccess { PropertyId = 2002, CategoryCode = "kampus", DurationMin = 65 });
            db.PropertyPoiAccesses.Add(new PropertyPoiAccess { PropertyId = 2002, CategoryCode = "metro", DurationMin = 5 });

            db.SaveChanges();
        }
        var resp = await client.GetAsync($"/api/properties/2002/score?profileId={profileId}");
        resp.StatusCode.Should().Be(HttpStatusCode.OK);
        resp.Headers.TryGetValues("X-Cache", out var header).Should().BeTrue();
        header!.First().Should().Be("MISS");

        var body = await resp.Content.ReadFromJsonAsync<JsonElement>();
        var score = body.GetProperty("score").GetDouble();
        // expect overall = ((0*1.0) + (100*0.5))/1.5 = 33.333 -> 33.33
        Math.Round(score, 2).Should().BeApproximately(33.33, 0.01);

    }

    [Fact]
    public async Task Scenario3_MissingProfile_returns_400_and_unknownProfile_returns_200_with_0()
    {
        var factory2 = _factory.WithWebHostBuilder(builder =>
        {
            builder.UseSetting("environment", "IntegrationTests");
            builder.ConfigureServices(services =>
            {
                var descriptors = services.Where(d => d.ServiceType == typeof(DbContextOptions<VividoDbContext>) || d.ServiceType == typeof(VividoDbContext)).ToList();
                foreach (var d in descriptors) services.Remove(d);
                services.AddDbContext<VividoDbContext>(options => options.UseInMemoryDatabase("test_db_scenario3"));
            });
        });

        using var client = factory2.CreateClient();
        // Missing profileId -> 400
        var respBad = await client.GetAsync($"/api/properties/1001/score");
        respBad.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        // Unknown profileId -> 200 with score 0.0
        var unknown = Guid.NewGuid();
        var resp = await client.GetAsync($"/api/properties/1001/score?profileId={unknown}");
        resp.StatusCode.Should().Be(HttpStatusCode.OK);
        var body = await resp.Content.ReadFromJsonAsync<JsonElement>();
        var score = body.GetProperty("score").GetDouble();
        score.Should().Be(0.0);
    }
}
