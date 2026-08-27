/**
 * Rota başlangıç noktası — kaynağı ve geçerliliği.
 *
 * ⭐ NEDEN "HARİTADAN SEÇ" KALDIRILDI
 *
 * Eskiden başlangıç haritaya tıklayarak seçiliyordu. İki sorunu vardı:
 * kullanıcı zaten konut seçmek için haritaya tıklıyor (aynı hareket iki
 * farklı anlam taşıyor, kip karışıyor) ve "evimden çıkıp bu evleri gezsem"
 * senaryosunda kendi konumunu haritada elle bulmak zorunda kalıyordu.
 * Artık iki yol var: canlı konum ya da yazılan adres — Google Maps'in
 * yaptığı gibi.
 */

import type { LocationSearchResult } from '@vivido/shared';
import type { UserLocation } from '@/shared/map/useUserLocation';

/** Rotanın başlayacağı nokta. */
export interface RouteStart {
  lat: number;
  lon: number;
  label: string;
  /** `live` = cihazın GPS'i, `address` = arama kutusundan seçilen adres. */
  source: 'live' | 'address';
}

/**
 * Çankaya ilçe sınırının kapsayıcı kutusu.
 *
 * ⚠️ Uydurma değil: `web/public/geo/cankaya.geojson` (OSM relation/1812321)
 * poligonundan hesaplandı. Sayılar o dosya değişirse yeniden çıkarılmalı.
 *
 * NEDEN KUTU, POLİGON DEĞİL: amaç "kullanıcı bambaşka bir şehirde mi"
 * sorusunu ucuza cevaplamak. Sınıra 2 km mesafedeki bir başlangıç zaten
 * çalışır (OSRM yol ağına yapıştırır); İstanbul'daki bir başlangıç ise
 * kutunun çok dışında kalır. Poligon içi/dışı testi bu ayrım için gereksiz
 * hassasiyet ve ek kod demekti.
 */
export const CANKAYA_BOUNDS = {
  west: 32.6265,
  east: 33.1435,
  south: 39.6583,
  north: 39.9375,
} as const;

/**
 * Nokta Çankaya kutusunun içinde mi?
 *
 * Dışarıdaysa rota kurulamaz: OSRM grafiği yalnızca Çankaya kesitinden
 * üretildi (`data/artifacts/osrm/`), dolayısıyla başka bir şehirdeki
 * başlangıç en yakın Çankaya yoluna yapışır ve mesafe anlamsız büyür.
 */
export function isWithinCankaya(point: { lat: number; lon: number }): boolean {
  return (
    point.lon >= CANKAYA_BOUNDS.west &&
    point.lon <= CANKAYA_BOUNDS.east &&
    point.lat >= CANKAYA_BOUNDS.south &&
    point.lat <= CANKAYA_BOUNDS.north
  );
}

/** Canlı konumu rota başlangıcına çevirir. */
export function startFromLiveLocation(location: UserLocation): RouteStart {
  return {
    lat: location.lat,
    lon: location.lon,
    label: 'Mevcut konumum',
    source: 'live',
  };
}

/** Adres arama sonucunu rota başlangıcına çevirir. */
export function startFromAddress(result: LocationSearchResult): RouteStart {
  return {
    lat: result.latitude,
    lon: result.longitude,
    label: result.label,
    source: 'address',
  };
}
