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
  type MapOptions,
} from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
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
import type { UserLocation } from './useUserLocation';
import type { AnchorSweetSpotResult } from './anchorSweetSpot';
import type { Poi, RouteDetail, RouteStop } from '@vivido/shared';
import { poiCategoryColor, POI_CATEGORY_COLORS, POI_FALLBACK_COLOR } from './poiColors';

setWorkerUrl(maplibreWorkerUrl);

type MapStyle = NonNullable<MapOptions['style']>;

interface GeoFeature {
  type: 'Feature';
  properties: Record<string, unknown> | null;
  geometry: { type: string; coordinates: unknown } | null;
}
interface GeoCollection {
  type: 'FeatureCollection';
  features: GeoFeature[];
}

export interface MapPoint {
  lat: number;
  lon: number;
}

export interface MapMarker extends MapPoint {
  id: string;
  label: string;
  priority?: number;
  className?: string;
  text?: string;
}

export interface MapFocus extends MapPoint {
  id: string;
  label: string;
  bounds?: { south: number; west: number; north: number; east: number } | null;
}

export interface MapBounds {
  south: number;
  west: number;
  north: number;
  east: number;
}

export interface PropertyPoint extends MapPoint {
  id: string;
}

interface CankayaMapProps {
  onMapClick?: (point: MapPoint) => void;
  onPropertyClick?: (id: string) => void;
  markers?: MapMarker[];
  properties?: PropertyPoint[];
  focus?: MapFocus | null;
  height?: string;
  selectedLocation?: WalkingLocation | null;
  onSelectedLocationChange?: (location: WalkingLocation) => void;
  walkingMinutes?: WalkingMinutes;
  analysisRadiusKm?: AnalysisRadiusKm;
  padLeft?: number;
  pois?: Poi[];
  poiCategoryNames?: Record<string, string>;
  onBoundsChange?: (bounds: MapBounds) => void;
  userLocation?: UserLocation | null;
  route?: RouteDetail | null;
  anchorArea?: AnchorSweetSpotResult | null;
}

const GEO_DISTRICT = '/geo/cankaya.geojson';
const GEO_NEIGHBOURHOODS = '/geo/cankaya-mahalleler.geojson';
const FALLBACK_CENTER: [number, number] = [32.85, 39.87];

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

/** Sol menüdeki mantıkla birebir aynı çalışan ikon belirleme fonksiyonu. */
function getCategoryIconPath(code: string, name?: string): string {
  const lowerCode = (code || '').toLowerCase();
  const lowerName = (name || '').toLowerCase();

  if (
    lowerCode.includes('cafe') || 
    lowerCode.includes('kafe') || 
    lowerCode.includes('restaurant') || 
    lowerCode.includes('restoran') ||
    lowerCode.includes('coffee') ||
    lowerCode.includes('food') ||
    lowerCode.includes('dining') ||
    lowerName.includes('kafe') ||
    lowerName.includes('restoran')
  ) {
    return '/cafe.svg';
  }

  if (
    lowerCode.includes('bus') || 
    lowerCode.includes('durak') || 
    lowerCode.includes('transport') || 
    lowerCode.includes('transit') || 
    lowerCode.includes('ulasim')
  ) {
    return '/bus.svg';
  }

  if (
    lowerCode.includes('hastane') || 
    lowerCode.includes('hospital') || 
    lowerCode.includes('saglik') || 
    lowerCode.includes('health') || 
    lowerCode.includes('asm') || 
    lowerCode.includes('eczane') ||
    lowerCode.includes('pharmacy') ||
    lowerCode.includes('drugstore') ||
    lowerName.includes('eczane') ||
    lowerName.includes('hastane')
  ) {
    return '/hastane.svg';
  }

  if (
    lowerCode.includes('park') || 
    lowerCode.includes('yesil') || 
    lowerCode.includes('green')
  ) {
    return '/park.svg';
  }

  if (
    lowerCode.includes('school') || 
    lowerCode.includes('okul') || 
    lowerCode.includes('education') || 
    lowerCode.includes('egitim')
  ) {
    return '/kep_kahve.svg';
  }

  if (
    lowerCode.includes('sport') || 
    lowerCode.includes('spor') || 
    lowerCode.includes('gym')
  ) {
    return '/sport_kahve.svg';
  }

  if (
    lowerCode.includes('market') || 
    lowerCode.includes('avm') || 
    lowerCode.includes('supermarket') || 
    lowerCode.includes('alisveris')
  ) {
    return '/avm.svg';
  }

  return '/icons.svg';
}

/**
 * Sol menüdeki SVG'leri harita motoruna imaj olarak kaydeder.
 */
