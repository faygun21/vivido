using FluentAssertions;
using Vivido.Scoring;

namespace Vivido.Scoring.Tests;

public class ScoringEngineTests
{
    // Ortak test eşikleri — küçük, yuvarlak sayılarla elle hesaplaması kolay.
    private const double TIdeal = 10.0;
    private const double THalf = 20.0;
    private const double TCutoff = 40.0;

    private static ScoringEngine.CategoryInput Category(
        double duration,
        double weight = 1.0,
        int? poiCount = null,
        int? minPoiCount = null) =>
        new(duration, weight, TIdeal, THalf, TCutoff, poiCount, minPoiCount);

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

        score.Should().BeApproximately(88.32, 0.0001);
    }

    [Fact]
    public void TIdealAltiIkiFarkliSure_ArtikAyniSkoruVermiyor()
    {
        // Eskiden t_ideal altındaki HER süre 100'dü — iki farklı ev aynı
        // skora yığılıyordu. Yol A sonrası ayrışmalı.
        var yakinEv = ScoringEngine.CalculateScore([Category(duration: 1)]);
        var uzakEv = ScoringEngine.CalculateScore([Category(duration: 8)]);

        yakinEv.Should().BeGreaterThan(uzakEv);
        yakinEv.Should().NotBe(100.0);
        uzakEv.Should().NotBe(100.0);
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

        // (100*1.0 + 0*0.02) / 1.02 = 98.0392...
        score.Should().BeApproximately(98.0392, 0.0001);
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
        score.Should().BeApproximately(45.0, 0.0001);
    }

    [Fact]
    public void YogunlukVerisiYokken_DavranisDegismiyor_GeriyeDonukUyumlu()
    {
        // PoiCountInRadius/MinPoiCount null (migration/ETL henüz çalışmamış
        // eski satırlar) → yoğunluk çarpanı devre dışı, saf Yol A + zayıf
        // halka sonucu.
        var score = ScoringEngine.CalculateScore([Category(duration: TIdeal, poiCount: null, minPoiCount: null)]);

        score.Should().BeApproximately(88.32, 0.0001);
    }

    [Fact]
    public void YuksekYogunluk_SkoruHafifceArtirir()
    {
        // min_poi_count'un 2 katı POI varsa çarpan 1.05 (0.05 * (2-1)).
        // 92 (t_ideal'deki temel skor) * 1.05 = 96.6, sonra zayıf halka
        // cezası (worst=96.6 → penalty=0.983): 96.6*0.983=94.9578.
        var score = ScoringEngine.CalculateScore(
            [Category(duration: TIdeal, poiCount: 10, minPoiCount: 5)]);

        score.Should().BeApproximately(94.9578, 0.0001);
    }

    [Fact]
    public void DusukYogunluk_SkoruHafifceAzaltir()
    {
        // Hiç POI yoksa (0/5) çarpan 0.95 (0.05 * (0-1)). 92*0.95=87.4,
        // ceza (worst=87.4 → penalty=0.937): 87.4*0.937=81.8938.
        var score = ScoringEngine.CalculateScore(
            [Category(duration: TIdeal, poiCount: 0, minPoiCount: 5)]);

        score.Should().BeApproximately(81.8938, 0.0001);
    }

    [Fact]
    public void AsiriYogunluk_CarpanUstSiniriGecmiyor()
    {
        // min_poi_count'un 100 katı POI olsa bile çarpan +%10'u geçemez —
        // duration=0 (decay=100) durumunda 100'ün üstüne çıkmaya çalışsa da
        // clamp 100'de tutmalı.
        var score = ScoringEngine.CalculateScore(
            [Category(duration: 0, poiCount: 500, minPoiCount: 5)]);

        score.Should().Be(100.0);
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
