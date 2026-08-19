/**
 * Skor ve gerekçe tablosu sözleşmesi (W5, W6). — Hafta 2
 *
 * Ürünün kalbi: her ev için tek bir 0–100 skor ve o skorun
 * SATIR SATIR gerekçesi.
 */

export type ScoreBand = 'excellent' | 'good' | 'fair' | 'poor';

/** Gerekçe tablosundaki bir satırın türü.
 *  `ces_adjustment` özel: CES doğrusal olmadığı için doğrusal katkılar
 *  ile gerçek sonuç arasındaki fark AÇIK bir satır olarak gösterilir. */
export type ScoreRowKind = 'poi' | 'anchor' | 'budget' | 'ces_adjustment';

export type ScoreRowStatus = 'strong' | 'good' | 'warning' | 'weak';

export interface ScoreRow {
  kind: ScoreRowKind;
  /** POI satırlarında kategori kodu, anchor satırlarında anchor id'si. */
  code?: string;
  label: string;
  /** Yalnızca anchor satırlarında — öncelik sırası. */
  priority?: number;
  measured: string;
  target: string;
  subScore: number;
  weight: number;
  /** Toplam skora katkısı.
   *  DEĞİŞMEZLİK (I4): TÜM satırların toplamı `total`a ±0.05 içinde eşittir.
   *  Bu bir birim testidir — tabloyu tutmayan bir skor gösterilemez. */
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
  /** Kaybı en yüksek satırların kodları — "neden uygun değil".
   *  Bir satır her iki listede de görünebilir (bütçe gibi) — bu doğrudur:
   *  "21 puan kazandırdı ama 9 puan da kaybettirdi." */
  weaknesses: string[];
  scoringVersion: string;
}

/** Liste görünümünde taşınan hafif özet — tam tablo detayda gelir. */
export interface ScoreSummary {
  total: number;
  band: ScoreBand;
  topStrength: string;
  topWeakness: string;
}