function loadCustomMapImages(map: MapLibreMap) {
  const addSvgIcon = (id: string, url: string) => {
    if (map.hasImage(id)) return;
    
    // Tarayıcının SVG decode hatasını atlatmak için belirli boyutla native Image kullanıyoruz
    const img = new Image(32, 32); 
    img.onload = () => {
      if (!map.hasImage(id)) {
        map.addImage(id, img);
      }
    };
    img.onerror = () => console.warn(`Harita ikonu yüklenemedi: ${url}`);
    img.src = url;
  };

  // 1. Konutlar için ev ikonu
  addSvgIcon('ev-ikon', '/home_kahve.svg');

  // 2. Diğer POI ikonları
  const uniquePaths = [
    '/cafe.svg',
    '/bus.svg',
    '/hastane.svg',
    '/park.svg',
    '/kep_kahve.svg',
    '/sport_kahve.svg',
    '/avm.svg',
    '/icons.svg',
  ];

  for (const path of uniquePaths) {
    addSvgIcon(`svg-icon-${path}`, path);
  }
}

function buildStyle(district: GeoCollection, neighbourhoods: GeoCollection): MapStyle {
  const sources: Record<string, unknown> = {
    ilce: { type: 'geojson', data: district },
    mahalleler: { type: 'geojson', data: neighbourhoods, generateId: true },
    'yurume-alani': {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    },
    'analiz-alani': {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    },
    'anchor-alani': {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    },
    'yurume-merkezi': {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    },
    pois: {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
      cluster: true,
      clusterRadius: 50,
      clusterMaxZoom: 14,
      generateId: true,
    },
    konutlar: {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
      cluster: true,
      clusterMaxZoom: 15,
      clusterRadius: 45,
    },
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
    // Anchor'lardan (özel yerler) hesaplanan arama alanı — diğer iki
    // dairelerden ayırt edilsin diye mor.
    {
      id: 'anchor-alani-dolgu',
      type: 'fill',
      source: 'anchor-alani',
      paint: { 'fill-color': '#7c3aed', 'fill-opacity': 0.08 },
    },
    {
      id: 'anchor-alani-cizgi',
      type: 'line',
      source: 'anchor-alani',
      paint: { 'line-color': '#6d28d9', 'line-width': 2, 'line-dasharray': [4, 2] },
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
          16,
          25, 20,
          100, 26,
          500, 32,
        ],
      },
    },
    // 🔥 Konutların turuncu arka plan dairesi
    {
      id: 'konut-noktalar-arkaplan',
      type: 'circle',
      source: 'konutlar',
      filter: ['!', ['has', 'point_count']],
      paint: {
        'circle-color': '#ea580c',
        'circle-radius': 14,
        'circle-stroke-width': 2,
        'circle-stroke-color': '#fff',
      },
    },
    // 🔥 Konutların SVG ikonu (dairenin tam ortasına oturan)
    {
      id: 'konut-noktalar',
      type: 'symbol',
      source: 'konutlar',
      filter: ['!', ['has', 'point_count']],
      layout: {
        'icon-image': 'ev-ikon',
        'icon-size': 0.6,
        'icon-allow-overlap': true,
      },
    },
    // POI Katmanı (Mevcut yapısı korundu)
    {
      id: 'poi-nokta',
      type: 'symbol',
      source: 'pois',
      filter: ['!', ['has', 'point_count']],
      minzoom: 14,
      layout: {
        'icon-image': ['concat', 'svg-icon-', ['get', 'iconPath']],
        'icon-size': 0.8,
        'icon-allow-overlap': true,
      },
    },
  );

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

  if (hasVectorTiles) layers.push(...vectorLabelLayers());

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

  return {
    version: 8,
    ...(hasVectorTiles ? { glyphs: GLYPHS_URL } : {}),
    sources,
    layers,
  } as MapStyle;
}

