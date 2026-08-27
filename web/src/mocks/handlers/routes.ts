import { http, HttpResponse } from 'msw';
import type {
  CreateRouteRequest,
  RouteDetail,
  RouteLeg,
  RouteListResponse,
  RouteStop,
  TravelMode,
} from '@vivido/shared';
import { MAX_ROUTE_STOPS, MIN_ROUTE_STOPS } from '@vivido/shared';
import { API_BASE_URL } from '@/shared/config';
import { mockDb, newId, userIdFromAuthHeader } from '@/mocks/db';
import { problem, validationProblem } from '@/mocks/problem';

/**
 * Rota (R-120..R-123) MSW handler'ları.
 *
 * Gerçek backend'in kurallarını birebir taklit eder:
 *   · 2–8 konut, tekrarsız (aksi 422)
 *   · mode yalnızca 'car' | 'foot', name boş olamaz
 *   · bacak (leg) i → durak i+1'in legDistanceM/LegDurationS alanına yazılır
 *   · POST → 201 + RouteDetail (geometry + stops + legs aynı cevapta)
 *
 * Gerçek konut verisi MSW'de tutulmuyor (properties uç noktası mock
 * kapsamı dışında) — bu yüzden konut özeti id'den deterministik üretilir.
 * Aynı propertyId her zaman aynı koordinat/kira/oda döner.
 */

function mockPropertyFor(id: number) {
  const lat = 39.87 + (((id * 37) % 100) - 50) * 0.0011;
  const lon = 32.85 + (((id * 53) % 100) - 50) * 0.0013;
  const monthlyRent = 9_500 + ((id * 211) % 14_500);
  const areaM2 = 60 + ((id * 7) % 71);
  const roomCount = ['1+0', '1+1', '2+1', '3+1'][((id * 5) % 100) % 4];
  const neighborhood = ['Kızılay', 'Bahçelievler', 'Kurtuluş', 'Çankaya', 'Maltepe'][
    ((id * 11) % 100) % 5
  ];
  const score = 70 + ((id * 13) % 26);
  return { lat, lon, monthlyRent, areaM2, roomCount, neighborhood, score };
}

/** Haversine — [lon, lat] çiftleri arası mesafe (metre). */
function haversineMeters(a: [number, number], b: [number, number]): number {
  const R = 6_371_008.8;
  const toRad = (value: number) => (value * Math.PI) / 180;
  const dLat = toRad(b[1] - a[1]);
  const dLon = toRad(b[0] - a[0]);
  const s =
    Math.sin(dLat / 2) ** 2
    + Math.cos(toRad(a[1])) * Math.cos(toRad(b[1])) * Math.sin(dLon / 2) ** 2;
  return Math.round(2 * R * Math.asin(Math.sqrt(s)));
}

/** Ulaşım moduna göre tahmini hız — yürüme ~4.8 km/s, araç ~30 km/s (kent içi). */
function speedMps(mode: TravelMode): number {
  return mode === 'foot' ? 1.33 : 8.33;
}

function legGeometry(from: [number, number], to: [number, number]) {
  return {
    type: 'LineString' as const,
    coordinates: [from, to] as [number, number][],
  };
}

/**
 * Backend akışıyla aynı biçimde rota üretir. Mock TSP koşturamaz; bunun
 * yerine "en yakın komşu" kaba sıralaması uygular — böylece arayüzün
 * "durak sırası değişti" beklentisi mock'ta da görünür olur.
 */
