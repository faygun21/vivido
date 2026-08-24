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
    // Formül veya eşikler değiştiğinde bu versiyonu güncelleyeceğiz (Örn: "v1.1")
    private const string CurrentScoringVersion = "v1.0"; 

    public PropertyScoringService(VividoDbContext context)
    {
        _context = context;
    }

    public async Task<double> ScorePropertyAsync(long propertyId, Guid profileId)
    {
        // 1. Önce Cache'e bak! Eğer bu versiyonda zaten hesaplanmışsa direkt onu dön.
        var cachedScore = await _context.ScoreCaches
            .AsNoTracking()
            .FirstOrDefaultAsync(sc => 
                sc.PropertyId == propertyId && 
                sc.ProfileId == profileId && 
                sc.ScoringVersion == CurrentScoringVersion);

        if (cachedScore is not null)
        {
            return (double)cachedScore.Score;
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

        var categoryScores = new List<(double score, double weight)>();
        var breakdownList = new List<object>();

        foreach (var access in accesses)
        {
            if (!weights.TryGetValue(access.CategoryCode, out var weight) || weight <= 0) continue;
            if (!categories.TryGetValue(access.CategoryCode, out var cat)) continue;

            // Her bir alt kategori için skoru hesapla
            double catScore = ScoringEngine.CalculateCategoryScore(
                (double)access.DurationMin,
                (double)cat.TIdealMin,
                (double)cat.THalfMin,
                (double)cat.TCutoffMin
            );

            categoryScores.Add((catScore, weight));

            // JSON olarak veritabanına kaydetmek için detayları topla
            breakdownList.Add(new {
                CategoryCode = access.CategoryCode,
                Duration = access.DurationMin,
                Weight = weight,
                CategoryScore = catScore
            });
        }

        // 3. Ağırlıklı genel ortalamayı hesapla
        var calculatedScore = ScoringEngine.CalculateWeightedScore(categoryScores);

        // 4. Sonucu veritabanına (Cache'e) kaydet
        var newCache = new ScoreCache
        {
            PropertyId = propertyId,
            ProfileId = profileId,
            ScoringVersion = CurrentScoringVersion,
            Score = calculatedScore,
            Breakdown = JsonSerializer.Serialize(breakdownList),
            CreatedAt = DateTime.UtcNow
        };

        _context.ScoreCaches.Add(newCache);
        await _context.SaveChangesAsync();

        return calculatedScore;
    }
}