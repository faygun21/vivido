import { describe, expect, it } from 'vitest';
import {
  DEFAULT_WALKING_MINUTES,
  createWalkingAccessibilityPolygon,
  isWalkingMinutes,
} from './walkingAccessibility';

describe('walking accessibility', () => {
  it('uses 15 minutes by default', () => {
    expect(DEFAULT_WALKING_MINUTES).toBe(15);
  });

  it('accepts only the permitted minute values', () => {
    expect(isWalkingMinutes(5)).toBe(true);
    expect(isWalkingMinutes(15)).toBe(true);
    expect(isWalkingMinutes(30)).toBe(true);
    expect(isWalkingMinutes(0)).toBe(false);
    expect(isWalkingMinutes(12)).toBe(false);
    expect(isWalkingMinutes(45)).toBe(false);
  });

  it('creates a closed 15-minute polygon with a 1200 metre radius', () => {
    const polygon = createWalkingAccessibilityPolygon({ lat: 39.87, lon: 32.85 }, 15);
    const ring = polygon.geometry.coordinates[0];

    expect(polygon.properties.radiusMetres).toBe(1200);
    expect(ring).toHaveLength(73);
    expect(ring.at(-1)).toEqual(ring[0]);
  });
});
