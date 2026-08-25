namespace Vivido.Api.services;

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Vivido.Infrastructure.Data; 
using Vivido.Domain.Entities;
using Vivido.Scoring;

public class PropertyScoringService
{
    private readonly VividoDbContext _context;
    // v1.1: yumuşak tavan (Yol A), zayıf halka cezası ve yoğunluk sinyali
    // eklendi — eski sürümle hesaplanmış skorlar artık geçersiz, versiyon
    // farkı sayesinde cache'ten okunmayıp otomatik yeniden hesaplanıyorlar.
    private const string CurrentScoringVersion = "v1.1";

    public PropertyScoringService(VividoDbContext context)
    {
        _context = context;
    }

    public async Task<double> ScorePropertyAsync(long propertyId, Guid profileId)
    {
        // 1. Önce Cache'e bak
        var cachedScore = await _context.ScoreCaches
            .AsNoTracking()
            .FirstOrDefaultAsync(sc => 
                sc.PropertyId == propertyId && 
                sc.ProfileId == profileId && 
                sc.ScoringVersion == CurrentScoringVersion);

        if (cachedScore is not null)
        {
            return (double)cachedScore.TotalScore;
        }

        // 2. Cache'de yoksa, profil ve ağırlıkları çek
        var profile = await _context.UserProfiles
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == profileId);

        if (profile is null) return 0.0;

        var weights = await _context.PersonaCategoryWeights
            .Where(w => w.PersonaCode == profile.PersonaCode)
            .AsNoTracking()
            .ToDictionaryAsync(w => w.CategoryCode, w => (double)w.Weight);

        var categories = await _context.PoiCategories
            .Where(c => c.Active)
            .AsNoTracking()
            .ToDictionaryAsync(c => c.Code, c => c);

        var accesses = await _context.PropertyPoiAccesses
            .Where(pa => pa.PropertyId == propertyId)
            .AsNoTracking()
            .ToListAsync();

        var scoringInputs = new List<ScoringEngine.CategoryInput>();
        var breakdownList = new List<object>();

        foreach (var access in accesses)
        {
            if (!weights.TryGetValue(access.CategoryCode, out var weight) || weight <= 0) continue;
            if (!categories.TryGetValue(access.CategoryCode, out var cat)) continue;

            scoringInputs.Add(new ScoringEngine.CategoryInput(
                DurationMinutes: (double)access.DurationMin,
                Weight: weight,
                TIdeal: (double)cat.TIdealMin,
                THalf: (double)cat.THalfMin,
                TCutoff: (double)cat.TCutoffMin,
                PoiCountInRadius: access.PoiCountInRadius,
                MinPoiCount: cat.MinPoiCount
            ));

            breakdownList.Add(new {
                CategoryCode = access.CategoryCode,
                Duration = (double)access.DurationMin,
                Weight = weight
            });
        }

        // 3. Senin orijinal hesaplama motorunu çağırıyoruz
        var calculatedScore = ScoringEngine.CalculateScore(scoringInputs);

        // 4. Sonucu Cache'e kaydet
        var newCache = new ScoreCache
        {
            PropertyId = propertyId,
            ProfileId = profileId,
            ScoringVersion = CurrentScoringVersion,
            TotalScore = (decimal)calculatedScore,
            Breakdown = JsonSerializer.Serialize(breakdownList),
            ComputedAt = DateTime.UtcNow
        };

        _context.ScoreCaches.Add(newCache);
        await _context.SaveChangesAsync();

        return calculatedScore;
    }

    /// <summary>
    /// Harita/liste görünümü için toplu skorlama.
    ///
    /// <see cref="ScorePropertyAsync"/> her konut için profili, persona
    /// ağırlıklarını ve kategori tanımlarını AYRI AYRI sorguluyordu — bunlar
    /// tüm konutlar için aynı olduğundan, yüzlerce eşleşen konutta bu tek
    /// başına yüzlerce gereksiz sorgu demekti. Burada profil/ağırlık/kategori
    /// TEK sefer, cache ve POI erişimi ise property id'leri için TEK toplu
    /// sorguyla çekilip bellekte gruplanıyor.
    /// </summary>
    public async Task<Dictionary<long, double>> ScorePropertiesAsync(IReadOnlyCollection<long> propertyIds, Guid profileId)
    {
        var result = new Dictionary<long, double>();
        if (propertyIds.Count == 0) return result;

        var cachedScores = await _context.ScoreCaches
            .AsNoTracking()
            .Where(sc => propertyIds.Contains(sc.PropertyId) &&
                         sc.ProfileId == profileId &&
                         sc.ScoringVersion == CurrentScoringVersion)
            .ToListAsync();

        foreach (var cached in cachedScores)
        {
            result[cached.PropertyId] = (double)cached.TotalScore;
        }

        var uncachedIds = propertyIds.Where(id => !result.ContainsKey(id)).ToList();
        if (uncachedIds.Count == 0) return result;

        var profile = await _context.UserProfiles
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == profileId);

        if (profile is null)
        {
            foreach (var id in uncachedIds) result[id] = 0.0;
            return result;
        }

        var weights = await _context.PersonaCategoryWeights
            .Where(w => w.PersonaCode == profile.PersonaCode)
            .AsNoTracking()
            .ToDictionaryAsync(w => w.CategoryCode, w => (double)w.Weight);

        var categories = await _context.PoiCategories
            .Where(c => c.Active)
            .AsNoTracking()
            .ToDictionaryAsync(c => c.Code, c => c);

        var accessesByProperty = await _context.PropertyPoiAccesses
            .Where(pa => uncachedIds.Contains(pa.PropertyId))
            .AsNoTracking()
            .ToListAsync();

        var accessLookup = accessesByProperty
            .GroupBy(a => a.PropertyId)
            .ToDictionary(g => g.Key, g => g.ToList());

        var newCaches = new List<ScoreCache>();

        foreach (var propertyId in uncachedIds)
        {
            var scoringInputs = new List<ScoringEngine.CategoryInput>();
            var breakdownList = new List<object>();

            if (accessLookup.TryGetValue(propertyId, out var accesses))
            {
                foreach (var access in accesses)
                {
                    if (!weights.TryGetValue(access.CategoryCode, out var weight) || weight <= 0) continue;
                    if (!categories.TryGetValue(access.CategoryCode, out var cat)) continue;

                    scoringInputs.Add(new ScoringEngine.CategoryInput(
                        DurationMinutes: (double)access.DurationMin,
                        Weight: weight,
                        TIdeal: (double)cat.TIdealMin,
                        THalf: (double)cat.THalfMin,
                        TCutoff: (double)cat.TCutoffMin,
                        PoiCountInRadius: access.PoiCountInRadius,
                        MinPoiCount: cat.MinPoiCount
                    ));

                    breakdownList.Add(new {
                        CategoryCode = access.CategoryCode,
                        Duration = (double)access.DurationMin,
                        Weight = weight
                    });
                }
            }

            var calculatedScore = ScoringEngine.CalculateScore(scoringInputs);
            result[propertyId] = calculatedScore;

            newCaches.Add(new ScoreCache
            {
                PropertyId = propertyId,
                ProfileId = profileId,
                ScoringVersion = CurrentScoringVersion,
                TotalScore = (decimal)calculatedScore,
                Breakdown = JsonSerializer.Serialize(breakdownList),
                ComputedAt = DateTime.UtcNow,
            });
        }

        _context.ScoreCaches.AddRange(newCaches);
        await _context.SaveChangesAsync();

        return result;
    }
}