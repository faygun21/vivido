export const WALKING_MINUTE_OPTIONS = [5, 10, 15, 20, 30] as const;
export const DEFAULT_WALKING_MINUTES = 15;

export type WalkingMinutes = (typeof WALKING_MINUTE_OPTIONS)[number];

export interface WalkingLocation {
  lat: number;
  lon: number;
}

/**
 * Standart 4,8 km/sa yürüme hızı.
 *
 * ⚠️ DIŞA AÇIK olmak zorunda: alan içi hizmet noktaları listesi
 * (`areaPoi.ts`) her noktanın yürüme süresini bu SABİTLE hesaplıyor.
 * Farklı bir hız kullansaydı çemberin kenarındaki bir nokta "18 dk"
 * diyebilirdi, oysa çemberin kendisi 15 dk (mobildeki `AreaPoi` ile
 * aynı gerekçe).
 */
export const WALKING_METRES_PER_MINUTE = 80;
const EARTH_RADIUS_METRES = 6_371_008.8;

export function isWalkingMinutes(value: number): value is WalkingMinutes {
  return WALKING_MINUTE_OPTIONS.some((option) => option === value);
}

/** Yürüme alanının metre cinsinden yarıçapı — çember de liste de bunu kullanır. */
export function walkingRadiusMetres(minutes: WalkingMinutes): number {
  return minutes * WALKING_METRES_PER_MINUTE;
}

/**
 * Seçilen nokta çevresinde, standart 4,8 km/sa yürüme hızına göre erişim alanı.
 * Noktalar küresel ileri-jeodezik formülle üretildiği için enlem/boylam
 * derecelerini metre gibi kullanmaz ve farklı enlemlerde bozulmaz.
 */
export function createWalkingAccessibilityPolygon(
  location: WalkingLocation,
  minutes: WalkingMinutes,
  segments = 72,
) {
  const radiusMetres = walkingRadiusMetres(minutes);
  const feature = createRadiusPolygon(location, radiusMetres, segments);

  return {
    ...feature,
    properties: { minutes, radiusMetres },
  };
}

/** Metre cinsinden yarıçapla kapalı, jeodezik bir GeoJSON poligonu üretir. */
export function createRadiusPolygon(
  location: WalkingLocation,
  radiusMetres: number,
  segments = 72,
) {
  const angularDistance = radiusMetres / EARTH_RADIUS_METRES;
  const lat1 = toRadians(location.lat);
  const lon1 = toRadians(location.lon);
  const ring: [number, number][] = [];

  for (let index = 0; index < segments; index += 1) {
    const bearing = (2 * Math.PI * index) / segments;
    const lat2 = Math.asin(
      Math.sin(lat1) * Math.cos(angularDistance)
      + Math.cos(lat1) * Math.sin(angularDistance) * Math.cos(bearing),
    );
    const lon2 = lon1 + Math.atan2(
      Math.sin(bearing) * Math.sin(angularDistance) * Math.cos(lat1),
      Math.cos(angularDistance) - Math.sin(lat1) * Math.sin(lat2),
    );
    ring.push([toDegrees(lon2), toDegrees(lat2)]);
  }

  ring.push(ring[0]);

  return {
    type: 'Feature' as const,
    properties: { radiusMetres },
    geometry: { type: 'Polygon' as const, coordinates: [ring] },
  };
}

/** İki koordinat arasındaki kuş uçuşu mesafeyi metre cinsinden hesaplar. */
export function haversineDistanceMetres(
  coord1: WalkingLocation,
  coord2: WalkingLocation,
): number {
  const lat1 = toRadians(coord1.lat);
  const lat2 = toRadians(coord2.lat);
  const deltaLat = toRadians(coord2.lat - coord1.lat);
  const deltaLon = toRadians(coord2.lon - coord1.lon);

  const a =
    Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) *
    Math.sin(deltaLon / 2) * Math.sin(deltaLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return EARTH_RADIUS_METRES * c;
}
function toRadians(value: number): number {
  return value * Math.PI / 180;
}

function toDegrees(value: number): number {
  return value * 180 / Math.PI;
}