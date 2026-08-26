namespace Vivido.Api.services;

using System.Collections.Generic;
using System.Linq;

/// <summary>
/// Kullanıcının UserProfileCategoryOrder ile özelleştirdiği kriter sırasını
/// ağırlıklara çevirir.
///
/// <see cref="PropertyScoringService"/> (liste/harita skoru) ve
/// <see cref="PropertyScoreBreakdownService"/> (detay panelindeki gerekçe
/// satırları) İKİSİ DE bunu kullanmak zorunda — aksi halde skor ile detay
/// panelindeki sıralama birbirinden sessizce ayrışır (kullanıcı listede bir
/// skora göre sıralanmış evler görür, detay panelinde farklı bir gerekçe
/// sırası).
/// </summary>
public static class CategoryWeightResolver
{
    public static Dictionary<string, double> Resolve(
        Dictionary<string, double> personaWeights,
        List<string> customOrderCategoryCodes)
    {
        if (customOrderCategoryCodes.Count == 0) return personaWeights;

        var defaultOrder = personaWeights
            .OrderByDescending(kv => kv.Value)
            .Select(kv => kv.Key)
            .ToList();

        // Kullanıcının sırası persona'nın kendi varsayılan sırasıyla birebir
        // aynıysa gerçek bir özelleştirme yok demektir — örn. kayıt
        // sihirbazındaki "Tercihler" adımından hiç sürüklemeden geçmiş
        // olabilir, ama ekran yine de o anki (varsayılan) sırayı kaydeder.
        // Bu durumda persona'nın TASARLANMIŞ ağırlıklarını aynen kullanmaya
        // devam ediyoruz; öğrenci persona'sını seçip hiçbir şeyi
        // değiştirmeyen biri hâlâ öğrenci katsayılarını almalı.
        if (customOrderCategoryCodes.SequenceEqual(defaultOrder)) return personaWeights;

        // Gerçek bir özelleştirme var. Persona'nın ham ağırlık DEĞERLERİNİ
        // (ör. 0.0) pozisyona göre yeniden dağıtmak yerine, sıraya göre
        // DÜZGÜN bir eğri üretiyoruz: n, n-1, ..., 1 — toplamlarına
        // bölünmüş (8 kriter için 8+7+…+1=36 üzerinden). Bu iki sorunu
        // birden çözüyor:
        //   1. Eskiden en alta sürüklenen kategori HER NEYSE, persona'nın
        //      en düşük değerini (bazen tam 0.0) alıyor, yani skordan
        //      TAMAMEN dışlanıyordu — "en az öncelikli" demek isteyen
        //      kullanıcı için bu çok sertti. Yeni eğri hiçbir zaman tam
        //      sıfıra inmiyor.
        //   2. Toplam her zaman TAM 1.0 ediyor (persona ağırlıklarıyla aynı
        //      sözleşme) — ScoringEngine ağırlıkların normalize edilmiş
        //      hâlini kullandığı için bu şart değil ama tutarlılık için
        //      korunuyor.
        var n = customOrderCategoryCodes.Count;
        var rankSum = n * (n + 1) / 2.0;

        var resolved = new Dictionary<string, double>();
        for (var i = 0; i < n; i++)
        {
            resolved[customOrderCategoryCodes[i]] = (n - i) / rankSum;
        }

        return resolved;
    }
}
