import { createRadiusPolygon, type WalkingLocation } from './walkingAccessibility';

export const ANALYSIS_RADIUS_OPTIONS_KM = [0.5, 1, 2, 3, 5] as const;
export const DEFAULT_ANALYSIS_RADIUS_KM = 2;

export type AnalysisRadiusKm = (typeof ANALYSIS_RADIUS_OPTIONS_KM)[number];

export function isAnalysisRadiusKm(value: number): value is AnalysisRadiusKm {
  return ANALYSIS_RADIUS_OPTIONS_KM.some((option) => option === value);
}

export function createAnalysisAreaPolygon(
  location: WalkingLocation,
  radiusKm: AnalysisRadiusKm,
) {
  const radiusMetres = radiusKm * 1000;
  const feature = createRadiusPolygon(location, radiusMetres);

  return {
    ...feature,
    properties: { radiusKm, radiusMetres },
  };
}
