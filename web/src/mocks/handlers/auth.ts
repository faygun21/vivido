import { http, HttpResponse } from 'msw';
import type {
  AuthResponse,
  LoginRequest,
  RefreshRequest,
  RegisterRequest,
} from '@vivido/shared';
import { API_BASE_URL } from '@/shared/config';
import { issueTokens, mockDb, newId, toAuthUser } from '@/mocks/db';
import { problem, validationProblem } from '@/mocks/problem';

/**
 * Auth handler'ları — SAHİBİ: Kişi 1
 *
 * Sözleşme: vivido-api-sozlesmesi.md §4
 * Backend `/auth/*` endpoint'lerini yayınlayınca bu dosya silinir.
 */

export const authHandlers = [
  // ─── POST /auth/register ───
  http.post(`${API_BASE_URL}/auth/register`, async ({ request }) => {
    const body = (await request.json()) as RegisterRequest;

    const errors: Record<string, string[]> = {};
    if (!body.email?.includes('@')) {
      errors.email = ['Geçerli bir e-posta adresi girin.'];
    }
    if (!body.password || body.password.length < 8) {
      errors.password = ['En az 8 karakter olmalı.'];
    }
    if (Object.keys(errors).length > 0) return validationProblem(errors);

    // users.email sütunu `citext` — büyük/küçük harf duyarsız karşılaştırma.
    const exists = mockDb.users.some(
      (u) => u.email.toLowerCase() === body.email.toLowerCase(),
    );
    if (exists) {
      return problem(
        409,
        'Bu e-posta zaten kayıtlı',
        'EMAIL_ALREADY_EXISTS',
        `${body.email} adresiyle bir hesap mevcut.`,
      );
    }

    const user = {
      id: newId(),
      email: body.email,
      password: body.password,
      displayName: body.displayName ?? null,
    };
    mockDb.users.push(user);

    const response: AuthResponse = {
      user: toAuthUser(user),
      tokens: issueTokens(user.id),
    };
    return HttpResponse.json(response, { status: 201 });
  }),

  // ─── POST /auth/login ───
  http.post(`${API_BASE_URL}/auth/login`, async ({ request }) => {
    const body = (await request.json()) as LoginRequest;

    const user = mockDb.users.find(
      (u) => u.email.toLowerCase() === body.email?.toLowerCase(),
    );

    // E-posta yok ve şifre yanlış AYNI cevabı döner —
    // ayırmak saldırgana hangi e-postaların kayıtlı olduğunu söyler.
    if (!user || user.password !== body.password) {
      return problem(401, 'E-posta veya şifre hatalı', 'INVALID_CREDENTIALS');
    }

    const response: AuthResponse = {
      user: toAuthUser(user),
      tokens: issueTokens(user.id),
    };
    return HttpResponse.json(response);
  }),

  // ─── POST /auth/refresh ───
  http.post(`${API_BASE_URL}/auth/refresh`, async ({ request }) => {
    const body = (await request.json()) as RefreshRequest;
    const userId = mockDb.sessions.get(body.refreshToken);

    if (!userId) {
      return problem(401, 'Oturum süresi doldu', 'TOKEN_REVOKED');
    }

    // Rotasyon (K-E): eski token iptal edilir, yenisi verilir.
    mockDb.sessions.delete(body.refreshToken);

    const user = mockDb.users.find((u) => u.id === userId);
    if (!user) return problem(401, 'Oturum geçersiz', 'TOKEN_REVOKED');

    const response: AuthResponse = {
      user: toAuthUser(user),
      tokens: issueTokens(user.id),
    };
    return HttpResponse.json(response);
  }),
];