function buildRoute(body: CreateRouteRequest): RouteDetail {
  const mode: TravelMode = body.mode === 'foot' ? 'foot' : 'car';
  const snapshots = new Map(body.propertyIds.map((id) => [id, mockPropertyFor(id)]));

  const startPoint: [number, number] = [body.start.lon, body.start.lat];

  // En yakın komşu: başlangıçtan başla, her adımda en yakın ziyaret edilmemiş konuta git.
  const ordered = [...body.propertyIds];
  const visited: number[] = [];
  let cursor = startPoint;
  while (ordered.length > 0) {
    let bestIdx = 0;
    let bestDist = Infinity;
    for (let i = 0; i < ordered.length; i += 1) {
      const p = snapshots.get(ordered[i])!;
      const d = haversineMeters(cursor, [p.lon, p.lat]);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    const [nextId] = ordered.splice(bestIdx, 1);
    const next = snapshots.get(nextId)!;
    visited.push(nextId);
    cursor = [next.lon, next.lat];
  }

  const coords: [number, number][] = [startPoint];
  const stops: RouteStop[] = [];
  const legs: RouteLeg[] = [];
  let totalDistanceM = 0;
  let totalDurationS = 0;

  visited.forEach((propertyId, index) => {
    const p = snapshots.get(propertyId)!;
    const from = coords[index];
    const to: [number, number] = [p.lon, p.lat];
    coords.push(to);

    const legDistance = haversineMeters(from, to);
    const legDuration = Math.round(legDistance / speedMps(mode));

    // Backend ile aynı semantik: leg[index] = önceki nokta → bu durak.
    legs.push({
      seq: index + 1,
      steps: [
        {
          distance: legDistance,
          duration: legDuration,
          name: index === 0 ? 'Başlangıç' : 'Rota',
          maneuver: {
            type: index === 0 ? 'depart' : index === visited.length - 1 ? 'arrive' : 'turn',
            modifier: index === 0 ? undefined : index % 2 === 0 ? 'left' : 'right',
            location: to,
          },
          geometry: legGeometry(from, to),
        },
      ],
    });

    stops.push({
      seq: index + 1,
      propertyId,
      score: p.score,
      legDistanceM: legDistance,
      legDurationS: legDuration,
      visitedAt: null,
      property: {
        monthlyRent: p.monthlyRent,
        areaM2: p.areaM2,
        roomCount: p.roomCount,
        neighborhood: p.neighborhood,
        lat: p.lat,
        lon: p.lon,
      },
    });

    totalDistanceM += legDistance;
    totalDurationS += legDuration;
  });

  const createdAt = new Date().toISOString();
  return {
    id: newId(),
    name: body.name.trim(),
    start: { lat: body.start.lat, lon: body.start.lon, label: body.start.label ?? '' },
    mode,
    totalDistanceM,
    totalDurationS,
    createdAt,
    stopCount: stops.length,
    scheduledAt: body.scheduledAt ?? null,
    // Mock her zaman KAYDEDİLMİŞ rota üretiyor; önizleme yolunu taklit
    // etmiyor (MSW şu an kapalı, gerçek API kullanılıyor).
    isSaved: true,
    geometry: { type: 'LineString', coordinates: coords },
    stops,
    legs,
  };
}

function requireUser(request: Request): string | null {
  return userIdFromAuthHeader(request);
}

function routesOf(userId: string): RouteDetail[] {
  return mockDb.routes.get(userId) ?? [];
}

export const routesHandlers = [
  // ─── GET /routes — liste (RouteSummary, ağır geometry/legs yok) ───
  http.get(`${API_BASE_URL}/routes`, ({ request }) => {
    const userId = requireUser(request);
    if (!userId) {
      return problem(401, 'Oturum gerekli', 'TOKEN_EXPIRED');
    }

    const list: RouteListResponse[] = routesOf(userId)
      .slice()
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .map((route) => ({
        id: route.id,
        name: route.name,
        mode: route.mode,
        totalDistanceM: route.totalDistanceM,
        totalDurationS: route.totalDurationS,
        createdAt: route.createdAt,
        stopCount: route.stopCount,
        scheduledAt: route.scheduledAt,
      }));

    return HttpResponse.json(list);
  }),

  // ─── GET /routes/{id} — detay ───
  http.get(`${API_BASE_URL}/routes/:id`, ({ request, params }) => {
    const userId = requireUser(request);
    if (!userId) {
      return problem(401, 'Oturum gerekli', 'TOKEN_EXPIRED');
    }

    const route = routesOf(userId).find((r) => r.id === params.id);
    if (!route) {
      return problem(404, 'Rota bulunamadı');
    }

    return HttpResponse.json(route);
  }),

  // ─── POST /routes — TSP + OSRM + kalıcılık (R-120, R-123) ───
  http.post(`${API_BASE_URL}/routes`, async ({ request }) => {
    const userId = requireUser(request);
    if (!userId) {
      return problem(401, 'Oturum gerekli', 'TOKEN_EXPIRED');
    }

    const body = (await request.json()) as CreateRouteRequest;
    const errors: Record<string, string[]> = {};

    if (body == null) {
      return problem(422, 'Rota isteği geçersiz', 'ROUTE_VALIDATION_ERROR');
    }

    if (!body.name?.trim()) {
      errors.name = ['Rota adı zorunlu.'];
    }

    if (!body.propertyIds || body.propertyIds.length < MIN_ROUTE_STOPS) {
      return problem(
        422,
        'Rota durağı sayısı geçersiz',
        'ROUTE_STOP_LIMIT_EXCEEDED',
        `Bir rota ${MIN_ROUTE_STOPS} ile ${MAX_ROUTE_STOPS} konut arasında içermelidir. (W7: en fazla ${MAX_ROUTE_STOPS} ev)`,
      );
    }
    if (body.propertyIds.length > MAX_ROUTE_STOPS) {
      return problem(
        422,
        'Rota durağı sayısı geçersiz',
        'ROUTE_STOP_LIMIT_EXCEEDED',
        `Bir rota ${MIN_ROUTE_STOPS} ile ${MAX_ROUTE_STOPS} konut arasında içermelidir. (W7: en fazla ${MAX_ROUTE_STOPS} ev)`,
      );
    }
    if (new Set(body.propertyIds).size !== body.propertyIds.length) {
      errors.propertyIds = ['Aynı konut bir rotaya iki kez eklenemez.'];
    }

    const mode = body.mode?.toLowerCase() ?? 'car';
    if (mode !== 'car' && mode !== 'foot') {
      errors.mode = ["mode yalnızca 'car' ya da 'foot' olabilir."];
    }

    const start = body.start;
    if (!start || start.lat < -90 || start.lat > 90 || start.lon < -180 || start.lon > 180) {
      errors.start = ['Geçerli bir başlangıç koordinatı gerekli.'];
    }

    if (Object.keys(errors).length > 0) {
      return validationProblem(errors);
    }

    const route = buildRoute(body);
    mockDb.routes.set(userId, [route, ...routesOf(userId)]);

    return HttpResponse.json(route, { status: 201 });
  }),

  // ─── DELETE /routes/{id} — 204 (yoksa da 204) ───
  http.delete(`${API_BASE_URL}/routes/:id`, ({ request, params }) => {
    const userId = requireUser(request);
    if (!userId) {
      return problem(401, 'Oturum gerekli', 'TOKEN_EXPIRED');
    }

    const remaining = routesOf(userId).filter((r) => r.id !== params.id);
    mockDb.routes.set(userId, remaining);

    return new HttpResponse(null, { status: 204 });
  }),
];

