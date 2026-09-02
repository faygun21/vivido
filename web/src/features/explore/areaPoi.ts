import type { Poi } from '@vivido/shared';
import {
  WALKING_METRES_PER_MINUTE,
  haversineDistanceMetres,
  type WalkingLocation,
} from '@/shared/map/walkingAccessibility';

/**
 * Analiz (yürüme) alanı içindeki bir hizmet noktası ve merkeze uzaklığı.
 *
 * Mobildeki `AreaPoi` ile aynı sözleşme (bkz.
 * `mobile/lib/features/location_analysis/domain/area_poi.dart`) — iki
 * istemci aynı çember için farklı mesafe/süre gösterirse hangisinin
 * doğru olduğu sorusu ortaya çıkar.
 *
 * Uzaklık İSTEMCİDE hesaplanıyor: `/pois/near` zaten yarıçap içinde
 * filtreliyor ama mesafeyi döndürmüyor; her POI için ayrı bir mesafe
 * isteği atmak (bir kategoride 40 nokta olabiliyor) hem yavaş hem
 * gereksiz. Kuş uçuşu mesafe bu ekran için yeterli — kullanıcı "market
 * 300 metre" bilgisiyle karar veriyor, 280 mi 310 mu olduğuyla değil.
 */
export interface AreaPoi {
  poi: Poi;
  /** Analiz merkezine kuş uçuşu mesafe (metre). */
  distanceM: number;
  /** Yaklaşık yürüme süresi (dakika). En az 1 — "0 dk" bir bilgi değil. */
  walkingMinutes: number;
}

/** Merkeze göre sıralanmış, alan İÇİNDEKİ noktaların listesi. */
export function rankPoisByDistance({
  center,
  pois,
  radiusM,
}: {
  center: WalkingLocation;
  pois: Poi[];
  radiusM: number;
}): AreaPoi[] {
  return pois
    .map((poi) => {
      const distanceM = haversineDistanceMetres(center, {
        lat: poi.latitude,
        lon: poi.longitude,
      });
      return {
        poi,
        distanceM,
        walkingMinutes: Math.max(1, Math.round(distanceM / WALKING_METRES_PER_MINUTE)),
      };
    })
    // Sunucu yarıçapı bbox/PostGIS ile uyguluyor; kenar durumlarda birkaç
    // metre taşan sonuçlar gelebiliyor. Listede "yürüme alanı içinde"
    // diyorsak gerçekten içinde olmalı.
    .filter((item) => item.distanceM <= radiusM)
    .sort((left, right) => left.distanceM - right.distanceM);
}

/** "376 m" / "1,2 km" — bin metreden sonra okunabilirlik için kilometre. */
export function formatAreaDistance(metres: number): string {
  return metres < 1000
    ? `${Math.round(metres)} m`
    : `${(metres / 1000).toFixed(1).replace('.', ',')} km`;
}

/**
 * POI'lerin ~%32'sinin OSM'de adı yok; adı olmayan satır boş kalmasın.
 * (Haritadaki balonun aksine burada kategori adı BAŞLIK olamaz — liste
 * zaten tek bir kategoriyi gösteriyor, her satır aynı şeyi yazardı.)
 */
export function areaPoiName(poi: Poi): string | null {
  const name = poi.name?.trim();
  return name ? name : null;
}

/**
 * Dar kategori şeridine sığan etiket.
 *
 * "Kafe ve restoran" 3.6rem'lik şeride sığmıyor; ilk kelime yeterince
 * ayırt edici — tam adı düğmenin `title`/`aria-label`'ı taşıyor.
 */
export function shortCategoryLabel(label: string): string {
  const firstWord = label.split(/[ /]/)[0] ?? label;
  return firstWord.length > 9 ? `${firstWord.slice(0, 8)}…` : firstWord;
}
