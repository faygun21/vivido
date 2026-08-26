/**
 * Kiralık konut sözleşmesi. — Hafta 2
 *
 * DİKKAT: `Property.id` bir SAYIDIR (`bigserial`), oysa kullanıcı, anchor
 * ve rota id'leri STRING'dir (uuid). Aynı projede iki tip var, karıştırmayın.
 */

import type { ScoreBand, ScoreSummary } from './score';

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

// ══════════════════════════════════════════════════════════════════════
//  API DTO'ları — `/api/v1/properties` uçlarının GERÇEK yanıt şekilleri
//
//  Yukarıdaki `Property` / `ScoredProperty` planlanmış (Hafta 2) sözleşme;
//  aşağıdakiler bugün sunucunun DÖNDÜĞÜ şekil. İkisi henüz birleşmedi —
//  `api/openapi.yaml` yazılınca tek kaynaktan üretilecekler
//  (docs/04-MEVCUT-DURUM §8, madde 6).
// ══════════════════════════════════════════════════════════════════════

/**
 * Konutun konum bilgisi.
 *
 * `streetName` NULL olabilir: `streets` tablosu yüklenmemişse
 * (`data/scripts/05_load_streets.sh`) ya da konutun ~330 m çevresinde adlı
 * bir sokak yoksa. Arayüz bu durumda mahalleye düşer.
 *
 * Kapı numarası BİLEREK YOK — sokak adı sentetik ilanı inandırıcı kılıyor,
 * kapı numarası ise gerçek bir konutu tekil olarak işaret ederdi.
 */
export interface PropertyAddress {
  streetName: string | null;
  neighborhoodName: string | null;
  districtName: string;
  cityName: string;
  /** Sunucunun birleştirdiği tek satırlık gösterim. */
  formatted: string;
}

/** Gerekçe tablosunun bir satırı (W6). */
export interface PropertyScoreRow {
  categoryCode: string;
  label: string;
  /** Ölçülen yürüme süresi (dakika) — OSRM foot profili. */
  durationMin: number;
  /** Bu süreye kadar 100 puan (`t_ideal`). */
  targetMin: number;
  /** Bu sürenin ötesi 0 puan (`t_cutoff`). */
  cutoffMin: number;
  subScore: number;
  /** Hesaba giren kategoriler arasında normalize edilmiş ağırlık. */
  weight: number;
  /** Toplam skora katkısı. Tüm satırların toplamı `total`a eşittir. */
  contribution: number;
  status: 'strong' | 'good' | 'warning' | 'weak';
}

/**
 * Kiranın bütçe aralığındaki yeri.
 *
 * ⚠️ SKOR BİLEŞENİ DEĞİLDİR — mevcut motor yalnızca POI erişim sürelerini
 * hesaba katıyor. Panelde ayrı ve açıkça etiketli durur ki kullanıcı
 * "bütçem skorumu düşürmüş" gibi yanlış bir sonuç çıkarmasın.
 */
export interface PropertyBudgetFit {
  monthlyRent: number;
  minMonthlyBudget: number | null;
  maxMonthlyBudget: number | null;
  ratioToMax: number | null;
  status: 'under' | 'fits' | 'tight' | 'over' | 'unknown';
  message: string;
}

export interface PropertyScoreDetail {
  total: number;
  band: ScoreBand;
  rows: PropertyScoreRow[];
  /** Katkısı en yüksek satırlar — "neden uygun". */
  strengths: PropertyScoreRow[];
  /** En çok puan kaybettiren satırlar — "neden uygun değil". */
  weaknesses: PropertyScoreRow[];
  budget: PropertyBudgetFit;
}

export interface PropertyFeatures {
  floorNo: number | null;
  totalFloors: number | null;
  buildingAge: number | null;
  hasElevator: boolean;
  hasParking: boolean;
  isFurnished: boolean;
  petsAllowed: boolean;
  rentPerM2: number | null;
  deposit: number | null;
}

/** `GET /properties/{id}` — pin'e tıklanınca açılan detay paneli. */
export interface PropertyDetail {
  id: string;
  externalRef: string;
  monthlyRent: number;
  areaM2: number;
  roomCount: string;
  latitude: number;
  longitude: number;
  address: PropertyAddress;
  features: PropertyFeatures;
  score: PropertyScoreDetail;
  isFavorite: boolean;
  isSynthetic: boolean;
}

/** `GET /properties/top` ve favori kartları — liste özeti. */
export interface PropertySummary {
  id: string;
  externalRef: string;
  monthlyRent: number;
  areaM2: number;
  roomCount: string;
  latitude: number;
  longitude: number;
  totalScore: number;
  band: ScoreBand;
  address: PropertyAddress;
  /** En yüksek katkılı kriterin adı — kartta ✓ ile gösterilir. */
  topStrength: string | null;
  /** En çok puan kaybettiren kriterin adı — kartta ✗ ile gösterilir. */
  topWeakness: string | null;
  isFavorite: boolean;
}

/** `GET /properties` — haritadaki pin'ler. Adres ve kırılım taşımaz. */
export interface PropertyMapItem {
  id: string;
  monthlyRent: number;
  areaM2: number;
  roomCount: string;
  latitude: number;
  longitude: number;
  totalScore: number;
}
