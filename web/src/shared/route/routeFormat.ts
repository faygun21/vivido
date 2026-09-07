/**
 * Rota metrikleri için saf biçimlendirme yardımcıları — R-121.
 *
 * Arayüzde mesafe/süre HER ZAMAN buradan geçer; iki yerde ayrı biçim
 * üretmek (ör. "1,2 km" ile "1.2 km") rapor ekranında tutarsızlık yaratır.
 * Explore (rota oluşturucu) ve Profil (kayıtlı rotalar) bu modülü paylaşır.
 */

/** Metre → '12,3 km' ya da '850 m'. */
export function formatRouteDistance(meters: number): string {
  if (meters < 1000) return `${Math.round(meters)} m`;
  return `${(meters / 1000).toLocaleString('tr-TR', { maximumFractionDigits: 1 })} km`;
}

/** Saniye → '25 dk', '1 sa 12 dk' ya da '2 sa'. Negatif değeri 0'a yumuşatır. */
export function formatRouteDuration(seconds: number): string {
  const totalMinutes = Math.max(0, Math.round(seconds / 60));
  if (totalMinutes < 60) return `${totalMinutes} dk`;

  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;
  return minutes === 0 ? `${hours} sa` : `${hours} sa ${minutes} dk`;
}

/** Varsayılan rota adı: 'Ziyaret rotası · 25 Ağu'. */
export function routeNameForToday(date = new Date()): string {
  const day = date.toLocaleDateString('tr-TR', { day: 'numeric', month: 'short' });
  return `Ziyaret rotası · ${day}`;
}

/** Ulaşım modu → Türkçe etiket (metrik kartı ve formda ortak). */
export function travelModeLabel(mode: 'car' | 'foot'): string {
  return mode === 'foot' ? 'Yürüyerek' : 'Araç';
}

/**
 * Rota uç noktasının döndürdüğü `problem.code` → kullanıcıya gösterilen
 * Türkçe mesaj. Arayüz title'a değil koda dallanır (kural).
 */
export function routeProblemMessage(code: string | undefined): string {
  switch (code) {
    case 'OSRM_UNAVAILABLE':
      return 'Rota servisi şu anda kullanılamıyor. Kısa süre sonra tekrar dene.';
    case 'ROUTE_STOP_LIMIT_EXCEEDED':
      return 'Bir rota 2 ile 8 konut arasında içermelidir.';
    case 'ROUTE_VALIDATION_ERROR':
      return 'İstek geçersiz — seçimlerini ve başlangıç noktasını kontrol et.';
    default:
      return 'Rota oluşturulamadı. Lütfen yeniden dene.';
  }
}
