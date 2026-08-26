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

// Rotalar İçin
export interface RouteListResponse {
  id: string;
  name: string;
  mode: string;
  totalDistanceM: number;
  totalDurationS: number;
  createdAt: string;
  stopCount: number;
}
