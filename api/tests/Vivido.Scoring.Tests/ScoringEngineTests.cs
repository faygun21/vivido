using FluentAssertions;
using Vivido.Scoring;

namespace Vivido.Scoring.Tests;

public class ScoringEngineTests
{
    // Ortak test eşikleri — küçük, yuvarlak sayılarla elle hesaplaması kolay.
    private const double TIdeal = 10.0;
    private const double THalf = 20.0;
    private const double TCutoff = 40.0;

    private static ScoringEngine.CategoryInput Category(double duration, double weight = 1.0) =>
        new(duration, weight, TIdeal, THalf, TCutoff);

    [Fact]
    public void TamKonumda_100Doner()
    {
        var score = ScoringEngine.CalculateScore([Category(duration: 0)]);

        score.Should().Be(100.0);
    }

    [Fact]
    public void TIdealSiniri_ArtikDuzTavanDegil_YuzdenAzSkorVerir()
    {
        // Yol A: t_ideal'e TAM basan bir süre artık 100 değil — tavan
        // yumuşatmasıyla (K=8) 92.
        var score = ScoringEngine.CalculateScore([Category(duration: TIdeal)]);

        score.Should().Be(92.0);
    }

    [Fact]
    public void TIdealAltiIkiFarkliSure_ArtikAyniSkoruVermiyor()
    {
        // Eskiden t_ideal altındaki HER süre 100'dü — iki farklı ev aynı
        // skora yığılıyordu. Yol A sonrası ayrışmalı.
        var yakinEv = ScoringEngine.CalculateScore([Category(duration: 1)]);
        var uzakEv = ScoringEngine.CalculateScore([Category(duration: 8)]);

        yakinEv.Should().Be(99.2);
        uzakEv.Should().Be(93.6);
        yakinEv.Should().BeGreaterThan(uzakEv);
    }

    [Fact]
    public void AgirligiSifirOlanKategori_HicHesabaKatilmiyor()
    {
        var score = ScoringEngine.CalculateScore(
        [
            Category(duration: 0, weight: 1.0),
            Category(duration: TCutoff + 10, weight: 0.0), // örn. persona bu kategoriyi hiç önemsemiyor
        ]);

        score.Should().Be(100.0);
    }

    [Fact]
    public void HicAgirlikliKategoriYokken_SifirDoner()
    {
        var score = ScoringEngine.CalculateScore(
        [
            Category(duration: 0, weight: 0.0),
        ]);

        score.Should().Be(0.0);
    }

    [Fact]
    public void CutoffUstundeSure_SifirVerir()
    {
        var score = ScoringEngine.CalculateScore([Category(duration: TCutoff + 1)]);

        score.Should().Be(0.0);
    }
}
