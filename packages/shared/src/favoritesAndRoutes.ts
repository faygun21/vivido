// Favoriler İçin
export interface FavoriteResponse {
  propertyId: number;
  createdAt: string;
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