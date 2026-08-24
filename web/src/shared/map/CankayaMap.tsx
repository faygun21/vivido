import { useEffect, useRef, useState } from 'react';
// maplibre-gl v6'nın default export'u YOK — adlandırılmış import şart.
import {
  AttributionControl,
  LngLatBounds,
  Map as MapLibreMap,
  Marker,
  NavigationControl,
  setWorkerUrl,
  type GeoJSONSource,
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

interface CankayaMapProps {
  /** Verilirse haritaya tıklanabilir hale gelir (anchor ekleme akışı). */
  onMapClick?: (point: MapPoint) => void;
  markers?: MapMarker[];
  /** Arama sonucu değiştiğinde haritayı bu konuma taşır. */
  focus?: MapFocus | null;
  /** Harita kabının yüksekliği (CSS değeri). */
  height?: string;
  selectedLocation?: WalkingLocation | null;
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

export function CankayaMap({
  onMapClick,
  markers = [],
  focus,
  height = '100%',
  selectedLocation = null,
  walkingMinutes = 15,
  analysisRadiusKm = 2,
  padLeft = 0,
}: CankayaMapProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const markerObjectsRef = useRef<Marker[]>([]);
  // Harita bir kez kuruluyor; kurulum anındaki padding'i efektin bağımlılık
  // listesine sokmadan okuyabilmek için ref'te tutuyoruz.
  const padLeftRef = useRef(padLeft);
  padLeftRef.current = padLeft;
  // onMapClick her render'da yeni referans olabilir; listener'ı yeniden
  // bağlamak yerine ref üzerinden güncel tutuyoruz.
  const clickHandlerRef = useRef(onMapClick);
  clickHandlerRef.current = onMapClick;

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
