import { useEffect, useRef, useState } from 'react';
// maplibre-gl v6'nın default export'u YOK — adlandırılmış import şart.
import {
  AttributionControl,
  LngLatBounds,
  Map as MapLibreMap,
  Marker,
  NavigationControl,
  Popup,
  setWorkerUrl,
  type GeoJSONSource,
  type MapGeoJSONFeature,
  type MapOptions,
} from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
// ⚠️ `?worker&url`: Vite worker'ı KENDİ bağımlılıklarıyla paketleyip
// yayımlanan dosyanın adresini veriyor. `?url` tek başına yetmez —
// worker içeride `maplibre-gl-shared.mjs`'i import ediyor, ham varlık
// olarak kopyalansa o import çözülemezdi.
import maplibreWorkerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url';
import { GLYPHS_URL, MAP_ATTRIBUTION, TILE_URL, USE_RASTER_BASEMAP } from '@/shared/config';
import {
  createWalkingAccessibilityPolygon,
  type WalkingLocation,
  type WalkingMinutes,
} from './walkingAccessibility';
import {
  createAnalysisAreaPolygon,
  type AnalysisRadiusKm,
} from './analysisArea';
import type { Poi, RouteDetail, RouteStop } from '@vivido/shared';
import { poiCategoryColor, POI_CATEGORY_COLORS, POI_FALLBACK_COLOR } from './poiColors';

/**
 * ⭐ ÜRETİM DERLEMESİNDE HARİTAYI BOŞ ÇİZEN HATANIN DÜZELTMESİ
 *
 * MapLibre 6, worker dosyasının adını ÇALIŞMA ANINDA kuruyor:
 *
 *     new Worker(new URL(dev ? `…-worker-dev.mjs` : `…-worker.mjs`,
 *                        import.meta.url), { type: 'module' })
 *
 * Ad bir üçlü operatörden geldiği için Vite 8 / Rolldown bunu statik
 * olarak göremiyor ve worker parçasını çıktıya HİÇ EKLEMİYOR. Sonuç
 * `dist/` içinde yalnızca `index-*.js` + CSS; worker isteği 404'e düşüyor.
 *
 * Belirtisi sinsi: MapLibre GeoJSON ayrıştırmayı ve karo çizimini worker'da
 * yapar. Worker ölünce HİÇBİR veri katmanı çizilmez — ama arka plan rengi,
 * +/− kontrolü ve atıf ana iş parçacığında olduğu için çalışmaya devam eder.
 * Harita "var" görünür, bomboştur ve HATA FIRLATMAZ; konsol tertemiz kalır.
 *
 * `docs/04-MEVCUT-DURUM.md` §4.5 aynı belirtiyi geliştirme sunucusu için
 * kaydetmiş ve "üretim derlemesi etkilenmez" demişti. Etkileniyormuş —
 * kimse fark etmemişti çünkü `vite build` çıktısı ilk kez staging'de sunuldu.
 *
 * Modül kapsamında çağrılıyor: ilk harita oluşturulmadan önce çalışması şart.
 */
setWorkerUrl(maplibreWorkerUrl);

/** `StyleSpecification` maplibre-gl tarafından yeniden dışa aktarılmıyor. */
type MapStyle = NonNullable<MapOptions['style']>;

/**
 * GeoJSON için yerel asgari tipler.
 *
 * `@types/geojson` yalnızca maplibre'ın alt bağımlılığı; web'in doğrudan
 * bağımlılığı değil, bu yüzden global `GeoJSON` ad alanı derlemeye girmiyor.
 * İhtiyacımız olan yüzey bu kadar küçükken pnpm-lock'u değiştirmeye değmez.
 */
interface GeoFeature {
  type: 'Feature';
  properties: Record<string, unknown> | null;
  geometry: { type: string; coordinates: unknown } | null;
}
interface GeoCollection {
  type: 'FeatureCollection';
  features: GeoFeature[];
}

/**
 * Çankaya haritası — ortak bileşen.
 *
 * Veri kaynağı: veri ekibinin ürettiği GeoJSON'lar (`web/public/geo/`).
 *   · cankaya.geojson            → ilçe sınırı (OSM relation/1812321)
 *   · cankaya-mahalleler.geojson → 124 mahalle poligonu
 *
 * ⚠️ Kurulum sırası önemli: GeoJSON'lar haritadan ÖNCE indirilir ve
 * kaynak/katman tanımları başlangıç stiline gömülür. `map.on('load')`
 * içinde `addSource`/`addLayer` çağırmak, React StrictMode'un geliştirme
 * modundaki çift mount'uyla yarışıyor — ilk harita `load` olayı gelmeden
 * `remove()` ediliyor ve katmanlar sessizce hiç eklenmemiş oluyordu.
 *
 * ⚠️ Neden vektör/raster karo yok: `cankaya.mbtiles` artefaktı henüz
 * yayınlanmadı (`data/artifacts/` boş, GitHub release yok). Altlık gelince
 * bu katmanların ALTINA serilir.
 *
 * Neden metin katmanı (symbol) yok: MapLibre'da metin çizmek `glyphs`
 * uç noktası ister, o da tileserver'a bağlı. Mahalle adı bunun yerine
 * fare üzerine gelince HTML rozetinde gösteriliyor — dış bağımlılık sıfır.
 */

export interface MapPoint {
  lat: number;
  lon: number;
}

export interface MapMarker extends MapPoint {
  id: string;
  label: string;
  /** 1 = en önemli. Pin üzerinde numara olarak görünür. */
  priority?: number;
  /** CSS sınıfı — varsayılan `map-pin`; rota seçimi gibi farklı renkler için. */
  className?: string;
  /** Pin metni — `priority`'ye üstün gelir (ör. rota başlangıcı için "A"). */
  text?: string;
}

export interface MapFocus extends MapPoint {
  id: string;
  label: string;
  bounds?: { south: number; west: number; north: number; east: number } | null;
}

/** Haritanın görünüm alanı (R-108 — bbox tabanlı POI çekme için). */
export interface MapBounds {
  south: number;
  west: number;
  north: number;
  east: number;
}

