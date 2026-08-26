import { beforeEach, describe, expect, it } from 'vitest';
import { useRouteStore } from './routeStore';
import type { RouteDetail } from '@vivido/shared';

/**
 * Aktif rota store'u — R-123'ün omurgası: Profil paneli rotayı buraya
 * yazar, Explore haritada çizer. Yanlışlıkla iki ayrı "aktif rota" kavramı
 * oluşursa (ör. birisi useState'e geçerse) bu test yakalar.
 */

function fixtureRoute(id: string): RouteDetail {
  return {
    id,
    name: 'Test rotası',
    start: { lat: 39.92, lon: 32.85, label: 'Kızılay' },
    mode: 'car',
    totalDistanceM: 12_000,
    totalDurationS: 1_800,
    stopCount: 2,
    geometry: {
      type: 'LineString',
      coordinates: [
        [32.85, 39.92],
        [32.86, 39.93],
      ],
    },
    stops: [
      {
        seq: 1,
        propertyId: 101,
        score: null,
        legDistanceM: 6_000,
        legDurationS: 900,
        visitedAt: null,
        property: {
          monthlyRent: 12_000,
          areaM2: 80,
          roomCount: '2+1',
          neighborhood: 'Kızılay',
          lat: 39.93,
          lon: 32.86,
        },
      },
    ],
    legs: [],
    createdAt: '2026-08-25T00:00:00Z',
  };
}

describe('useRouteStore', () => {
  beforeEach(() => {
    useRouteStore.setState({ activeRoute: null });
  });

  it('varsayılan olarak aktif rota yoktur', () => {
    expect(useRouteStore.getState().activeRoute).toBeNull();
  });

  it('setActiveRoute rotayı yazar, harita okuyabilir', () => {
    useRouteStore.getState().setActiveRoute(fixtureRoute('route-1'));
    expect(useRouteStore.getState().activeRoute?.id).toBe('route-1');
    expect(useRouteStore.getState().activeRoute?.geometry.type).toBe('LineString');
  });

  it('null ile çizgi temizlenebilir', () => {
    useRouteStore.getState().setActiveRoute(fixtureRoute('route-2'));
    useRouteStore.getState().setActiveRoute(null);
    expect(useRouteStore.getState().activeRoute).toBeNull();
  });
});
