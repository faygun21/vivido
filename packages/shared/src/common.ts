/**
 * Birden fazla modülün paylaştığı temel tipler.
 *
 * Buraya bir tip eklemeden önce düşün: gerçekten iki ayrı modül mü
 * kullanıyor? Tek modül kullanıyorsa orada kalsın — bu dosya büyüdükçe
 * herkesin dokunduğu bir çakışma noktasına dönüşür.
 */

/** Bir anchor'a ya da rotaya hangi ulaşım moduyla gidiliyor. */
export type TravelMode = 'foot' | 'car';

/** API'de koordinat her zaman lat/lon çifti olarak taşınır.
 *  Veritabanında `geometry(Point, 4326)` olarak saklanır — bu dönüşüm
 *  backend'in işidir, istemci GeoJSON görmez. */
export interface LatLon {
  lat: number;
  lon: number;
}

export interface GeoJsonLineString {
  type: 'LineString';
  /** [lon, lat] sırası — GeoJSON standardı lat/lon DEĞİL lon/lat ister. */
  coordinates: [number, number][];
}
