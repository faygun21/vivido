/**
 * Vivido — web ve mobil arasında paylaşılan tipler.
 *
 * KURAL: API istemcisi ELLE YAZILMAZ.
 * `api/openapi.yaml` hazır olunca `pnpm gen:api` ile `src/api/` altına üretilir.
 * Buradaki tipler ise el yazımı domain tipleridir (UI'ın konuştuğu dil).
 */

// ─────────── Persona ───────────

export const PERSONA_CODES = [
  'student',
  'family_kids',
  'pet_owner',
  'elderly',
  'remote_worker',
  'car_free',
] as const;

export type PersonaCode = (typeof PERSONA_CODES)[number];

export interface Persona {
  code: PersonaCode;
  displayNameTr: string;
  descriptionTr: string;
  icon?: string;
}

// ─────────── Profil ve anchor ───────────

/** Anchor'a hangi ulaşım moduyla gidiliyor. */
export type TravelMode = 'foot' | 'car';

export interface Anchor {
  id: string;
  label: string;
  lat: number;
  lon: number;
  mode: TravelMode;
  /** 1 = en önemli. Ağırlık geometrik olarak türetilir: 0.5^(priority-1), normalize. */
  priority: number;
}

export interface UserProfile {
  id: string;
  personaCode: PersonaCode;
  /** null ise bütçe skoru devre dışı kalır, skor = YaşamSkoru. */
  monthlyBudget: number | null;
  anchors: Anchor[];
}

// ─────────── Konut ───────────

export interface Property {
  id: number;
  lat: number;
  lon: number;
  monthlyRent: number;
  areaM2: number;
  roomCount: string;
  neighborhood: string;
  floorNo?: number;
  totalFloors?: number;
  buildingAge?: number;
  hasElevator: boolean;
  hasParking: boolean;
  isFurnished: boolean;
  petsAllowed: boolean;
  /** Veri sentetiktir — UI'da her yerde rozetle gösterilmesi zorunludur. */
  isSynthetic: boolean;
}

// ─────────── Skor ───────────

export type ScoreBand = 'excellent' | 'good' | 'fair' | 'poor';

/** Gerekçe tablosundaki bir satırın türü. */
export type ScoreRowKind = 'poi' | 'anchor' | 'budget' | 'ces_adjustment';

export type ScoreRowStatus = 'strong' | 'good' | 'warning' | 'weak';

export interface ScoreRow {
  kind: ScoreRowKind;
  /** POI satırlarında kategori kodu, anchor satırlarında anchor id'si. */
  code?: string;
  label: string;
  /** Anchor satırlarında öncelik sırası. */
  priority?: number;
  measured: string;
  target: string;
  subScore: number;
  weight: number;
  /** Toplam skora katkısı. TÜM satırların toplamı `total`a eşit olmalıdır. */
  contribution: number;
  /** Bu satırdan kaybedilen puan: maksimum katkı − gerçek katkı. */
  loss: number;
  status: ScoreRowStatus;
}

export interface ScoreResult {
  propertyId: number;
  total: number;
  band: ScoreBand;
  rows: ScoreRow[];
  /** Katkısı en yüksek satırların kodları — "neden uygun". */
  strengths: string[];
  /** Kaybı en yüksek satırların kodları — "neden uygun değil". */
  weaknesses: string[];
  scoringVersion: string;
}

/** Liste görünümünde taşınan hafif skor özeti. */
export interface ScoreSummary {
  total: number;
  band: ScoreBand;
  topStrength: string;
  topWeakness: string;
}

export interface ScoredProperty extends Property {
  score: ScoreSummary;
}

// ─────────── Rota ───────────

export interface RouteStop {
  seq: number;
  propertyId: number;
  score: number;
  legDistanceM: number;
  legDurationS: number;
  visitedAt: string | null;
  property: Pick<Property, 'monthlyRent' | 'areaM2' | 'roomCount' | 'neighborhood' | 'lat' | 'lon'>;
}

/** OSRM manevra tipi — mobil navigasyonda Türkçe metne çevrilir. */
export interface Maneuver {
  type: string;
  modifier?: string;
  location: [number, number];
  exit?: number;
}

export interface RouteStep {
  distance: number;
  duration: number;
  name: string;
  maneuver: Maneuver;
  geometry: GeoJsonLineString;
}

export interface RouteLeg {
  seq: number;
  steps: RouteStep[];
}

export interface GeoJsonLineString {
  type: 'LineString';
  coordinates: [number, number][];
}

export interface RouteDetail {
  id: string;
  name: string;
  start: { lat: number; lon: number; label: string };
  mode: TravelMode;
  totalDistanceM: number;
  totalDurationS: number;
  geometry: GeoJsonLineString;
  stops: RouteStop[];
  legs: RouteLeg[];
  createdAt: string;
}

export interface RouteSummary {
  id: string;
  name: string;
  stopCount: number;
  totalDistanceM: number;
  totalDurationS: number;
  createdAt: string;
}

// ─────────── Yardımcılar ───────────

/** Skor → renk bandı. Web ve mobil AYNI eşikleri kullanmalı. */
export function scoreBand(total: number): ScoreBand {
  if (total >= 85) return 'excellent';
  if (total >= 70) return 'good';
  if (total >= 55) return 'fair';
  return 'poor';
}

/**
 * Anchor öncelik sırasını ağırlığa çevirir — geometrik azalan.
 *
 * Ters sıra ağırlığı yerine bu seçildi: listeye önemsiz bir anchor eklemek
 * 1. anchor'ın ağırlığını seyreltmemeli. Geometrikte w₁ her zaman
 * 0.50–0.667 bandında kalır ve `w₁ ≈ w₂ + … + wₙ` özdeşliği sağlanır.
 *
 * Bu fonksiyon UI'da önizleme içindir; skorun tek doğruluk kaynağı backend'dir.
 */
export function anchorWeights(count: number): number[] {
  if (count <= 0) return [];
  const raw = Array.from({ length: count }, (_, i) => 0.5 ** i);
  const sum = raw.reduce((a, b) => a + b, 0);
  return raw.map((r) => r / sum);
}

/** Ziyaret rotasına eklenebilecek en fazla ev sayısı (Held-Karp sınırı). */
export const MAX_ROUTE_STOPS = 8;
export const MIN_ROUTE_STOPS = 2;
