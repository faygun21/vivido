// Favoriler İçin
export interface FavoriteResponse {
  propertyId: number;
  createdAt: string;
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
}