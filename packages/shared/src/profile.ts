/**
 * Profil ve anchor sözleşmesi.
 *
 * Anchor = kullanıcının düzenli gittiği yer (iş, okul, spor salonu…).
 * Önem sırasına dizilir ve skor bu sıraya göre yeniden hesaplanır (W4).
 */

import type { PersonaCode } from './persona';
import type { TravelMode } from './common';

/** En fazla kaç anchor eklenebilir.
 *
 * Üç haftalık planda 5'ten 3'e indirildi. Ağırlık formülü değişmedi,
 * yalnızca tavan düştü. Veritabanı da zorluyor:
 * `CHECK (priority BETWEEN 1 AND 3)` */
export const MAX_ANCHORS = 3;

export interface Anchor {
  id: string;
  label: string;
  lat: number;
  lon: number;
  mode: TravelMode;

  /** 1 = en önemli. Ağırlık geometrik türetilir — bkz. `anchorWeights()`. */
  priority: number;
}

export interface UserProfile {
  id: string;

  firstName: string;
  lastName: string;

  personaCode: PersonaCode;

  /** null → bütçe skoru devre dışı, Skor = YaşamSkoru. */
  monthlyBudget: number | null;

  /**
   * Kullanıcının kişisel yaşam kriteri sırası.
   * İlk eleman en önemli kriterdir.
   *
   * Örn:
   * ['school', 'market', 'park', ...]
   */
  categoryOrder: string[];

  /** Her zaman `priority`'ye göre sıralı gelir. */
  anchors: Anchor[];
}

export interface UpdateProfileRequest {
  firstName: string;
  lastName: string;

  personaCode: PersonaCode;
  monthlyBudget: number | null;

  /**
   * Yaşam kriterleri en önemliden
   * en az önemliye doğru gönderilir.
   */
  categoryOrder?: string[];
}

export interface CreateAnchorRequest {
  label: string;
  lat: number;
  lon: number;
  mode: TravelMode;

  // priority YOK — sunucu boş olan en küçük sırayı atar.
  // Sıralama yalnızca ReorderAnchorsRequest ile değişir.
}

export interface ReorderAnchorsRequest {
  /** Dizideki index + 1 = yeni priority.
   *
   * Sunucu şunları doğrular, biri bile bozuksa 422 + INVALID_ANCHOR_ORDER:
   *   · kullanıcının anchor'larının TAMAMI var (eksik yok)
   *   · fazladan id yok
   *   · tekrar eden id yok
   *   · başkasının anchor'ı yok
   */
  order: string[];
}