import { beforeAll, afterAll, afterEach, describe, expect, it } from 'vitest';
import { setupServer } from 'msw/node';
import { routesHandlers } from './routes';
import { mockDb } from '@/mocks/db';
import { API_BASE_URL } from '@/shared/config';
import type { CreateRouteRequest, RouteDetail, RouteListResponse } from '@vivido/shared';
import { MAX_ROUTE_STOPS, MIN_ROUTE_STOPS } from '@vivido/shared';

/**
 * Rota MSW handler'ları — gerçek backend'in kurallarını doğrular:
 * sınırlar (2–8), isim zorunluluğu, auth ve rota geometrisi/leg yapısı.
 * `setup.ts`'te öngörülen `setupServer` deseni ilk kez burada kullanılıyor.
 */

const server = setupServer(...routesHandlers);

const USER_ID = 'test-user-1';
const AUTH = { Authorization: `Bearer mock-access.${USER_ID}` };

function routeUrl(path: string): string {
  return `${API_BASE_URL}${path}`;
}

const validRequest: CreateRouteRequest = {
  name: 'Cumartesi turu',
  start: { lat: 39.9208, lon: 32.8541, label: 'Kızılay Meydanı' },
  propertyIds: [101, 202, 303, 404, 505],
  mode: 'car',
};

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => {
  server.resetHandlers();
  mockDb.routes.clear();
});
afterAll(() => server.close());

async function postRoute(body: CreateRouteRequest, headers: HeadersInit = AUTH) {
  return fetch(routeUrl('/routes'), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
}

describe('POST /routes', () => {
  it('geçerli istekle 201 + tam rota döner (geometry, stops, legs)', async () => {
    const response = await postRoute(validRequest);
    expect(response.status).toBe(201);

    const route = (await response.json()) as RouteDetail;
    expect(route.id).toBeTruthy();
    expect(route.name).toBe('Cumartesi turu');
    expect(route.mode).toBe('car');
    expect(route.stopCount).toBe(5);
    expect(route.stops.map((s) => s.seq)).toEqual([1, 2, 3, 4, 5]);
    // Başlangıç + 5 durak → 6 koordinatlı LineString
    expect(route.geometry.type).toBe('LineString');
    expect(route.geometry.coordinates.length).toBe(6);
    expect(route.legs.length).toBe(5);
    // Bacak süreleri durakta taşınır (backend semantiği)
    for (const stop of route.stops) {
      expect(stop.legDistanceM).toBeGreaterThan(0);
      expect(stop.legDurationS).toBeGreaterThan(0);
    }
    expect(route.totalDistanceM).toBeGreaterThan(0);
    expect(route.totalDurationS).toBeGreaterThan(0);
  });

  it('mod yürüme seçilince foot profili döner', async () => {
    const response = await postRoute({ ...validRequest, mode: 'foot' });
    expect(response.status).toBe(201);
    const route = (await response.json()) as RouteDetail;
    expect(route.mode).toBe('foot');
  });

  it(`${MIN_ROUTE_STOPS} altında durağı 422 ROUTE_STOP_LIMIT_EXCEEDED ile reddeder`, async () => {
    const response = await postRoute({ ...validRequest, propertyIds: [101] });
    expect(response.status).toBe(422);

    const body = (await response.json()) as { code?: string };
    expect(body.code).toBe('ROUTE_STOP_LIMIT_EXCEEDED');
  });

  it(`${MAX_ROUTE_STOPS} üstünde durağı 422 ile reddeder`, async () => {
    const response = await postRoute({
      ...validRequest,
      propertyIds: Array.from({ length: MAX_ROUTE_STOPS + 1 }, (_, i) => 1000 + i),
    });
    expect(response.status).toBe(422);
  });

  it('boş adı 400 VALIDATION_ERROR ile reddeder', async () => {
    const response = await postRoute({ ...validRequest, name: '   ' });
    expect(response.status).toBe(400);

    const body = (await response.json()) as { code?: string; errors?: Record<string, string[]> };
    expect(body.code).toBe('VALIDATION_ERROR');
    expect(body.errors?.name).toBeTruthy();
  });

  it('aynı konutu iki kez içeren isteği 400 ile reddeder', async () => {
    const response = await postRoute({ ...validRequest, propertyIds: [101, 101, 202, 303] });
    expect(response.status).toBe(400);

    const body = (await response.json()) as { errors?: Record<string, string[]> };
    expect(body.errors?.propertyIds).toBeTruthy();
  });

  it('token yoksa 401 döner', async () => {
    const response = await postRoute(validRequest, {});
    expect(response.status).toBe(401);
  });
});

describe('GET /routes', () => {
  it('oluşturulan rotaları özet listesine çevirir (ağır geometry yok)', async () => {
    await postRoute(validRequest);
    await postRoute({ ...validRequest, name: 'İkinci rota', propertyIds: [7, 8] });

    const response = await fetch(routeUrl('/routes'), { headers: AUTH });
    expect(response.status).toBe(200);

    const list = (await response.json()) as RouteListResponse[];
    expect(list.length).toBe(2);
    expect(list[0].name).toBe('İkinci rota'); // en yeni başta
    expect(list[0].mode).toBe('car');
    expect(list[0].stopCount).toBe(2);
    expect('geometry' in list[0]).toBe(false); // özet payload'da çizgi yok
  });
});

describe('GET /routes/{id} ve DELETE', () => {
  it('detayı döner ve silme sonrası liste boşalır', async () => {
    const createdResponse = await postRoute(validRequest);
    const created = (await createdResponse.json()) as RouteDetail;

    const detailResponse = await fetch(routeUrl(`/routes/${created.id}`), { headers: AUTH });
    expect(detailResponse.status).toBe(200);
    const detail = (await detailResponse.json()) as RouteDetail;
    expect(detail.id).toBe(created.id);
    expect(detail.stops.length).toBe(5);

    const deleteResponse = await fetch(routeUrl(`/routes/${created.id}`), {
      method: 'DELETE',
      headers: AUTH,
    });
    expect(deleteResponse.status).toBe(204);

    const listResponse = await fetch(routeUrl('/routes'), { headers: AUTH });
    const list = (await listResponse.json()) as RouteListResponse[];
    expect(list.length).toBe(0);
  });
});
