import { describe, expect, it } from 'vitest';
import {
  createAnchorAreaPolygon,
  haversineDistanceMetres,
  weightedCentroid,
} from './anchorSweetSpot';

// Çankaya merkezi civarında, birbirinden belirgin şekilde uzak 3 nokta.
const SCHOOL = { lat: 39.905, lon: 32.862, priority: 1, mode: 'foot' as const }; // en öncelikli
const JOB = { lat: 39.87, lon: 32.85, priority: 2, mode: 'foot' as const };
const LIBRARY = { lat: 39.84, lon: 32.83, priority: 3, mode: 'foot' as const };

describe('haversineDistanceMetres', () => {
  it('returns 0 for the same point', () => {
    expect(haversineDistanceMetres(SCHOOL, SCHOOL)).toBe(0);
  });

  it('matches a known ~1 degree latitude distance (~111km) within 1%', () => {
    const a = { lat: 39, lon: 32 };
    const b = { lat: 40, lon: 32 };
    const distance = haversineDistanceMetres(a, b);
    expect(distance).toBeGreaterThan(110_000);
    expect(distance).toBeLessThan(112_000);
  });
});

describe('weightedCentroid', () => {
  it('returns the point itself for a single anchor', () => {
    const result = weightedCentroid([{ ...SCHOOL, weight: 1 }]);
    expect(result).toEqual({ lat: SCHOOL.lat, lon: SCHOOL.lon });
  });

  it('blends two anchors, weighted toward the heavier one — NOT a snap to either', () => {
    // Geometrik medyanla denenmişti ama matematiksel bir kural yüzünden
    // (1. anchor'ın ağırlığı diğerinin ağırlığından büyükse sonuç HER ZAMAN
    // 1. anchor'ın üstüne tam oturuyordu) terk edildi — bkz. dosya başındaki
    // not. Centroid'in tam olarak çözdüğü şey bu: sonuç iki noktanın
    // ARASINDA, ikisine de ölçülebilir mesafede olmalı.
    const result = weightedCentroid([
      { ...SCHOOL, weight: 0.667 },
      { ...JOB, weight: 0.333 },
    ]);

    const distToSchool = haversineDistanceMetres(result, SCHOOL);
    const distToJob = haversineDistanceMetres(result, JOB);

    // Ne bir anchor'ın tam üstünde (blend gerçekleşmiş)…
    expect(distToSchool).toBeGreaterThan(100);
    expect(distToJob).toBeGreaterThan(100);
    // …ne de JOB'a School'dan daha yakın (ağırlık sırası korunmuş).
    expect(distToSchool).toBeLessThan(distToJob);
  });

  it('for three anchors, sits closer to the priority-1 anchor than the plain (unweighted) centroid would', () => {
    const weighted = weightedCentroid([
      { ...SCHOOL, weight: 0.5714 },
      { ...JOB, weight: 0.2857 },
      { ...LIBRARY, weight: 0.1429 },
    ]);

    const plainCentroid = {
      lat: (SCHOOL.lat + JOB.lat + LIBRARY.lat) / 3,
      lon: (SCHOOL.lon + JOB.lon + LIBRARY.lon) / 3,
    };

    expect(haversineDistanceMetres(weighted, SCHOOL)).toBeLessThan(
      haversineDistanceMetres(plainCentroid, SCHOOL),
    );
  });
});

describe('createAnchorAreaPolygon', () => {
  it('returns null when there are no anchors', () => {
    expect(createAnchorAreaPolygon([])).toBeNull();
  });

  it('single foot anchor: centers exactly on it with an 800m radius', () => {
    const result = createAnchorAreaPolygon([SCHOOL]);
    expect(result).not.toBeNull();
    expect(result!.center).toEqual({ lat: SCHOOL.lat, lon: SCHOOL.lon });
    expect(result!.radiusMetres).toBe(800);
  });

  it('single car anchor: uses the wider (4000m) car radius', () => {
    const result = createAnchorAreaPolygon([{ ...SCHOOL, mode: 'car' }]);
    expect(result!.radiusMetres).toBe(4000);
  });

  it(
    'radius stays bounded even when anchors are spread across the whole city — ' +
      'does NOT grow with anchor spread anymore (this was the bug: a huge, useless circle)',
    () => {
      const farApart = createAnchorAreaPolygon([
        { lat: 39.97, lon: 32.75, priority: 1, mode: 'foot' }, // ilçenin bir ucu
        { lat: 39.75, lon: 32.95, priority: 2, mode: 'foot' }, // diğer ucu, ~30km öteде
      ])!;

      // Yarıçap hâlâ sadece mode'a bağlı (800m) — iki anchor birbirinden
      // ne kadar uzak olursa olsun BÜYÜMÜYOR.
      expect(farApart.radiusMetres).toBe(800);
    },
  );

  it('uses the MOST generous (largest) radius among the anchors\' modes', () => {
    const result = createAnchorAreaPolygon([
      { ...SCHOOL, mode: 'foot' },
      { ...JOB, mode: 'car' },
      { ...LIBRARY, mode: 'foot' },
    ])!;

    expect(result.radiusMetres).toBe(4000);
  });

  it('produces a closed polygon ring around the center', () => {
    const result = createAnchorAreaPolygon([SCHOOL, JOB])!;
    const ring = result.polygon.geometry.coordinates[0];
    expect(ring.at(-1)).toEqual(ring[0]);
    expect(ring.length).toBeGreaterThan(10);
  });
});
