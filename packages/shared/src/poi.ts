/** R-108/R-109/R-110 — POI ve harita konutu sözleşmeleri. */

export interface PoiCategory {
  code: string;
  displayNameTr: string;
}

export interface Poi {
  id: number;
  name: string | null;
  categoryCode: string;
  latitude: number;
  longitude: number;
}

/** Harita görünümü için konut (API: GET /api/v1/properties). */
export interface MapProperty {
  id: number;
  externalRef: string;
  latitude: number;
  longitude: number;
  monthlyRent: number;
  areaM2: number;
  roomCount: string;
  buildingAge: number | null;
  hasElevator: boolean;
  isSynthetic: boolean;
}
