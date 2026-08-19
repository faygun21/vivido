import { http, HttpResponse } from 'msw';
import type {
  Anchor,
  CreateAnchorRequest,
  ReorderAnchorsRequest,
  UpdateProfileRequest,
  UserProfile,
} from '@vivido/shared';
import { MAX_ANCHORS } from '@vivido/shared';
import { API_BASE_URL } from '@/shared/config';
import { mockDb, newId, userIdFromAuthHeader } from '@/mocks/db';
import { problem } from '@/mocks/problem';

/**
 * Profil ve anchor handler'ları — SAHİBİ: Kişi 3
 *
 * Sözleşme: vivido-api-sozlesmesi.md §4
 *
 * Gerçek backend'in kurallarını taklit eder:
 *   · profil ilk PUT ile oluşur, yoksa 404 (K-C)
 *   · en fazla 3 anchor (MAX_ANCHORS)
 *   · silme sonrası öncelikler sıkıştırılır
 *   · sıralama isteği 4 maddeyle doğrulanır
 */

function anchorsOf(userId: string): Anchor[] {
  return mockDb.anchors.get(userId) ?? [];
}

function sorted(anchors: Anchor[]): Anchor[] {
  return [...anchors].sort((a, b) => a.priority - b.priority);
}

function fullProfile(userId: string): UserProfile | null {
  const base = mockDb.profiles.get(userId);
  if (!base) return null;
  return { ...base, anchors: sorted(anchorsOf(userId)) };
}

/** Her handler'ın başında: token var mı, profil var mı. */
function requireUser(request: Request): string | null {
  return userIdFromAuthHeader(request);
}

export const profileHandlers = [
  // ─── GET /profile ───
  http.get(`${API_BASE_URL}/profile`, ({ request }) => {
    const userId = requireUser(request);
    if (!userId) return problem(401, 'Oturum gerekli', 'TOKEN_EXPIRED');

    const profile = fullProfile(userId);
    if (!profile) {
      // K-C: profil persona seçilmeden var olamaz. Web bu 404'ü
      // "onboarding'e yönlendir" sinyali olarak kullanır.
      return problem(404, 'Profil henüz oluşturulmamış', 'PROFILE_NOT_FOUND');
    }
    return HttpResponse.json(profile);
  }),

  // ─── PUT /profile  (upsert) ───
  http.put(`${API_BASE_URL}/profile`, async ({ request }) => {
    const userId = requireUser(request);
    if (!userId) return problem(401, 'Oturum gerekli', 'TOKEN_EXPIRED');

    const body = (await request.json()) as UpdateProfileRequest;
    const existing = mockDb.profiles.get(userId);

    mockDb.profiles.set(userId, {
      id: existing?.id ?? newId(),
      personaCode: body.personaCode,
      monthlyBudget: body.monthlyBudget,
    });

    return HttpResponse.json(fullProfile(userId));
  }),

  // ─── GET /profile/anchors ───
  http.get(`${API_BASE_URL}/profile/anchors`, ({ request }) => {
    const userId = requireUser(request);
    if (!userId) return problem(401, 'Oturum gerekli', 'TOKEN_EXPIRED');
    return HttpResponse.json(sorted(anchorsOf(userId)));
  }),

  // ─── POST /profile/anchors ───
  http.post(`${API_BASE_URL}/profile/anchors`, async ({ request }) => {
    const userId = requireUser(request);
    if (!userId) return problem(401, 'Oturum gerekli', 'TOKEN_EXPIRED');

    if (!mockDb.profiles.has(userId)) {
      return problem(404, 'Önce persona seçmelisiniz', 'PROFILE_NOT_FOUND');
    }

    const current = anchorsOf(userId);
    if (current.length >= MAX_ANCHORS) {
      return problem(
        422,
        `En fazla ${MAX_ANCHORS} yer ekleyebilirsiniz`,
        'ANCHOR_LIMIT_EXCEEDED',
      );
    }

    const body = (await request.json()) as CreateAnchorRequest;
    const anchor: Anchor = {
      id: newId(),
      label: body.label,
      lat: body.lat,
      lon: body.lon,
      mode: body.mode,
      // K-G: önceliği sunucu atar — boş olan en küçük sıra.
      priority: current.length + 1,
    };

    mockDb.anchors.set(userId, [...current, anchor]);
    return HttpResponse.json(anchor, { status: 201 });
  }),

  // ─── DELETE /profile/anchors/{id} ───
  http.delete(`${API_BASE_URL}/profile/anchors/:id`, ({ request, params }) => {
    const userId = requireUser(request);
    if (!userId) return problem(401, 'Oturum gerekli', 'TOKEN_EXPIRED');

    const current = anchorsOf(userId);
    const remaining = current.filter((a) => a.id !== params.id);
    if (remaining.length === current.length) {
      return problem(404, 'Yer bulunamadı');
    }

    // ⚠️ Öncelikleri SIKIŞTIR. ② silinirse ③ → ② olmalı.
    // Yoksa `1, 3` boşluğu kalır ve DQ-06 kapısı kırılır.
    const compacted = sorted(remaining).map((a, i) => ({ ...a, priority: i + 1 }));
    mockDb.anchors.set(userId, compacted);

    return new HttpResponse(null, { status: 204 });
  }),

  // ─── PUT /profile/anchors/order ───  ⭐ W4'ün kalbi
  http.put(`${API_BASE_URL}/profile/anchors/order`, async ({ request }) => {
    const userId = requireUser(request);
    if (!userId) return problem(401, 'Oturum gerekli', 'TOKEN_EXPIRED');

    const body = (await request.json()) as ReorderAnchorsRequest;
    const current = anchorsOf(userId);
    const order = body.order ?? [];

    // Dört maddelik doğrulama — biri bile bozuksa öncelikler boşluklu
    // kalır ve geometrik ağırlık yanlış hesaplanır.
    const unique = new Set(order);
    const known = new Set(current.map((a) => a.id));

    const gecerli =
      order.length === current.length &&          // eksik yok
      unique.size === order.length &&             // tekrar yok
      order.every((id) => known.has(id));         // fazladan/başkasının yok

    if (!gecerli) {
      return problem(
        422,
        'Sıralama listesi geçersiz',
        'INVALID_ANCHOR_ORDER',
        'Liste, mevcut yerlerin tamamını tekrarsız içermelidir.',
      );
    }

    const reordered = order.map((id, i) => ({
      ...current.find((a) => a.id === id)!,
      priority: i + 1,
    }));
    mockDb.anchors.set(userId, reordered);

    return HttpResponse.json(reordered);
  }),
];
