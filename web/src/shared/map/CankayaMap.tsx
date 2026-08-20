import { useEffect, useRef, useState } from 'react';
// maplibre-gl v6'nın default export'u YOK — adlandırılmış import şart.
import {
  AttributionControl,
  LngLatBounds,
  Map as MapLibreMap,
  Marker,
  NavigationControl,
  type MapOptions,
} from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import { MAP_ATTRIBUTION, USE_RASTER_BASEMAP } from '@/shared/config';

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

interface CankayaMapProps {
  /** Verilirse haritaya tıklanabilir hale gelir (anchor ekleme akışı). */
  onMapClick?: (point: MapPoint) => void;
  markers?: MapMarker[];
  /** Harita kabının yüksekliği (CSS değeri). */
  height?: string;
}

const GEO_DISTRICT = '/geo/cankaya.geojson';
const GEO_NEIGHBOURHOODS = '/geo/cankaya-mahalleler.geojson';

/** Çankaya kaba bbox — sınır verisi okunamazsa kullanılacak yedek görünüm. */
const FALLBACK_CENTER: [number, number] = [32.85, 39.87];

function buildStyle(district: GeoCollection, neighbourhoods: GeoCollection): MapStyle {
  const sources: Record<string, unknown> = {
    ilce: { type: 'geojson', data: district },
    // feature-state ile hover boyaması yapabilmek için id şart.
    mahalleler: { type: 'geojson', data: neighbourhoods, generateId: true },
  };

  const layers: unknown[] = [
    { id: 'arka-plan', type: 'background', paint: { 'background-color': '#eef2f0' } },
  ];

  if (USE_RASTER_BASEMAP) {
    sources.osm = {
      type: 'raster',
      tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
      tileSize: 256,
      maxzoom: 19,
      attribution: MAP_ATTRIBUTION,
    };
    layers.push({ id: 'osm', type: 'raster', source: 'osm' });
  } else {
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
          USE_RASTER_BASEMAP ? 0.18 : 0.35,
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

  // Stil koşullu kurulduğu için TypeScript `type: 'raster'` gibi alanları
  // string-literal birleşimine daraltamıyor. Tek noktada dönüştürüyoruz;
  // şekil MapLibre style-spec v8 ile birebir uyumlu (validateStyleMin: 0 hata).
  return { version: 8, sources, layers } as MapStyle;
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

export function CankayaMap({ onMapClick, markers = [], height = '100%' }: CankayaMapProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const markerObjectsRef = useRef<Marker[]>([]);
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
    // `status` bağımlılığı şart: harita asenkron kurulduğu için ilk render'da
    // mapRef henüz boş olabiliyor, hazır olunca işaretçiler yeniden basılır.
  }, [markers, status]);

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
