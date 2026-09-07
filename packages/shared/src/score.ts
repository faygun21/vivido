/**
 * Skor ve gerekçe tablosu sözleşmesi (W5, W6). — Hafta 2
 *
 * Ürünün kalbi: her ev için tek bir 0–100 skor ve o skorun
 * SATIR SATIR gerekçesi.
 */

export type ScoreBand = 'excellent' | 'good' | 'fair' | 'poor';

/*
 * ⚠️ BURADA ESKİDEN `ScoreRow` / `ScoreResult` / `ScoreSummary` VARDI.
 *
 * Hafta 2'de PLANLANAN skor sözleşmesiydi; sunucu hiçbir zaman o şekli
 * döndürmedi. Gerçek şekiller `property.ts` içinde: `PropertyScoreRow`,
 * `PropertyScoreDetail`. İki ayrı "skor satırı" tipinin yan yana durması,
 * hangisinin gerçek olduğunu her okuyanın yeniden çözmesi gereken bir
 * tuzaktı — hiçbir dosya planlanan olanları import etmiyordu.
 *
 * Yeniden gerekirse git geçmişinden alınabilir. Sözleşmeyi ikiye bölmeden
 * yapılacak doğru iş, `api/openapi.yaml` yazılıp tiplerin tek kaynaktan
 * üretilmesi (docs/04-MEVCUT-DURUM §8).
 */
