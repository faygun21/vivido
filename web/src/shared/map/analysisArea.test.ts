import { describe, expect, it } from 'vitest';
import {
  DEFAULT_ANALYSIS_RADIUS_KM,
  createAnalysisAreaPolygon,
  isAnalysisRadiusKm,
} from './analysisArea';

describe('analysis area', () => {
  it('uses a 2 km default radius', () => {
    expect(DEFAULT_ANALYSIS_RADIUS_KM).toBe(2);
  });

  it('accepts only configured radii', () => {
    expect(isAnalysisRadiusKm(0.5)).toBe(true);
    expect(isAnalysisRadiusKm(2)).toBe(true);
    expect(isAnalysisRadiusKm(5)).toBe(true);
    expect(isAnalysisRadiusKm(0)).toBe(false);
    expect(isAnalysisRadiusKm(2.5)).toBe(false);
    expect(isAnalysisRadiusKm(6)).toBe(false);
  });

  it('creates a closed polygon with a 2000 metre radius', () => {
    const polygon = createAnalysisAreaPolygon({ lat: 39.87, lon: 32.85 }, 2);
    const ring = polygon.geometry.coordinates[0];

    expect(polygon.properties).toEqual({ radiusKm: 2, radiusMetres: 2000 });
    expect(ring).toHaveLength(73);
    expect(ring.at(-1)).toEqual(ring[0]);
  });
});