/**
 * Bir konut noktası — R-109 gereği tek tek `Marker` DOM elemanı DEĞİL,
 * `konutlar` GeoJSON kaynağına yazılıp MapLibre'ın kendi cluster
 * motoruyla çizilir (bkz. `buildStyle`). Yüzlerce/binlerce nokta için
 * tek yol bu; DOM marker'lar bu ölçekte tarayıcıyı kilitler.
 */
export interface PropertyPoint extends MapPoint {
  id: string;
}

interface CankayaMapProps {
  /** Verilirse haritaya tıklanabilir hale gelir (anchor ekleme akışı). */
  onMapClick?: (point: MapPoint) => void;
  /** Kümelenmemiş bir konut noktasına tıklandığında id'siyle çağrılır. */
  onPropertyClick?: (id: string) => void;
  markers?: MapMarker[];
  /** Bütçeye uygun konutlar — haritada kümeli olarak gösterilir. */
  properties?: PropertyPoint[];
  /** Arama sonucu değiştiğinde haritayı bu konuma taşır. */
  focus?: MapFocus | null;
  /** Harita kabının yüksekliği (CSS değeri). */
  height?: string;
  selectedLocation?: WalkingLocation | null;
  /** Analiz merkezindeki sürüklenebilir işaretçi bırakıldığında yeni konumu bildirir. */
  onSelectedLocationChange?: (location: WalkingLocation) => void;
  walkingMinutes?: WalkingMinutes;
  analysisRadiusKm?: AnalysisRadiusKm;
  /**
   * Görünür alanın solunda kaç piksellik kısmın ÖRTÜLÜ olduğu.
   *
   * Keşfet ekranında çekmece haritanın üstünde yüzüyor; padding verilmezse
   * ilçe sınırının solu panelin altında kalır ve kullanıcı haritayı elle
   * kaydırmak zorunda kalır. MapLibre `padding`i hem `fitBounds` hem de
   * ortalama hesabına katar.
   */
  padLeft?: number;
  /**
   * R-108/109/110 — haritada gösterilecek POI'ler (kategori filtresi API'de
   * uygulanmış halde gelir; burada yalnızca çizilir).
   */
  pois?: Poi[];
  /* NOT: konutlar için ikinci bir prop YOK. Yukarıdaki `properties`
     (PropertyPoint[]) tek kaynak — `konutlar` cluster katmanını o besliyor. */
  /** POI popup'ında Türkçe kategori adı göstermek için kod → ad haritası. */
  poiCategoryNames?: Record<string, string>;
  /** Harita taşındığında görünüm alanını (bbox) yukarı bildirir. */
  onBoundsChange?: (bounds: MapBounds) => void;
  /**
   * R-121 — oluşturulmuş ziyaret rotası. Verilirse `rota` GeoJSON kaynağına
   * çizgi yazılır, duraklar numaralı mavi pinlerle basılır ve harita rotanın
   * tamamını kapsayacak şekilde yakınlaştırılır. `null` çizgiyi kaldırır.
   */
  route?: RouteDetail | null;
}

const GEO_DISTRICT = '/geo/cankaya.geojson';
const GEO_NEIGHBOURHOODS = '/geo/cankaya-mahalleler.geojson';

/** Çankaya kaba bbox — sınır verisi okunamazsa kullanılacak yedek görünüm. */
const FALLBACK_CENTER: [number, number] = [32.85, 39.87];

/**
 * Kendi karo sunucumuzdan gelen sokak / bina / su katmanları.
 *
 * Şema: OpenMapTiles (Planetiler'ın varsayılan çıktısı). `source-layer`
 * adları o şemadan gelir — `transportation`, `building`, `water`…
 * Alta serilir; mahalle poligonları bunların ÜSTÜNDE yarı saydam durur.
 */
function vectorBasemapLayers(): unknown[] {
  return [
    {
      id: 'su',
      type: 'fill',
      source: 'karolar',
      'source-layer': 'water',
      paint: { 'fill-color': '#b9d6de' },
    },
    {
      id: 'yesil-alan',
      type: 'fill',
      source: 'karolar',
      'source-layer': 'landcover',
      paint: { 'fill-color': '#d6e6d2', 'fill-opacity': 0.7 },
    },
    {
      id: 'park',
      type: 'fill',
      source: 'karolar',
      'source-layer': 'park',
      paint: { 'fill-color': '#cfe6c8', 'fill-opacity': 0.6 },
    },
    {
      id: 'binalar',
      type: 'fill',
      source: 'karolar',
      'source-layer': 'building',
      minzoom: 13,
      paint: {
        'fill-color': '#d9d4cc',
        'fill-outline-color': '#c2bcb2',
        // Uzakta bina kalabalığı haritayı okunmaz yapıyor; yakınlaştıkça belirginleşsin.
        'fill-opacity': ['interpolate', ['linear'], ['zoom'], 13, 0.25, 16, 0.85],
      },
    },
    {
      id: 'yollar-kucuk',
      type: 'line',
      source: 'karolar',
      'source-layer': 'transportation',
      filter: ['!', ['in', ['get', 'class'], ['literal', ['motorway', 'trunk', 'primary']]]],
      paint: {
        'line-color': '#ffffff',
        'line-width': ['interpolate', ['linear'], ['zoom'], 11, 0.4, 16, 3],
      },
    },
    {
      id: 'yollar-ana',
      type: 'line',
      source: 'karolar',
      'source-layer': 'transportation',
      filter: ['in', ['get', 'class'], ['literal', ['motorway', 'trunk', 'primary']]],
      paint: {
        'line-color': '#f7c873',
        'line-width': ['interpolate', ['linear'], ['zoom'], 9, 0.8, 16, 6],
      },
    },
  ];
}

/** Etiketler en üstte — karo sunucusu varsa (glyph gerekir). */
function vectorLabelLayers(): unknown[] {
  return [
    {
      id: 'yol-adlari',
      type: 'symbol',
      source: 'karolar',
      'source-layer': 'transportation_name',
      minzoom: 14,
      layout: {
        'text-field': ['get', 'name'],
        'text-font': ['Noto Sans Regular'],
        'text-size': 11,
        'symbol-placement': 'line',
      },
      paint: { 'text-color': '#4a4a4a', 'text-halo-color': '#ffffff', 'text-halo-width': 1.2 },
    },
    {
      id: 'yer-adlari',
      type: 'symbol',
      source: 'karolar',
      'source-layer': 'place',
      layout: {
        'text-field': ['get', 'name'],
        'text-font': ['Noto Sans Regular'],
        'text-size': ['interpolate', ['linear'], ['zoom'], 10, 11, 15, 15],
      },
      paint: { 'text-color': '#2b3a36', 'text-halo-color': '#ffffff', 'text-halo-width': 1.4 },
    },
  ];
}

