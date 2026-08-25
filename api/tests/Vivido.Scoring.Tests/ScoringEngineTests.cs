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
    public void TamKonumda_HicPenaltiYokken_100Doner()
    {
        // duration=0 → decay=100, tek kategori olduğu için zayıf halka
        // cezası da worst=100 üzerinden penalty=1.0 verir.
        var score = ScoringEngine.CalculateScore([Category(duration: 0)]);

        score.Should().Be(100.0);
    }

    [Fact]
    public void TIdealSiniri_ArtikDuzTavanDegil_YuzdenAzSkorVerir()
    {
        // Yol A: t_ideal'e TAM basan bir süre artık 100 değil, tavan
        // yumuşatmasıyla (K=8) 92 kategori skoru, üstüne tek-kategori zayıf
        // halka cezası (worst=92 → penalty=0.96) biniyor: 92*0.96=88.32.
        var score = ScoringEngine.CalculateScore([Category(duration: TIdeal)]);

        score.Should().Be(88.32);
    }

    [Fact]
    public void TIdealAltiIkiFarkliSure_ArtikAyniSkoruVermiyor()
    {
        // Eskiden t_ideal altındaki HER süre 100'dü — iki farklı ev aynı
        // skora yığılıyordu. Yol A + zayıf halka cezası sonrası ayrışmalı.
        var yakinEv = ScoringEngine.CalculateScore([Category(duration: 1)]);
        var uzakEv = ScoringEngine.CalculateScore([Category(duration: 8)]);

        yakinEv.Should().Be(98.8);
        uzakEv.Should().Be(90.6);
        yakinEv.Should().BeGreaterThan(uzakEv);
    }

    [Fact]
    public void AgirligiEsikAltindaKotuKategori_CezaTetiklemezAmaOrtalamayiSeyreltir()
    {
        // cat1 mükemmel + yüksek ağırlıklı, cat2 çok kötü ama ağırlığı
        // eşiğin (0.05) altında — kullanıcı o kategoriyi önemsemiyor demek.
        // Ceza tetiklenmemeli (worst yalnızca cat1'den, yani 100), ama cat2
        // yine de ağırlıklı ortalamayı hafifçe seyreltmeli.
        var score = ScoringEngine.CalculateScore(
        [
            Category(duration: 0, weight: 1.0),                 // cat1: mükemmel
            Category(duration: TCutoff + 10, weight: 0.02),      // cat2: berbat ama önemsiz
        ]);

        // (100*1.0 + 0*0.02) / 1.02 = 98.0392... → 2 ondalık: 98.04
        score.Should().Be(98.04);
        score.Should().BeLessThan(100.0);
    }

    [Fact]
    public void AgirligiEsikUstundeKotuKategori_SkoruSertCekiyor()
    {
        // cat2 burada eşiğin (0.05) ÜSTÜNDE bir ağırlığa sahip — artık
        // zayıf halka cezasına dahil, skor ağırlıklı ortalamadan çok daha
        // fazla düşmeli.
        var score = ScoringEngine.CalculateScore(
        [
            Category(duration: 0, weight: 0.9),                  // cat1: mükemmel
            Category(duration: TCutoff + 10, weight: 0.1),        // cat2: berbat, önemli
        ]);

        // Ağırlıklı ortalama: 90.0 — ama ceza (worst=0 → penalty=0.5) yarıya indiriyor.
        score.Should().Be(45.0);
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
