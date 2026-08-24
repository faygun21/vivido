/**
 * Web ve mobilin PAYLAŞTIĞI saf yardımcılar.
 *
 * Buradaki her fonksiyon iki istemcide de aynı sonucu vermek zorunda —
 * kopyalanıp bir tarafta değiştirilirse web ile mobil farklı şey gösterir.
 */

import type { LatLon } from './common';
import type { ScoreBand } from './score';

/**
 * Skor → renk bandı. Web ve mobil AYNI eşikleri kullanmalı.
 * Eşikler değişirse iki istemcide de tek noktadan değişsin diye burada.
 */
export function scoreBand(total: number): ScoreBand {
  if (total >= 85) return 'excellent';
  if (total >= 70) return 'good';
  if (total >= 55) return 'fair';
  return 'poor';
}

/**
 * Anchor öncelik sırasını ağırlığa çevirir — geometrik azalan.
 *
 * Neden ters sıra (`w_i = (n−i+1)/Σ`) değil de geometrik (`0.5^(i−1)/Σ`):
 * ters sırada listeye ÖNEMSİZ bir 5. anchor eklemek 1. anchor'ın ağırlığını
 * 0.667'den 0.333'e yarıya düşürür — kullanıcının "bu benim en önemli yerim"
 * beyanını bozar. Geometrikte w₁ her zaman 0.50–0.667 bandında kalır ve şu
 * özdeşlik sağlanır:
 *
 *     w₁ ≈ w₂ + w₃ + … + wₙ
 *     "En önemli yer, diğerlerinin toplamı kadar ağırlık taşır."
 *
 * ⚠️ Bu fonksiyon arayüzde ÖNİZLEME içindir.
 *    Skorun tek doğruluk kaynağı backend'dir — burada hesaplanan değer
 *    kullanıcıya gösterilir, karar vermek için kullanılmaz.
 */
export function anchorWeights(count: number): number[] {
  if (count <= 0) return [];
  const raw = Array.from({ length: count }, (_, i) => 0.5 ** i);
  const sum = raw.reduce((a, b) => a + b, 0);
  return raw.map((r) => r / sum);
}

/**
 * Merkez nokta çevresinde yaklaşık bir çember üretir — analiz alanı (buffer) halkası.
 *
 * R-106: kullanıcının seçtiği konum çevresinde yarıçapı km cinsinden verilen
 * kapalı bir halka döner. Harita istemcileri bunu GeoJSON
 * `Polygon.coordinates[0]` olarak katmana verir.
 *
 * Neden eşit alanlı (equirectangular) yaklaşım: `cos(lat)` ile boylam ölçeği
 * düzeltilir; 64 noktalık halka Çankaya ölçeğindeki yarıçaplarda (≤ 5 km)
 * görsel ve ölçüm hatasını ihmal edilebilir düzeye indirir. Gerçek büyük
 * daire (haversine) gerekirse rota/router katmanında ayrıca ele alınır.
 *
 * @param center   merkez nokta (lat/lon)
 * @param radiusKm yarıçap — kilometre cinsinden
 * @param segments halka nokta sayısı; varsayılan 64
 * @returns kapalı halka: [lon, lat] koordinatları, ilk nokta = son nokta
 */
export function circleAround(
  center: LatLon,
  radiusKm: number,
  segments = 64,
): [number, number][] {
  const latRad = (center.lat * Math.PI) / 180;
  // 1 enlem derecesi ≈ 111.32 km; 1 boylam derecesi enlemle birlikte daralır.
  const kmPerDegLat = 111.32;
  const kmPerDegLon = 111.32 * Math.cos(latRad);

  const dLat = radiusKm / kmPerDegLat;
  const dLon = radiusKm / kmPerDegLon;

  const ring: [number, number][] = [];
  for (let i = 0; i < segments; i++) {
    const angle = (i / segments) * 2 * Math.PI;
    ring.push([
      center.lon + dLon * Math.cos(angle),
      center.lat + dLat * Math.sin(angle),
    ]);
  }
  // GeoJSON Polygon kuralı: halka ilk noktanın tekrarıyla kapanır.
  ring.push(ring[0]!);
  return ring;
}
