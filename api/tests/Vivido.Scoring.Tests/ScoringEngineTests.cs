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
        // zayıf halka cezasına dahil, skor ağırlıklı ortalamadan düşmeli.
        // Ceza artık cat2'nin ağırlığına (0.1) göre de ölçekleniyor:
        // severity=0.1/0.25=0.4 → effectiveFloor=1-0.5*0.4=0.8 →
        // penalty=0.8+(1-0.8)*(0/100)=0.8. 90.0*0.8=72.0.
        var score = ScoringEngine.CalculateScore(
        [
            Category(duration: 0, weight: 0.9),                  // cat1: mükemmel
            Category(duration: TCutoff + 10, weight: 0.1),        // cat2: berbat, orta önemli
        ]);

        score.Should().BeApproximately(72.0, 0.0001);
    }

    [Fact]
    public void OnemliZayifHalka_AzOnemliZayifHalkadanDahaSertCezalandirir()
    {
        // Aynı derecede kötü (score=0) iki senaryo: birinde zayıf halka
        // kullanıcının EN önemli saydığı kategori (ağırlık 0.25, tam ceza
        // referansında), diğerinde zar zor eşiği geçen bir kategori
        // (ağırlık 0.05). Öncesinde ikisi de AYNI cezayı alıyordu — artık
        // önemli olan çok daha sert cezalanıyor.
        var onemliZayifHalka = ScoringEngine.CalculateScore(
        [
            Category(duration: 0, weight: 0.75),                 // mükemmel, baskın
            Category(duration: TCutoff + 10, weight: 0.25),       // berbat, ÇOK önemli
        ]);

        var onemsizZayifHalka = ScoringEngine.CalculateScore(
        [
            Category(duration: 0, weight: 0.95),                 // mükemmel, baskın
            Category(duration: TCutoff + 10, weight: 0.05),       // berbat, zar zor önemli
        ]);

        // onemli: ortalama 75.0, severity=1 (tavanda) → floor=0.5 → 75*0.5=37.5
        onemliZayifHalka.Should().BeApproximately(37.5, 0.0001);
        // onemsiz: ortalama 95.0, severity=0.2 → floor=0.9 → 95*0.9=85.5
        onemsizZayifHalka.Should().BeApproximately(85.5, 0.0001);
        onemliZayifHalka.Should().BeLessThan(onemsizZayifHalka);
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
        // min_poi_count'un 2 katı POI varsa bonus +1.5 puan (1.5 * (2-1)).
        // 92 (t_ideal'deki temel skor) + 1.5 = 93.5, sonra zayıf halka
        // cezası (worst=93.5 → penalty=0.9675): 93.5*0.9675=90.46125.
        var score = ScoringEngine.CalculateScore(
            [Category(duration: TIdeal, poiCount: 10, minPoiCount: 5)]);

        score.Should().BeApproximately(90.46125, 0.0001);
    }

    [Fact]
    public void DusukYogunluk_SkoruHafifceAzaltir()
    {
        // Hiç POI yoksa (0/5) bonus -1.5 puan (1.5 * (0-1)). 92-1.5=90.5,
        // ceza (worst=90.5 → penalty=0.9525): 90.5*0.9525=86.20125.
        var score = ScoringEngine.CalculateScore(
            [Category(duration: TIdeal, poiCount: 0, minPoiCount: 5)]);

        score.Should().BeApproximately(86.20125, 0.0001);
    }

    [Fact]
    public void AsiriYogunluk_BonusUstSiniriGecmiyor()
    {
        // min_poi_count'un 100 katı POI olsa bile bonus +3 puanı geçemez —
        // duration=0 (decay=100) durumunda 100'ün üstüne çıkmaya çalışsa da
        // clamp 100'de tutmalı.
        var score = ScoringEngine.CalculateScore(
            [Category(duration: 0, poiCount: 500, minPoiCount: 5)]);

        score.Should().Be(100.0);
    }

    [Fact]
    public void YuksekYogunluk_TavaniArtikDelemiyor()
    {
        // Yol A'nın kendisiyle çözdüğü sorun: eskiden ×1.10 çarpanı,
        // t_ideal'e yakın (ama tam basmayan) bir kategoriyi kolayca 100'e
        // geri kırpıyordu (96 * 1.10 = 105.6 → 100), yoğunluk sinyali Yol
        // A'nın tavanını arka kapıdan deliyordu. Artık +3 puan sabit
        // bonusla bile 92'den 100'e çıkamıyor.
        var score = ScoringEngine.CalculateScore(
            [Category(duration: TIdeal, weight: 1.0, poiCount: 1000, minPoiCount: 5)]);

        // decay(t_ideal)=92, +3 (üst sınır) = 95, tek kategori olduğu için
        // zayıf halka cezası da worst=95 → penalty=0.975: 95*0.975=92.625.
        score.Should().BeApproximately(92.625, 0.0001);
        score.Should().BeLessThan(96.0);
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
