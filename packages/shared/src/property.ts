/**
 * Kiralık konut sözleşmesi. — Hafta 2
 *
 * DİKKAT: `Property.id` bir SAYIDIR (`bigserial`), oysa kullanıcı, anchor
 * ve rota id'leri STRING'dir (uuid). Aynı projede iki tip var, karıştırmayın.
 */

import type { ScoreSummary } from './score';

export interface Property {
  id: number;
  lat: number;
  lon: number;
  monthlyRent: number;
  areaM2: number;
  /** '1+0' … '4+1' */
  roomCount: string;
  neighborhood: string;
  floorNo?: number;
  totalFloors?: number;
  buildingAge?: number;
  hasElevator: boolean;
  hasParking: boolean;
  isFurnished: boolean;
  petsAllowed: boolean;
  /** Veri sentetiktir — arayüzde her yerde rozetle gösterilmesi ZORUNLUDUR.
   *  Dürüstlük kuralı: "veriniz gerçek değil" eleştirisini baştan keser. */
  isSynthetic: boolean;
}

export interface ScoredProperty extends Property {
  score: ScoreSummary;
}

/** Liste başlığındaki mini çubuk için — kaç ev hangi bantta. */
export interface ScoreDistribution {
  excellent: number;
  good: number;
  fair: number;
  poor: number;
}

export interface PropertySearchResponse {
  items: ScoredProperty[];
  page: number;
  totalPages: number;
  totalCount: number;
  scoreDistribution: ScoreDistribution;
}