/**
 * Kümelenmemiş konut noktası için ev ikonu — canvas'ta çizilip
 * `map.addImage`'a ham piksel olarak verilir. `text-field`/emoji YERİNE
 * bunu kullanıyoruz: emoji glyph'leri de MapLibre'ın `glyphs` uç noktasına
 * (harita karo sunucusu) muhtaç, sunucu yoksa hiç görünmez. Tarayıcının
 * kendi 2D canvas'ı ise fontu HER ZAMAN çizebiliyor, sunucudan bağımsız.
 */
function drawHouseIcon(size = 36): ImageData {
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d')!;

  const cx = size / 2;
  const cy = size / 2;
  const r = size / 2 - 2;

  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.fillStyle = '#ea580c';
  ctx.fill();
  ctx.lineWidth = 2;
  ctx.strokeStyle = '#fff';
  ctx.stroke();

  ctx.font = `${Math.round(size * 0.55)}px sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#fff';
  ctx.fillText('🏠', cx, cy + 1);

  return ctx.getImageData(0, 0, size, size);
}

function buildStyle(district: GeoCollection, neighbourhoods: GeoCollection): MapStyle {
  const sources: Record<string, unknown> = {
    ilce: { type: 'geojson', data: district },
    // feature-state ile hover boyaması yapabilmek için id şart.
    mahalleler: { type: 'geojson', data: neighbourhoods, generateId: true },
    'yurume-alani': {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    },
    'analiz-alani': {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    },
    'yurume-merkezi': {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    },
    // R-108 — POI noktaları. Kaynak burada bir kez kurulur; veri geldikçe
    // yalnızca `setData` ile güncellenir (`map.on('load')` yarışı StrictMode
    // çift mount'unda katmanları sessizce kaybettiriyordu).
    pois: {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
      cluster: true,
      clusterRadius: 50,
      clusterMaxZoom: 14,
      generateId: true,
    },
    // Konut noktaları — R-109: yakınlaştırma seviyesine göre gruplanmalı.
    // Yüzlerce/binlerce konutu tek tek DOM `Marker` elemanı olarak basmak
    // (eskiden yapıldığı gibi) hem tarayıcıyı kilitliyor hem de üst üste
    // binen pin'ler tek bir nokta gibi görünüyordu. MapLibre'ın kendi
    // GeoJSON cluster desteği ikisini birden çözüyor: uzakta tek küme
    // dairesi, yakınlaşınca gerçek noktalar — hepsi GPU'da çiziliyor.
    konutlar: {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
      cluster: true,
      clusterMaxZoom: 15,
      clusterRadius: 45,
    },
    // R-121 — oluşturulan rota çizgisi. Kaynak bir kez kurulur; veri `setData`
    // ile güncellenir (diğer GeoJSON kaynaklarıyla aynı StrictMode kuralı).
    rota: {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    },
  };

  const layers: unknown[] = [
    { id: 'arka-plan', type: 'background', paint: { 'background-color': '#eef2f0' } },
  ];

  const hasVectorTiles = TILE_URL !== '';

  if (hasVectorTiles) {
    sources.karolar = { type: 'vector', url: TILE_URL, attribution: MAP_ATTRIBUTION };
    layers.push(...vectorBasemapLayers());
  } else if (USE_RASTER_BASEMAP) {
    sources.osm = {
      type: 'raster',
      tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
      tileSize: 256,
      maxzoom: 19,
      attribution: MAP_ATTRIBUTION,
    };
    layers.push({ id: 'osm', type: 'raster', source: 'osm' });
  } else {
    // Altlık yokken ilçe alanını beyaza boyamak, mahalle sınırlarını
    // okunur kılıyor. Altlık varsa sokakları örteceği için eklenmez.
    layers.push({
      id: 'ilce-dolgu',
      type: 'fill',
      source: 'ilce',
      paint: { 'fill-color': '#ffffff', 'fill-opacity': 0.9 },
    });
  }

  layers.push(
    {
      id: 'analiz-alani-dolgu',
      type: 'fill',
      source: 'analiz-alani',
      paint: { 'fill-color': '#0f766e', 'fill-opacity': 0.1 },
    },
    {
      id: 'analiz-alani-cizgi',
      type: 'line',
      source: 'analiz-alani',
      paint: {
        'line-color': '#0f766e',
        'line-width': 2,
        'line-dasharray': [2, 2],
      },
    },
    {
      id: 'yurume-alani-dolgu',
      type: 'fill',
      source: 'yurume-alani',
      paint: { 'fill-color': '#f59e0b', 'fill-opacity': 0.22 },
    },
    {
      id: 'yurume-alani-cizgi',
      type: 'line',
      source: 'yurume-alani',
      paint: { 'line-color': '#b45309', 'line-width': 2.5 },
    },
    {
      id: 'yurume-merkezi-nokta',
      type: 'circle',
      source: 'yurume-merkezi',
      paint: {
        'circle-radius': 7,
        'circle-color': '#f59e0b',
        'circle-stroke-color': '#7c2d12',
        'circle-stroke-width': 2,
      },
    },
    {
      id: 'mahalle-dolgu',
      type: 'fill',
      source: 'mahalleler',
      paint: {
        'fill-color': [
          'case',
          ['boolean', ['feature-state', 'hover'], false],
          '#0b6e60',
          '#7fb3a8',
        ],
        'fill-opacity': [
          'case',
          ['boolean', ['feature-state', 'hover'], false],
          0.6,
          TILE_URL !== '' || USE_RASTER_BASEMAP ? 0.18 : 0.35,
        ],
      },
    },
    {
      id: 'mahalle-cizgi',
      type: 'line',
      source: 'mahalleler',
      paint: { 'line-color': '#4a8578', 'line-width': 0.8, 'line-opacity': 0.9 },
    },
    {
      id: 'ilce-sinir',
      type: 'line',
      source: 'ilce',
      paint: { 'line-color': '#0b3d35', 'line-width': 2.4 },
    },
    // Küme dairesi — çaptaki basamaklar içindeki konut sayısına göre büyür.
    {
      id: 'konut-kumeleri',
      type: 'circle',
      source: 'konutlar',
      filter: ['has', 'point_count'],
      paint: {
        'circle-color': '#ea580c',
        'circle-opacity': 0.85,
        'circle-stroke-width': 2,
        'circle-stroke-color': '#fff',
        'circle-radius': [
          'step',
          ['get', 'point_count'],
          16, // < 25 konut
          25, 20,
          100, 26,
          500, 32,
        ],
      },
    },
    // Kümelenmemiş tek konut — yeterince yakınlaşınca kümenin yerini alır.
    // `icon-image` kullanıyoruz (düz daire değil): resim `map.addImage` ile
    // canvas'ta ÇİZİLİP eklendiği için MapLibre'ın `glyphs` uç noktasına
    // (karo sunucusu) bağlı değil — sunucu olmasa da ev ikonu görünür.
    {
      id: 'konut-noktalar',
      type: 'symbol',
      source: 'konutlar',
      filter: ['!', ['has', 'point_count']],
      layout: {
        'icon-image': 'ev-ikon',
        'icon-size': 1,
        'icon-allow-overlap': true,
      },
    },
  );

  // R-108 — POI nokta katmanları (uzakta küme, yakında tekil).
  //
  // ⚠️ Burada KONUT katmanı YOK. Konutlar `konutlar` kaynağından
  // `konut-kumeleri` / `konut-noktalar` / `konut-kume-sayisi` katmanlarıyla
  // çiziliyor (yukarısı). İki ayrı konut katmanı olursa aynı ev haritaya
  // iki kez basılır ve tıklama hangi katmana gittiği belirsizleşir.
  layers.push(
    clusterFillLayer('poi-cluster-dolgu', 'pois', '#7c3aed'),
    clusterCountLayer('poi-cluster-sayi', 'pois'),
    {
      id: 'poi-nokta',
      type: 'circle',
      source: 'pois',
      filter: ['!', ['has', 'point_count']],
      minzoom: 14,
      paint: {
        'circle-radius': 6,
        'circle-color': poiCategoryColorExpression(),
        'circle-stroke-color': '#ffffff',
        'circle-stroke-width': 1.5,
      },
    },
  );

  // R-121 — rota çizgisi: geniş koyu gölge şerit + üstte parlak mavi çizgi.
  // Kaynak boşken hiçbir şey çizilmez; `setData` ile dolunca görünür olur.
  layers.push(
    {
      id: 'rota-cizgi-golge',
      type: 'line',
      source: 'rota',
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: { 'line-color': '#1e3a8a', 'line-width': 9, 'line-opacity': 0.35 },
    },
    {
      id: 'rota-cizgi',
      type: 'line',
      source: 'rota',
      layout: { 'line-cap': 'round', 'line-join': 'round' },
      paint: {
        'line-color': '#2563eb',
        'line-width': ['interpolate', ['linear'], ['zoom'], 10, 4, 16, 7],
      },
    },
  );

  // Etiketler her şeyin üstünde kalmalı.
  if (hasVectorTiles) layers.push(...vectorLabelLayers());

  // Küme içindeki konut sayısı — `text-field` gerektirdiği için `glyphs`
  // uç noktası şart (yalnızca karo sunucusu varken tanımlı, bkz. yukarısı).
  // Sunucu yoksa küme dairesi (zaten eklendi) sayı olmadan görünür — bina
  // adları için kullanılan hover-rozeti yaklaşımıyla aynı kısıt.
  if (hasVectorTiles) {
    layers.push({
      id: 'konut-kume-sayisi',
      type: 'symbol',
      source: 'konutlar',
      filter: ['has', 'point_count'],
      layout: {
        'text-field': ['get', 'point_count_abbreviated'],
        'text-font': ['Noto Sans Regular'],
        'text-size': 12,
      },
      paint: { 'text-color': '#fff' },
    });
  }

  // Stil koşullu kurulduğu için TypeScript `type: 'raster'` gibi alanları
  // string-literal birleşimine daraltamıyor. Tek noktada dönüştürüyoruz;
  // şekil MapLibre style-spec v8 ile birebir uyumlu (validateStyleMin: 0 hata).
  return {
    version: 8,
    // `glyphs` yalnızca symbol katmanı varken anlamlı; karo sunucusu yoksa
    // hiç metin çizmediğimiz için dış bir font kaynağına da bağlanmıyoruz.
    ...(hasVectorTiles ? { glyphs: GLYPHS_URL } : {}),
    sources,
    layers,
  } as MapStyle;
}

/** Bir GeoJSON nesnesinin sınırlayıcı kutusunu hesaplar. */
function boundsOf(geojson: GeoCollection): LngLatBounds {
  const bounds = new LngLatBounds();

  const visit = (coords: unknown): void => {
    if (!Array.isArray(coords)) return;
    // [lon, lat] yaprağı
    if (typeof coords[0] === 'number' && typeof coords[1] === 'number') {
      bounds.extend(coords as [number, number]);
      return;
    }
    for (const child of coords) visit(child);
  };

  for (const feature of geojson.features) {
    if (feature.geometry && 'coordinates' in feature.geometry) {
      visit(feature.geometry.coordinates);
    }
  }
  return bounds;
}

// ─── R-108/109/110 — POI & konut katmanları ────────────────────────────────

/** POI dizisini GeoJSON FeatureCollection'a çevirir (küme katmanı için). */
function toPoiFeatureCollection(pois: Poi[]): GeoCollection {
  return {
    type: 'FeatureCollection',
    features: pois.map((poi) => ({
      type: 'Feature',
      properties: {
        id: poi.id,
        name: poi.name,
        category: poi.categoryCode,
      },
      geometry: { type: 'Point', coordinates: [poi.longitude, poi.latitude] },
    })),
  };
}

/** POI nokta rengi: kategori bazlı `match` ifadesi. */
function poiCategoryColorExpression(): unknown {
  const pairs = Object.entries(POI_CATEGORY_COLORS).flat();
  return ['match', ['get', 'category'], ...pairs, POI_FALLBACK_COLOR];
}

/** Kümelenmiş noktaların dolgu halkası. `maxzoom` ile kümeler tekil noktalara bırakır. */
function clusterFillLayer(id: string, source: string, color: string): unknown {
  return {
    id,
    type: 'circle',
    source,
    filter: ['has', 'point_count'],
    maxzoom: 14,
    paint: {
      'circle-color': color,
      'circle-opacity': 0.75,
      'circle-radius': ['step', ['get', 'point_count'], 16, 10, 20, 50, 26],
      'circle-stroke-color': '#ffffff',
      'circle-stroke-width': 2,
    },
  };
}

/** Küme sayısını gösteren sembol. */
function clusterCountLayer(id: string, source: string): unknown {
  return {
    id,
    type: 'symbol',
    source,
    filter: ['has', 'point_count'],
    maxzoom: 14,
    layout: {
      'text-field': ['get', 'point_count_abbreviated'],
      'text-size': 12,
    },
    paint: { 'text-color': '#ffffff' },
  };
}

/** POI/konut etkileşimlerini bir kez başlar: imleç, popup, küme zoom'u. */
function wirePoiInteractions(
  map: MapLibreMap,
  categoryNames: { current: Record<string, string> },
): void {
  // Konut katmanlarinin imlec/tiklama dinleyicileri yukarida, harita
  // kurulumunda baglaniyor (konut-kumeleri / konut-noktalar).
  const hoverLayers = ['poi-nokta', 'poi-cluster-dolgu'];
  for (const layer of hoverLayers) {
    map.on('mouseenter', layer, () => { map.getCanvas().style.cursor = 'pointer'; });
    map.on('mouseleave', layer, () => { map.getCanvas().style.cursor = ''; });
  }

  // R-110 — POI popup'ı
  map.on('click', 'poi-nokta', (e) => {
    const feature = e.features?.[0];
    if (!feature || !map) return;
    const props = feature.properties as Record<string, unknown>;
    const name = typeof props.name === 'string' && props.name ? props.name : 'İsimsiz hizmet noktası';
    const categoryCode = String(props.category ?? '');
    const categoryName = categoryNames.current[categoryCode] ?? categoryCode;
    const coordinates = (feature.geometry as { coordinates?: [number, number] }).coordinates;
    if (!coordinates) return;

    new Popup({ offset: 18, closeButton: false })
      .setLngLat(coordinates)
      .setHTML(poiPopupHtml(name, categoryName, categoryCode))
      .addTo(map);
  });

  // R-109 — küme tıklaması: yayılımına yakınlaş
  map.on('click', 'poi-cluster-dolgu', (e) => {
    const feature = e.features?.[0];
    if (feature) zoomToCluster(map, 'pois', feature);
  });
}

/** Küme tıklanınca kümenin yayılımına yakınlaşır (R-109). */
function zoomToCluster(map: MapLibreMap, sourceId: string, feature: MapGeoJSONFeature): void {
  const clusterId = feature.properties?.cluster_id;
  if (typeof clusterId !== 'number') return;

  const source = map.getSource(sourceId) as GeoJSONSource | undefined;
  if (!source) return;

  const coordinates = (feature.geometry as { coordinates?: [number, number] }).coordinates;
  if (!coordinates) return;

  // maplibre-gl v6: getClusterExpansionZoom Promise döner (callback API kaldırıldı).
  void source.getClusterExpansionZoom(clusterId).then((zoom) => {
    map.easeTo({ center: coordinates, zoom: zoom + 1 });
  });
}

/** Görünüm alanını (bbox) yukarı bildirir (R-108 — bbox tabanlı veri çekme). */
function reportBounds(map: MapLibreMap, cb?: (bounds: MapBounds) => void): void {
  if (!cb) return;
  const b = map.getBounds();
  cb({ south: b.getSouth(), west: b.getWest(), north: b.getNorth(), east: b.getEast() });
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (ch) => {
    const map: Record<string, string> = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;',
    };
    return map[ch];
  });
}

/** R-110 — POI popup içeriği (ad + kategori + temel bilgi). */
function poiPopupHtml(name: string, categoryName: string, categoryCode: string): string {
  return `
    <div class="vivido-popup">
      <div class="vivido-popup-title">${escapeHtml(name)}</div>
      <div class="vivido-popup-category">
        <span class="vivido-popup-dot" style="background:${poiCategoryColor(categoryCode)}"></span>
        ${escapeHtml(categoryName)}
      </div>
    </div>`;
}

/** R-121 — rota durağı popup içeriği (konut özeti + bacak bilgisi). */
function routeStopPopupHtml(stop: RouteStop): string {
  const property = stop.property;
  const rent = property.monthlyRent.toLocaleString('tr-TR');
  const area = property.areaM2 != null ? `${property.areaM2} m²` : '';
  const score = stop.score != null ? `Skor ${Math.round(stop.score)}/100` : 'Skor —';
  const leg = stop.legDistanceM != null ? `${Math.round(stop.legDistanceM / 100) / 10} km` : '';
  return `
    <div class="vivido-popup">
      <div class="vivido-popup-title">${stop.seq}. durak · ${escapeHtml(property.roomCount)}</div>
      <div class="vivido-popup-category">
        ${escapeHtml(property.neighborhood ?? '')}${area ? ` · ${area}` : ''} · ${rent} ₺<br />
        ${score}${leg ? ` · ${leg}` : ''}
      </div>
    </div>`;
}

export function CankayaMap({
  onMapClick,
  onPropertyClick,
  markers = [],
  properties = [],
  focus,
  height = '100%',
  selectedLocation = null,
  onSelectedLocationChange,
  walkingMinutes = 15,
  analysisRadiusKm = 2,
  padLeft = 0,
  pois,
  poiCategoryNames,
  onBoundsChange,
  route = null,
}: CankayaMapProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const markerObjectsRef = useRef<Marker[]>([]);
  const analysisMarkerRef = useRef<Marker | null>(null);
  const userLocationMarkerRef = useRef<Marker | null>(null);
  // R-121 — rota durağı pinleri (anchor pin deseni) ve fit-zoom tekrar koruması.
  const routeStopMarkersRef = useRef<Marker[]>([]);
  const lastRouteIdRef = useRef<string | null>(null);
  // Harita bir kez kuruluyor; kurulum anındaki padding'i efektin bağımlılık
  // listesine sokmadan okuyabilmek için ref'te tutuyoruz.
  const padLeftRef = useRef(padLeft);
  padLeftRef.current = padLeft;
  // onMapClick her render'da yeni referans olabilir; listener'ı yeniden
  // bağlamak yerine ref üzerinden güncel tutuyoruz.
  const clickHandlerRef = useRef(onMapClick);
  clickHandlerRef.current = onMapClick;
  const propertyClickHandlerRef = useRef(onPropertyClick);
  propertyClickHandlerRef.current = onPropertyClick;
  const selectedLocationChangeHandlerRef = useRef(onSelectedLocationChange);
  selectedLocationChangeHandlerRef.current = onSelectedLocationChange;

  // R-108/109/110 — POI/konut verisi ve kategori adları da listener'lar
  // kurulduktan sonra değişebilir; ref'ler üzerinden güncel tutulur.
  const poiDataRef = useRef<Poi[]>([]);
  poiDataRef.current = pois ?? [];
  const categoryNamesRef = useRef<Record<string, string>>({});
  categoryNamesRef.current = poiCategoryNames ?? {};
  const boundsHandlerRef = useRef(onBoundsChange);
  boundsHandlerRef.current = onBoundsChange;

  const [hoveredName, setHoveredName] = useState<string | null>(null);
  const [status, setStatus] = useState<'yukleniyor' | 'hazir' | 'hata'>('yukleniyor');
  const [errorText, setErrorText] = useState<string | null>(null);

  // ─── Haritayı bir kez kur ───
  useEffect(() => {
    let cancelled = false;
    let map: MapLibreMap | null = null;

    async function setup() {
      try {
        const [districtRaw, neighbourhoods] = await Promise.all([
          fetchGeo(GEO_DISTRICT),
          fetchGeo(GEO_NEIGHBOURHOODS),
        ]);

        // StrictMode geliştirme modunda efekti iki kez çalıştırır; ilk
        // çalıştırmanın isteği dönerse haritayı kurmadan çıkıyoruz.
        if (cancelled || !containerRef.current) return;

        // cankaya.geojson içinde sınır poligonunun yanında bir de etiket
        // node'u (Point) var — dolgu/çizgi katmanları için ayıklıyoruz.
        const district: GeoCollection = {
          type: 'FeatureCollection',
          features: districtRaw.features.filter(
            (f) => f.geometry?.type === 'Polygon' || f.geometry?.type === 'MultiPolygon',
          ),
        };

        const bounds = boundsOf(district);
        const hasBounds = !bounds.isEmpty();

        map = new MapLibreMap({
          container: containerRef.current,
          style: buildStyle(district, neighbourhoods),
          attributionControl: false,
          ...(hasBounds
            ? {
                bounds,
                fitBoundsOptions: {
                  padding: { top: 24, right: 24, bottom: 24, left: 24 + padLeftRef.current },
                },
              }
            : { center: FALLBACK_CENTER, zoom: 10.5 }),
        });
        mapRef.current = map;

        // Ev ikonu `konut-noktalar` katmanının `icon-image`'ı — stil tam
        // yüklenmeden `addImage` "Style is not done loading" ile patlıyor,
        // o yüzden `load` olayını bekliyoruz.
        map.on('load', () => {
          if (!map || map.hasImage('ev-ikon')) return;
          map.addImage('ev-ikon', drawHouseIcon());
        });

        map.addControl(new NavigationControl({ showCompass: false }), 'top-right');
        // ODbL: atıf kapatılamaz olmalı.
        map.addControl(
          new AttributionControl({ compact: false, customAttribution: MAP_ATTRIBUTION }),
          'bottom-right',
        );

        // Sessiz kalmasın: stil/karo hataları ekranda görünsün.
        map.on('error', (e) => {
          console.error('MapLibre hatası', e.error);
          setErrorText(e.error?.message ?? 'Bilinmeyen harita hatası');
        });

        // Kümelenmemiş bir konuta tıklanınca detay açılır; genel harita
        // tıklaması (konum analizi) bu durumda TETİKLENMEMELİ — ikisi aynı
        // canvas üzerinde olduğu için önce konut katmanını sorguluyoruz.
        map.on('click', 'konut-noktalar', (e) => {
          const feature = e.features?.[0];
          const id = feature?.properties?.id as string | undefined;
          if (id) propertyClickHandlerRef.current?.(id);
        });

        // Kümeye tıklayınca o küme açılana kadar yakınlaştır (R-109: "yakınlaştıkça görünür").
        map.on('click', 'konut-kumeleri', (e) => {
          const feature = e.features?.[0];
          const clusterId = feature?.properties?.cluster_id as number | undefined;
          const source = map?.getSource('konutlar') as GeoJSONSource | undefined;
          if (clusterId === undefined || !source || !map) return;

          source.getClusterExpansionZoom(clusterId).then((zoom) => {
            const geometry = feature?.geometry;
            if (!map || !geometry || geometry.type !== 'Point') return;
            const [lon, lat] = geometry.coordinates as [number, number];
            map.easeTo({ center: [lon, lat], zoom, duration: 400 });
          }).catch(() => {});
        });

        for (const layerId of ['konut-kumeleri', 'konut-noktalar']) {
          map.on('mouseenter', layerId, () => {
            const canvas = map?.getCanvas();
            if (canvas) canvas.style.cursor = 'pointer';
          });
          map.on('mouseleave', layerId, () => {
            const canvas = map?.getCanvas();
            if (canvas) canvas.style.cursor = clickHandlerRef.current ? 'crosshair' : '';
          });
        }

        map.on('click', (e) => {
          if (!map) return;
          // POI ya da konut noktası/kümesi tıklanınca analiz/anchor akışı
          // tetiklenmesin; o katmanların kendi dinleyicileri var.
          const hits = map.queryRenderedFeatures(e.point, {
            layers: ['poi-nokta', 'poi-cluster-dolgu', 'konut-kumeleri', 'konut-noktalar'],
          });
          if (hits.length > 0) return;

          clickHandlerRef.current?.({ lat: e.lngLat.lat, lon: e.lngLat.lng });
        });

        // ─── R-108/109/110 — POI & konut etkileşimi (popup, küme zoom'u) ───
        wirePoiInteractions(map, categoryNamesRef);

        // Görünüm alanını yukarı bildir (bbox tabanlı veri çekme). Harita
        // kurulumunda ve her taşımada güncel kalır.
        reportBounds(map, boundsHandlerRef.current);
        map.on('moveend', () => {
          if (map) reportBounds(map, boundsHandlerRef.current);
        });

        // ─── Mahalle vurgulama ───
        let hoveredId: string | number | undefined;

        map.on('mousemove', 'mahalle-dolgu', (e) => {
          const feature = e.features?.[0];
          if (!feature || !map) return;

          if (hoveredId !== undefined) {
            map.setFeatureState({ source: 'mahalleler', id: hoveredId }, { hover: false });
          }
          hoveredId = feature.id;
          map.setFeatureState({ source: 'mahalleler', id: hoveredId }, { hover: true });

          const props = feature.properties as { name?: string; MAHALLE_ADI?: string } | null;
          setHoveredName(props?.name ?? props?.MAHALLE_ADI ?? null);
        });

        map.on('mouseleave', 'mahalle-dolgu', () => {
          if (hoveredId !== undefined && map) {
            map.setFeatureState({ source: 'mahalleler', id: hoveredId }, { hover: false });
          }
          hoveredId = undefined;
          setHoveredName(null);
        });

        setStatus('hazir');
      } catch (err) {
        console.error('Çankaya GeoJSON katmanları yüklenemedi', err);
        if (!cancelled) {
          setErrorText(err instanceof Error ? err.message : String(err));
          setStatus('hata');
        }
      }
    }

    void setup();

    return () => {
      cancelled = true;
      analysisMarkerRef.current?.remove();
      analysisMarkerRef.current = null;
      map?.remove();
      mapRef.current = null;
    };
  }, []);


  // ── Kullanıcının GPS konumu ──
useEffect(() => {
  if (!navigator.geolocation) return;

  navigator.geolocation.getCurrentPosition(
    (position) => {
      const lat = position.coords.latitude;
      const lon = position.coords.longitude;

      const map = mapRef.current;
      if (!map) return;

      const el = document.createElement('div');
      el.className = 'user-location-marker';

      userLocationMarkerRef.current?.remove();

      userLocationMarkerRef.current = new Marker({ element: el })
        .setLngLat([lon, lat])
        .setPopup(
          new Popup({ offset: 16 }).setText('Mevcut konum')
        )
        .addTo(map);
    },
    (error) => {
      console.warn('Konum alınamadı:', error.message);
    }
  );
}, []);
  
  // ─── İşaretçiler (anchor'lar) ───
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    for (const m of markerObjectsRef.current) m.remove();
    markerObjectsRef.current = [];

    for (const marker of markers) {
      const el = document.createElement('div');
      el.className = marker.className ?? 'map-pin';
      el.textContent = marker.text ?? (marker.priority ? String(marker.priority) : '•');
      el.title = marker.label;

      markerObjectsRef.current.push(
        new Marker({ element: el }).setLngLat([marker.lon, marker.lat]).addTo(map),
      );
    }

    if (focus) {
      const el = document.createElement('div');
      el.className = 'map-pin map-pin--search';
      el.textContent = '⌖';
      el.title = focus.label;
      markerObjectsRef.current.push(
        new Marker({ element: el }).setLngLat([focus.lon, focus.lat]).addTo(map),
      );
    }
    // `status` bağımlılığı şart: harita asenkron kurulduğu için ilk render'da
    // mapRef henüz boş olabiliyor, hazır olunca işaretçiler yeniden basılır.
  }, [markers, focus, status]);

  // Analiz ve yürüme alanlarının ortak merkezi. İşaretçi sürüklendiğinde iki alan
  // da aynı state üzerinden yeni konumda yeniden hesaplanır.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || status !== 'hazir') return;

    if (!selectedLocation) {
      analysisMarkerRef.current?.remove();
      analysisMarkerRef.current = null;
      return;
    }

    let marker = analysisMarkerRef.current;
    if (!marker) {
      const element = document.createElement('div');
      element.className = 'map-pin map-pin--analysis';
      element.textContent = '↕';
      element.title = 'Analiz konumunu sürükle';

      marker = new Marker({ element, draggable: true })
        .setLngLat([selectedLocation.lon, selectedLocation.lat])
        .addTo(map);
      marker.on('drag', () => {
        const location = marker?.getLngLat();
        if (location) {
          selectedLocationChangeHandlerRef.current?.({ lat: location.lat, lon: location.lng });
        }
      });
      analysisMarkerRef.current = marker;
    } else {
      marker.setLngLat([selectedLocation.lon, selectedLocation.lat]);
    }
  }, [selectedLocation, status]);

  // ─── Konum arama sonucu ───
  useEffect(() => {
    const map = mapRef.current;
    if (!map || status !== 'hazir' || !focus) return;

    if (focus.bounds) {
      map.fitBounds(
        [
          [focus.bounds.west, focus.bounds.south],
          [focus.bounds.east, focus.bounds.north],
        ],
        { padding: 56, maxZoom: 16, duration: 700 },
      );
    } else {
      map.flyTo({ center: [focus.lon, focus.lat], zoom: 16, duration: 700 });
    }
  }, [focus, status]);

  // ─── Konut noktaları (cluster kaynağı) ───
  useEffect(() => {
    const source = mapRef.current?.getSource('konutlar') as GeoJSONSource | undefined;
    if (!source) return;

    source.setData({
      type: 'FeatureCollection',
      features: properties.map((p) => ({
        type: 'Feature',
        properties: { id: p.id },
        geometry: { type: 'Point', coordinates: [p.lon, p.lat] },
      })),
    });
    // `status` şart: kaynak asenkron kurulur, harita hazır olmadan `getSource` boş döner.
  }, [properties, status]);

  // ─── R-121 — rota çizgisi (`rota` GeoJSON kaynağına setData) ───
  useEffect(() => {
    const source = mapRef.current?.getSource('rota') as GeoJSONSource | undefined;
    if (!source || status !== 'hazir') return;

    const coords = route?.geometry.coordinates ?? [];
    source.setData({
      type: 'FeatureCollection',
      features:
        coords.length >= 2
          ? [
              {
                type: 'Feature',
                properties: {},
                geometry: { type: 'LineString', coordinates: coords },
              },
            ]
          : [],
    });
  }, [route, status]);

  // ─── R-121 — numaralı durak pinleri (anchor `map-pin` deseni yeniden kullanılır) ───
  useEffect(() => {
    const map = mapRef.current;
    if (!map || status !== 'hazir') return;

    for (const m of routeStopMarkersRef.current) m.remove();
    routeStopMarkersRef.current = [];

    if (!route) return;

    for (const stop of route.stops) {
      const el = document.createElement('div');
      el.className = 'map-pin map-pin--route';
      el.textContent = String(stop.seq);
      el.title = `${stop.seq}. durak · ${stop.property.roomCount} · ${stop.property.neighborhood ?? ''}`;

      routeStopMarkersRef.current.push(
        new Marker({ element: el })
          .setLngLat([stop.property.lon, stop.property.lat])
          .setPopup(new Popup({ offset: 24, closeButton: false }).setHTML(routeStopPopupHtml(stop)))
          .addTo(map),
      );
    }
  }, [route, status]);

  // ─── R-121 — rota değişince tamamını görünüme sığdır (her rota id'si bir kez) ───
  useEffect(() => {
    const map = mapRef.current;
    if (!map || status !== 'hazir') return;

    if (!route) {
      lastRouteIdRef.current = null;
      return;
    }
    if (lastRouteIdRef.current === route.id) return;
    lastRouteIdRef.current = route.id;

    const coords = route.geometry.coordinates;
    if (coords.length === 0) return;

    const bounds = new LngLatBounds();
    for (const coord of coords) bounds.extend(coord);
    map.fitBounds(bounds, {
      padding: { top: 80, right: 80, bottom: 80, left: 80 + padLeftRef.current },
      maxZoom: 15,
      duration: 900,
    });
  }, [route, status]);

  // İmleci tıklanabilirlik durumuna göre değiştir.
  useEffect(() => {
    const canvas = mapRef.current?.getCanvas();
    if (canvas) canvas.style.cursor = onMapClick ? 'crosshair' : '';
  }, [onMapClick, status]);

  /**
   * Panel açılıp kapandıkça haritayı yatayda kaydırır.
   *
   * Neden `setPadding`/`easeTo({padding})` DEĞİL: `fitBoundsOptions.padding`
   * yalnızca ilk yerleştirmenin HESABINA girer, haritanın kalıcı padding'ini
   * ayarlamaz. İkisini karıştırınca kurulumda dolgu iki kez sayılıp ilçe
   * kırpılıyor, panel kapanınca da harita yerinde kalıyordu (ikisi de
   * görüldü).
   *
   * `panBy` yakınlaştırmayı ve kullanıcının kendi kaydırmasını korur:
   * yalnızca örtülen genişliğin yarısı kadar öteler. Süre panelin CSS
   * geçişiyle (0.22s) aynı — ikisi birlikte hareket etsin.
   */
  const previousPadRef = useRef(padLeft);
  useEffect(() => {
    const map = mapRef.current;
    if (!map || status !== 'hazir') return;

    const delta = padLeft - previousPadRef.current;
    previousPadRef.current = padLeft;
    if (delta === 0) return;

    map.panBy([-delta / 2, 0], { duration: 220 });
  }, [padLeft, status]);

  useEffect(() => {
    const source = mapRef.current?.getSource('yurume-alani') as GeoJSONSource | undefined;
    const analysisSource = mapRef.current?.getSource('analiz-alani') as GeoJSONSource | undefined;
    const centreSource = mapRef.current?.getSource('yurume-merkezi') as GeoJSONSource | undefined;
    if (!source || !analysisSource || !centreSource) return;

    source.setData({
      type: 'FeatureCollection',
      features: selectedLocation
        ? [createWalkingAccessibilityPolygon(selectedLocation, walkingMinutes)]
        : [],
    });
    analysisSource.setData({
      type: 'FeatureCollection',
      features: selectedLocation
        ? [createAnalysisAreaPolygon(selectedLocation, analysisRadiusKm)]
        : [],
    });
    centreSource.setData({
      type: 'FeatureCollection',
      features: selectedLocation
        ? [{
            type: 'Feature',
            properties: {},
            geometry: {
              type: 'Point',
              coordinates: [selectedLocation.lon, selectedLocation.lat],
            },
          }]
        : [],
    });
  }, [analysisRadiusKm, selectedLocation, walkingMinutes, status]);

  // ─── R-108 — POI verisi geldikçe kaynağı güncelle ───
  // Kaynaklar buildStyle'da kurulur; burada yalnızca setData ile veri değişir.
  useEffect(() => {
    const map = mapRef.current;
    if (!map || status !== 'hazir') return;

    const poiSource = map.getSource('pois') as GeoJSONSource | undefined;
    poiSource?.setData(toPoiFeatureCollection(poiDataRef.current) as never);
  }, [pois, status]);

  return (
    <div className="map-wrap" style={{ height }}>
      <div ref={containerRef} className="map-canvas" />

      {status === 'yukleniyor' && (
        <div className="map-note">Çankaya katmanları yükleniyor…</div>
      )}
      {status === 'hata' && (
        <div className="map-note map-note--error">
          Harita yüklenemedi: {errorText ?? 'bilinmeyen hata'}
        </div>
      )}
      {hoveredName && <div className="map-hover-badge">{hoveredName}</div>}
    </div>
  );
}

async function fetchGeo(url: string): Promise<GeoCollection> {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`${url} → HTTP ${response.status}`);
  return (await response.json()) as GeoCollection;
}
