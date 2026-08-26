import { anchorWeights, type TravelMode } from '@vivido/shared';
import { createRadiusPolygon, type WalkingLocation } from './walkingAccessibility';

/**
 * Anchor'ların (özel yerler) ortak "ağırlık merkezi" ve etrafındaki arama
 * alanı — R-anchor-sweet-spot.
 *
 * Merkez, AĞIRLIKLI ORTALAMA (centroid) ile hesaplanıyor.
 *
 * ⚠️ Önce ağırlıklı GEOMETRİK MEDYAN (Weiszfeld algoritması) denendi ama
 * canlı testte bir sorun ortaya çıktı: ağırlıklı medyanın bilinen bir
 * optimalite kuralı var — bir noktanın ağırlığı DİĞER TÜM noktaların
 * ağırlıkları TOPLAMINA eşit ya da ondan büyükse, sonuç o noktanın
 * ÜSTÜNE TAM OTURUR, diğerlerinin konumu hiç önemli olmadan. Bizim
 * `anchorWeights()` formülümüz (0.5^sıra) 3 anchor'da tam bu sınırı
 * aşıyor: 1.'nin ağırlığı (~%57) diğer ikisinin toplamından (~%43) büyük.
 * Yani medyan HER anchor yerleşiminde birebir 1. anchor'a eşit çıkıyordu —
 * 2. ve 3. hiç iz bırakmıyordu. "Sağlam" (robust) olma özelliği burada
 * "diğerlerini yok sayma"ya dönüşüyordu.
 *
 * Centroid'in bu sorunu YOK: konumları ağırlıklarıyla ORANTILI şekilde
 * harmanlar, tek bir noktanın üstüne (o nokta %100 ağırlıklı olmadıkça)
 * asla tam oturmaz — 1. öncelik en çok çeker ama 2./3. de gerçekten katkı
 * yapar.
 */

export interface AnchorPoint extends WalkingLocation {
  priority: number;
  mode: TravelMode;
}

interface WeightedPoint extends WalkingLocation {
  weight: number;
}

export interface AnchorSweetSpotResult {
  center: WalkingLocation;
  radiusMetres: number;
  polygon: ReturnType<typeof createRadiusPolygon>;
}

const EARTH_RADIUS_METRES = 6_371_008.8;

/**
 * Arama yarıçapı, mode'a (yürüyerek/araçla) göre — anchor'lar arasındaki
 * mesafeden DEĞİL.
 *
 * ⚠️ Önce yarıçap "merkezden en uzak anchor'a mesafe + sabit pay" olarak
 * hesaplanıyordu. Sorun: anchor'lar şehrin iki ucundaysa (örn. okul kuzeyde,
 * kütüphane güneyde) yarıçap onları İÇİNE ALMAK için otomatik şişiyordu —
 * canlı testte neredeyse tüm ilçeyi kaplayan, işe yaramaz bir daire çıktı.
 * Ama anchor'ların taranan alanın İÇİNDE olması gerekmiyor — önemli olan
 * merkezin (1. önceliğe yakın) sağlıklı olması, alanın ise MAKUL ve SINIRLI
 * kalması. Şehrin iki ucundaki 2 anchor için de "ikisine de erişilebilsin"
 * diye alanı devasa büyütmek yerine, 1. önceliğe yakın sağlıklı bir merkez
 * seçip onun etrafında gerçekçi boyutta bir alan taramak daha iyi bir
 * kullanıcı deneyimi veriyor.
 *
 * Yerine: her anchor'ın kendi ulaşım biçimine göre "benim için hâlâ makul"
 * bir yarıçapı var; kullanıcının anchor'ları arasında EN CÖMERT olanı
 * (en geniş toleranslı) tüm alan için kullanılıyor.
 *
 *   Yürüyerek → 800m (zaten kullandığımız yürüme hızı biriminden — bkz.
 *               db/schema/011_poi_density_radius_thalf.sql'deki toplu
 *               taşıma yarıçapı, aynı türetme).
 *   Araçla    → şehir içi ortalama araç hızı (trafik ışıkları vb. dahil,
 *               kabaca 25 km/h) yürüme hızının (4,8 km/h) ~5 katı — aynı
 *               oranla yarıçapı da 5 katına çıkarıyoruz (~4000m).
 */
const WALK_SEARCH_RADIUS_METRES = 800;
const CAR_SEARCH_RADIUS_METRES = 4000;

function searchRadiusForMode(mode: TravelMode): number {
  return mode === 'car' ? CAR_SEARCH_RADIUS_METRES : WALK_SEARCH_RADIUS_METRES;
}

/** İki nokta arasındaki büyük daire (jeodezik) mesafesi, metre cinsinden. */
export function haversineDistanceMetres(a: WalkingLocation, b: WalkingLocation): number {
  const lat1 = toRadians(a.lat);
  const lat2 = toRadians(b.lat);
  const dLat = toRadians(b.lat - a.lat);
  const dLon = toRadians(b.lon - a.lon);

  const sinDLat = Math.sin(dLat / 2);
  const sinDLon = Math.sin(dLon / 2);
  const h = sinDLat * sinDLat + Math.cos(lat1) * Math.cos(lat2) * sinDLon * sinDLon;

  return 2 * EARTH_RADIUS_METRES * Math.asin(Math.sqrt(Math.min(1, h)));
}

/**
 * Ağırlıklı ortalama (centroid) — her noktanın enlem/boylamı kendi
 * ağırlığıyla çarpılıp toplanır, toplam ağırlığa bölünür.
 *
 * Tek noktanın üstüne asla tam OTURMAZ (o nokta %100 ağırlıklı olmadıkça):
 * sonuç her zaman noktaların ağırlıklarıyla orantılı GERÇEK bir harman —
 * bkz. dosya başındaki not, geometrik medyanın neden bunun yerine
 * kullanılmadığı.
 */
export function weightedCentroid(points: WeightedPoint[]): WalkingLocation {
  if (points.length === 0) {
    throw new Error('weightedCentroid: en az bir nokta gerekli.');
  }

  const totalWeight = points.reduce((sum, p) => sum + p.weight, 0);

  return {
    lat: points.reduce((sum, p) => sum + p.lat * p.weight, 0) / totalWeight,
    lon: points.reduce((sum, p) => sum + p.lon * p.weight, 0) / totalWeight,
  };
}

/**
 * Kullanıcının anchor'larından tek bir ağırlık merkezi ve bu merkezin
 * etrafında MAKUL boyutta bir arama alanı üretir. Anchor'ların bu alanın
 * içinde olması ŞART DEĞİL — bkz. `searchRadiusForMode` üstündeki not.
 * Anchor yoksa null döner (gösterilecek bir alan yok).
 */
export function createAnchorAreaPolygon(anchors: AnchorPoint[]): AnchorSweetSpotResult | null {
  if (anchors.length === 0) return null;

  const ordered = [...anchors].sort((a, b) => a.priority - b.priority);
  const weights = anchorWeights(ordered.length);
  const weightedPoints: WeightedPoint[] = ordered.map((anchor, index) => ({
    lat: anchor.lat,
    lon: anchor.lon,
    weight: weights[index],
  }));

  const center = weightedCentroid(weightedPoints);

  const radiusMetres = Math.max(...ordered.map((anchor) => searchRadiusForMode(anchor.mode)));
  const polygon = createRadiusPolygon(center, radiusMetres);

  return { center, radiusMetres, polygon };
}

function toRadians(value: number): number {
  return (value * Math.PI) / 180;
}