function boundsOf(geojson: GeoCollection): LngLatBounds {
  const bounds = new LngLatBounds();

  const visit = (coords: unknown): void => {
    if (!Array.isArray(coords)) return;
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

function toPoiFeatureCollection(pois: Poi[], categoryNames?: Record<string, string>): GeoCollection {
  return {
    type: 'FeatureCollection',
    features: pois.map((poi) => {
      const displayNameTr = categoryNames?.[poi.categoryCode] || poi.categoryCode;
      const iconPath = getCategoryIconPath(poi.categoryCode, displayNameTr);
      return {
        type: 'Feature',
        properties: {
          id: poi.id,
          name: poi.name,
          category: poi.categoryCode,
          iconPath: iconPath,
        },
        geometry: { type: 'Point', coordinates: [poi.longitude, poi.latitude] },
      };
    }),
  };
}

function wirePoiInteractions(
  map: MapLibreMap,
  categoryNames: { current: Record<string, string> },
): void {
  map.on('mouseenter', 'poi-nokta', () => { map.getCanvas().style.cursor = 'pointer'; });
  map.on('mouseleave', 'poi-nokta', () => { map.getCanvas().style.cursor = ''; });

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
}

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
  userLocation = null,
  route = null,
  anchorArea = null,
}: CankayaMapProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const markerObjectsRef = useRef<Marker[]>([]);
  const analysisMarkerRef = useRef<Marker | null>(null);
  const userLocationMarkerRef = useRef<Marker | null>(null);
  const routeStopMarkersRef = useRef<Marker[]>([]);
  const lastRouteIdRef = useRef<string | null>(null);
  const padLeftRef = useRef(padLeft);
  padLeftRef.current = padLeft;
  const clickHandlerRef = useRef(onMapClick);
  clickHandlerRef.current = onMapClick;
  const propertyClickHandlerRef = useRef(onPropertyClick);
  propertyClickHandlerRef.current = onPropertyClick;
  const selectedLocationChangeHandlerRef = useRef(onSelectedLocationChange);
  selectedLocationChangeHandlerRef.current = onSelectedLocationChange;

  const poiDataRef = useRef<Poi[]>([]);
  poiDataRef.current = pois ?? [];
  const categoryNamesRef = useRef<Record<string, string>>({});
  categoryNamesRef.current = poiCategoryNames ?? {};
  const boundsHandlerRef = useRef(onBoundsChange);
  boundsHandlerRef.current = onBoundsChange;

  const [hoveredName, setHoveredName] = useState<string | null>(null);
  const [status, setStatus] = useState<'yukleniyor' | 'hazir' | 'hata'>('yukleniyor');
  const [errorText, setErrorText] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    let map: MapLibreMap | null = null;

    async function setup() {
      try {
        const [districtRaw, neighbourhoods] = await Promise.all([
          fetchGeo(GEO_DISTRICT),
          fetchGeo(GEO_NEIGHBOURHOODS),
        ]);

        if (cancelled || !containerRef.current) return;

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

        map.on('load', () => {
          if (!map) return;
          loadCustomMapImages(map);
        });

        const markReady = () => {
          if (!cancelled) setStatus('hazir');
        };
        if (map.isStyleLoaded()) markReady();
        else map.once('load', markReady);

        map.addControl(new NavigationControl({ showCompass: false }), 'top-right');
        map.addControl(
          new AttributionControl({ compact: false, customAttribution: MAP_ATTRIBUTION }),
          'bottom-right',
        );

        map.on('error', (e) => {
          console.error('MapLibre hatası', e.error);
          setErrorText(e.error?.message ?? 'Bilinmeyen harita hatası');
        });

        map.on('click', 'konut-noktalar-arkaplan', (e) => {
          const feature = e.features?.[0];
          const id = feature?.properties?.id as string | undefined;
          if (id) propertyClickHandlerRef.current?.(id);
        });

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

        for (const layerId of ['konut-kumeleri', 'konut-noktalar-arkaplan', 'konut-noktalar']) {
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
          const hits = map.queryRenderedFeatures(e.point, {
            layers: ['poi-nokta', 'konut-kumeleri', 'konut-noktalar-arkaplan', 'konut-noktalar'],
          });
          if (hits.length > 0) return;

          clickHandlerRef.current?.({ lat: e.lngLat.lat, lon: e.lngLat.lng });
        });

        wirePoiInteractions(map, categoryNamesRef);

        reportBounds(map, boundsHandlerRef.current);
        map.on('moveend', () => {
          if (map) reportBounds(map, boundsHandlerRef.current);
        });

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

  useEffect(() => {
    const map = mapRef.current;
    if (!map || status !== 'hazir') return;

    userLocationMarkerRef.current?.remove();
    userLocationMarkerRef.current = null;

    if (!userLocation) return;

    const el = document.createElement('div');
    el.className = 'user-location-marker';

    userLocationMarkerRef.current = new Marker({ element: el })
      .setLngLat([userLocation.lon, userLocation.lat])
      .setPopup(new Popup({ offset: 16 }).setText('Mevcut konumun'))
      .addTo(map);
  }, [userLocation, status]);

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
  }, [markers, focus, status]);

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
  }, [properties, status]);

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

  useEffect(() => {
    const canvas = mapRef.current?.getCanvas();
    if (canvas) canvas.style.cursor = onMapClick ? 'crosshair' : '';
  }, [onMapClick, status]);

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
    const anchorSource = mapRef.current?.getSource('anchor-alani') as GeoJSONSource | undefined;
    if (!anchorSource) return;

    anchorSource.setData({
      type: 'FeatureCollection',
      features: anchorArea ? [anchorArea.polygon] : [],
    });
  }, [anchorArea, status]);

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

  useEffect(() => {
    const map = mapRef.current;
    if (!map || status !== 'hazir') return;

    const poiSource = map.getSource('pois') as GeoJSONSource | undefined;
    poiSource?.setData(toPoiFeatureCollection(poiDataRef.current, categoryNamesRef.current) as never);
  }, [pois, status, poiCategoryNames]);

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