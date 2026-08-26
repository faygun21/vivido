import type { PropertySummary } from './property';

// Favoriler İçin
export interface FavoriteResponse {
  propertyId: number;
  createdAt: string;
  /**
   * Konutun kart basmaya yetecek özeti.
   *
   * Sonradan eklendi: eskiden yalnızca `propertyId` geliyordu ve profil
   * sayfası "Ev ID: 4213" yazmak zorunda kalıyordu. Konut silinmişse null.
   */
  property: PropertySummary | null;
}

// Rotalar İçin — backend `RouteListResponse` ile senkron.
import type { TravelMode } from './common';

export interface RouteListResponse {
  id: string;
  name: string;
  /** 'car' | 'foot' — backend enum'ı string olarak serileşir. */
  mode: TravelMode;
  totalDistanceM: number;
  totalDurationS: number;
  createdAt: string;
  stopCount: number;
  /** Planlanan ziyaret zamanı (ISO). null = plan girilmedi. */
  scheduledAt: string | null;
}
