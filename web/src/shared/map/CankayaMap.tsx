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
import type { MapProperty, Poi } from '@vivido/shared';
import { POI_CATEGORY_COLORS, POI_FALLBACK_COLOR, poiCategoryColor } from './poiColors';

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
}

export interface MapFocus extends MapPoint {
  id: string;
  label: string;
  bounds?: { south: number; west: number; north: number; east: number } | null;
}

/** Haritanın görünüm alanı (R-108/109 — bbox bazlı veri çekme için). */
export interface MapBounds {
  south: number;
  west: number;
  north: number;
  east: number;
}

interface CankayaMapProps {
  /** Verilirse haritaya tıklanabilir hale gelir (anchor ekleme akışı). */
  onMapClick?: (point: MapPoint) => void;
  markers?: MapMarker[];
  /** Arama sonucu değiştiğinde haritayı bu konuma taşır. */
  focus?: MapFocus | null;
  /** Harita kabının yüksekliği (CSS değeri). */
  height?: string;
  /**
   * R-108/109/110 — haritada gösterilecek POI'ler (kategori filtresi API'de
   * uygulanmış halde gelir; burada yalnızca çizilir).
   */
  pois?: Poi[];
  /** R-109/110 — haritada gösterilecek konutlar. */
  properties?: MapProperty[];
  /** POI popup'ında Türkçe kategori adı göstermek için kod → ad haritası. */
  poiCategoryNames?: Record<string, string>;
  /** Harita taşındığında görünüm alanını (bbox) yukarı bildirir. */
  onBoundsChange?: (bounds: MapBounds) => void;
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

function buildStyle(district: GeoCollection, neighbourhoods: GeoCollection): MapStyle {
  const sources: Record<string, unknown> = {
    ilce: { type: 'geojson', data: district },
    // feature-state ile hover boyaması yapabilmek için id şart.
    mahalleler: { type: 'geojson', data: neighbourhoods, generateId: true },
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
  );

  // Etiketler her şeyin üstünde kalmalı.
  if (hasVectorTiles) layers.push(...vectorLabelLayers());

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

// ─────────────────────────────────────────────────────────────────────────
//  R-108/109/110 — POI & konut katmanları
//
//  Zoom kuralı (R-109): z < 14'te noktalar küme (cluster) olarak çizilir,
//  z ≥ 14'te tekil noktalar görünür. Katmanlardaki `maxzoom`/`minzoom` ve
//  kaynağın `clusterMaxZoom: 14` değeri bu geçişi sağlar.
//
//  Veri filtreleme (kategori + bbox) API'de yapılır; buraya yalnızca çizime
//  hazır veri gelir.
// ─────────────────────────────────────────────────────────────────────────

const EMPTY_COLLECTION: GeoCollection = { type: 'FeatureCollection', features: [] };

/** POI listesini MapLibre GeoJSON kaynağına çevirir. */
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

/** Konut listesini MapLibre GeoJSON kaynağına çevirir. */
function toPropertyFeatureCollection(properties: MapProperty[]): GeoCollection {
  return {
    type: 'FeatureCollection',
    features: properties.map((p) => ({
      type: 'Feature',
      properties: {
        id: p.id,
        externalRef: p.externalRef,
        monthlyRent: p.monthlyRent,
        areaM2: p.areaM2,
        roomCount: p.roomCount,
        buildingAge: p.buildingAge,
        hasElevator: p.hasElevator,
        isSynthetic: p.isSynthetic,
      },
      geometry: { type: 'Point', coordinates: [p.longitude, p.latitude] },
    })),
  };
}

/** POI nokta rengi: kategori bazlı `match` ifadesi. */
function poiCategoryColorExpression(): unknown {
  const pairs = Object.entries(POI_CATEGORY_COLORS).flat();
  return ['match', ['get', 'category'], ...pairs, POI_FALLBACK_COLOR];
}

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

/** POI/konut kaynaklarını ve katmanlarını bir kez kurar (idempotent). */
function ensurePoiLayers(map: MapLibreMap): void {
  if (map.getSource('pois')) return;

  map.addSource('pois', {
    type: 'geojson',
    data: EMPTY_COLLECTION,
    cluster: true,
    clusterRadius: 50,
    clusterMaxZoom: 14,
    generateId: true,
  } as never);
  map.addSource('properties', {
    type: 'geojson',
    data: EMPTY_COLLECTION,
    cluster: true,
    clusterRadius: 40,
    clusterMaxZoom: 14,
    generateId: true,
  } as never);

  // ── POI katmanları (R-108: kategori rengi, R-109: zoom kuralı) ──
  map.addLayer(clusterFillLayer('poi-cluster-dolgu', 'pois', '#7c3aed') as never);
  map.addLayer(clusterCountLayer('poi-cluster-sayi', 'pois') as never);
  map.addLayer({
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
  } as never);

  // ── Konut katmanları (R-109/R-110) ──
  map.addLayer(clusterFillLayer('konut-cluster-dolgu', 'properties', '#c2410c') as never);
  map.addLayer(clusterCountLayer('konut-cluster-sayi', 'properties') as never);
  map.addLayer({
    id: 'konut-nokta',
    type: 'circle',
    source: 'properties',
    filter: ['!', ['has', 'point_count']],
    minzoom: 14,
    paint: {
      'circle-radius': 5.5,
      'circle-color': '#c2410c',
      'circle-stroke-color': '#ffffff',
      'circle-stroke-width': 1.5,
    },
  } as never);
}

/** POI/konut verisi değiştiğinde GeoJSON kaynaklarını günceller. */
function updatePointSources(map: MapLibreMap, pois: Poi[], properties: MapProperty[]): void {
  if (!map.isStyleLoaded()) return;
  ensurePoiLayers(map);

  const poiSource = map.getSource('pois') as GeoJSONSource | undefined;
  poiSource?.setData(toPoiFeatureCollection(pois) as never);

  const propertySource = map.getSource('properties') as GeoJSONSource | undefined;
  propertySource?.setData(toPropertyFeatureCollection(properties) as never);
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
      <div class="vivido-popup-meta">Kategori kodu: ${escapeHtml(categoryCode)}</div>
    </div>`;
}

/** R-110 — konut popup içeriği (kira, oda, alan, bina yaşı, asansör). */
function propertyPopupHtml(props: Record<string, unknown>): string {
  const rent = typeof props.monthlyRent === 'number'
    ? `${props.monthlyRent.toLocaleString('tr-TR')} ₺/ay`
    : 'kira bilinmiyor';
  const area = typeof props.areaM2 === 'number' ? `${props.areaM2} m²` : '';
  const rooms = String(props.roomCount ?? '');
  const age = typeof props.buildingAge === 'number' ? `${props.buildingAge} yıl` : 'bilinmiyor';
  const lift = props.hasElevator ? 'var' : 'yok';

  return `
    <div class="vivido-popup">
      <div class="vivido-popup-title">${escapeHtml(String(props.externalRef ?? 'Konut'))}</div>
      <div class="vivido-popup-meta">${escapeHtml(rooms)}${rooms && area ? ' · ' : ''}${escapeHtml(area)}</div>
      <div class="vivido-popup-meta vivido-popup-rent">${escapeHtml(rent)}</div>
      <div class="vivido-popup-meta">Bina yaşı: ${escapeHtml(age)} · Asansör: ${escapeHtml(lift)}</div>
    </div>`;
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

/** POI/konut etkileşimlerini bir kez bağlar: imleç, popup, küme zoom'u. */
function wirePoiInteractions(
  map: MapLibreMap,
  categoryNames: React.MutableRefObject<Record<string, string>>,
): void {
  const hoverLayers = ['poi-nokta', 'konut-nokta', 'poi-cluster-dolgu', 'konut-cluster-dolgu'];
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

  // R-110 — konut popup'ı
  map.on('click', 'konut-nokta', (e) => {
    const feature = e.features?.[0];
    if (!feature || !map) return;
    const coordinates = (feature.geometry as { coordinates?: [number, number] }).coordinates;
    if (!coordinates) return;

    new Popup({ offset: 18, closeButton: false })
      .setLngLat(coordinates)
      .setHTML(propertyPopupHtml(feature.properties as Record<string, unknown>))
      .addTo(map);
  });

  // R-109 — küme tıklaması: yakınlaş
  map.on('click', 'poi-cluster-dolgu', (e) => {
    const feature = e.features?.[0];
    if (feature) zoomToCluster(map, 'pois', feature);
  });
  map.on('click', 'konut-cluster-dolgu', (e) => {
    const feature = e.features?.[0];
    if (feature) zoomToCluster(map, 'properties', feature);
  });
}

/** Görünüm alanını (bbox) yukarı bildirir (R-108 — bbox bazlı veri çekme). */
function reportBounds(map: MapLibreMap, cb?: (bounds: MapBounds) => void): void {
  if (!cb) return;
  const b = map.getBounds();
  cb({ south: b.getSouth(), west: b.getWest(), north: b.getNorth(), east: b.getEast() });
}

export function CankayaMap({
  onMapClick,
  markers = [],
  focus,
  height = '100%',
  pois,
  properties,
  poiCategoryNames,
  onBoundsChange,
}: CankayaMapProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const markerObjectsRef = useRef<Marker[]>([]);
  // onMapClick her render'da yeni referans olabilir; listener'ı yeniden
  // bağlamak yerine ref üzerinden güncel tutuyoruz.
  const clickHandlerRef = useRef(onMapClick);
  clickHandlerRef.current = onMapClick;

  // R-108/109/110 — POI/konut verisi ve kategori adları da listener'lar
  // kurulduktan sonra değişebilir; ref'ler üzerinden güncel tutulur.
  const poiDataRef = useRef<Poi[]>([]);
  poiDataRef.current = pois ?? [];
  const propertyDataRef = useRef<MapProperty[]>([]);
  propertyDataRef.current = properties ?? [];
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
            ? { bounds, fitBoundsOptions: { padding: 24 } }
            : { center: FALLBACK_CENTER, zoom: 10.5 }),
        });
        mapRef.current = map;

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

        map.on('click', (e) => {
          clickHandlerRef.current?.({ lat: e.lngLat.lat, lon: e.lngLat.lng });
        });

        // ─── R-108/109/110: POI & konut katmanları, popup, bbox bildirimi ───
        map.on('load', () => {
          if (!map) return;
          updatePointSources(map, poiDataRef.current, propertyDataRef.current);
          reportBounds(map, boundsHandlerRef.current);
        });
        map.on('moveend', () => {
          if (map) reportBounds(map, boundsHandlerRef.current);
        });
        wirePoiInteractions(map, categoryNamesRef);

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
      map?.remove();
      mapRef.current = null;
    };
  }, []);

  // ─── İşaretçiler (anchor'lar) ───
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    for (const m of markerObjectsRef.current) m.remove();
    markerObjectsRef.current = [];

    for (const marker of markers) {
      const el = document.createElement('div');
      el.className = 'map-pin';
      el.textContent = marker.priority ? String(marker.priority) : '•';
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

  // ─── R-108/109/110: POI & konut verisi değişince GeoJSON kaynaklarını güncelle ───
  useEffect(() => {
    const map = mapRef.current;
    if (!map || status !== 'hazir') return;
    // Stil yüklenmediyse kaynak eklenemez; `load` handler'ı da bu fonksiyonu
    // çağırdığı için veri burada kaybolmaz.
    updatePointSources(map, poiDataRef.current, propertyDataRef.current);
  }, [pois, properties, status]);

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

  // İmleci tıklanabilirlik durumuna göre değiştir.
  useEffect(() => {
    const canvas = mapRef.current?.getCanvas();
    if (canvas) canvas.style.cursor = onMapClick ? 'crosshair' : '';
  }, [onMapClick, status]);

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
