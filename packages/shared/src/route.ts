/**
 * Ziyaret rotası sözleşmesi (W7, M2–M5). — Hafta 3
 *
 * Mobil uygulama YALNIZCA `RouteDetail` payload'ını tüketir;
 * navigasyon için ikinci bir API çağrısına ihtiyaç duymaz.
 * Bu yüzden `legs` ve `geometry` aynı cevapta gelir.
 */

import type { GeoJsonLineString, TravelMode } from './common';
import type { Property } from './property';

/** Held-Karp sınırı. n=8 için 16.384 işlem, <1 ms.
 *  n=12'de 590K, n=15'te 7.4M — ve bir günde 8 evden fazlası zaten gerçekçi değil. */
export const MAX_ROUTE_STOPS = 8;
export const MIN_ROUTE_STOPS = 2;

export interface RouteStop {
  /** TSP'nin belirlediği sıra, 1..8 */
  seq: number;
  propertyId: number;
  /**
   * Rota kurulduğu ANDAKİ skor — sonradan değişse bile bu sabit kalır.
   * Backend şu an `ScoreSnapshot` kolonu null döndürebilir (skorlama
   * entegrasyonu henüz rotaya bağlanmadı); null olduğunda arayüz
   * konutun anlık skorunu kendi verisinden doldurur.
   */
  score: number | null;
  legDistanceM: number;
  legDurationS: number;
  /** Mobilde "ziyaret ettim" işaretlenince dolar (M5). */
  visitedAt: string | null;
  property: Pick<
    Property,
    'monthlyRent' | 'areaM2' | 'roomCount' | 'neighborhood' | 'lat' | 'lon'
  >;
}

/** OSRM manevrası — mobilde Türkçe metne çevrilir (`maneuverText.ts`). */
export interface Maneuver {
  /** 'turn' | 'depart' | 'arrive' | 'roundabout' … */
  type: string;
  /** 'left' | 'right' | 'slight left' … */
  modifier?: string;
  /** [lon, lat] */
  location: [number, number];
  /** Göbek/meydan çıkışı numarası. */
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

export interface CreateRouteRequest {
  /**
   * Rota adı.
   *
   * `POST /routes` (kaydetme) için ZORUNLU; `POST /routes/preview`
   * (önizleme) için değil — kullanıcı beğenmediği bir rotaya ad uydurmak
   * zorunda kalmasın diye ad kaydetme adımında soruluyor.
   */
  name: string;
  start: { lat: number; lon: number; label?: string };
  /** 2–8 ev. Sınır dışında 422 döner. */
  propertyIds: number[];
  mode?: TravelMode;
  /** Planlanan ziyaret zamanı (ISO). Yalnızca kaydederken anlamlı. */
  scheduledAt?: string | null;
}

export interface RouteDetail {
  id: string;
  name: string;
  start: { lat: number; lon: number; label: string };
  mode: TravelMode;
  totalDistanceM: number;
  totalDurationS: number;
  /** Liste ile senkron özet alanı — backend `RouteListResponse`'tan miras gelir. */
  stopCount: number;
  /**
   * Kullanıcının bu rotayı gezmeyi planladığı an (ISO). null = plan yok.
   *
   * ⚠️ Bildirim GÖNDERMEZ — yalnızca saklanır ve listede gösterilir.
   * Mobil bildirim ayrı bir iş (backlog/v2.md).
   */
  scheduledAt: string | null;
  /**
   * Rota veritabanına kaydedildi mi?
   *
   * `POST /routes/preview` hesaplanmış ama KAYDEDİLMEMİŞ rota döner:
   * `id` boş, bu alan `false`. Arayüz buna bakıp "Kaydet" düğmesini
   * gösteriyor — kullanıcı kaydetmediği bir rotayı kaydedilmiş sanmasın.
   */
  isSaved: boolean;
  /** Tam rota çizgisi — mobilde haritaya çizilir. */
  geometry: GeoJsonLineString;
  stops: RouteStop[];
  legs: RouteLeg[];
  createdAt: string;
}

/** Liste görünümü — ağır `geometry` ve `legs` alanları olmadan. */
export interface RouteSummary {
  id: string;
  name: string;
  /** 'car' | 'foot' — backend `RouteListResponse` ile senkron (mode eksikti, eklendi). */
  mode: TravelMode;
  stopCount: number;
  totalDistanceM: number;
  totalDurationS: number;
  createdAt: string;
}
