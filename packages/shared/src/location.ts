/** R-105 konum arama API sözleşmesi. */

export interface LocationBounds {
  south: number;
  west: number;
  north: number;
  east: number;
}

export type LocationKind = 'neighborhood' | 'address' | 'place';

export interface LocationSearchResult {
  id: string;
  label: string;
  kind: LocationKind;
  latitude: number;
  longitude: number;
  bounds: LocationBounds | null;
  neighborhood: string | null;
  source: 'local' | 'nominatim';
}

export interface LocationSearchResponse {
  items: LocationSearchResult[];
  attribution: string;
}
