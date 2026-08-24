/**
 * Web ve mobilin PAYLAŞTIĞI saf yardımcılar.
 *
 * Buradaki her fonksiyon iki istemcide de aynı sonucu vermek zorunda —
 * kopyalanıp bir tarafta değiştirilirse web ile mobil farklı şey gösterir.
 */

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
