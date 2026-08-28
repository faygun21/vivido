import { http, HttpResponse } from 'msw';
import type {
  AuthResponse,
  ForgotPasswordRequest,
  LoginRequest,
  MessageResponse,
  PendingVerificationResponse,
  RefreshRequest,
  RegisterRequest,
  ResendVerificationRequest,
  ResetPasswordRequest,
  VerifyEmailRequest,
} from '@vivido/shared';
import { API_BASE_URL } from '@/shared/config';
import { issueTokens, mockDb, newId, toAuthUser } from '@/mocks/db';
import { problem, validationProblem } from '@/mocks/problem';

/**
 * Auth handler'ları — SAHİBİ: Kişi 1
 *
 * Sözleşme: vivido-api-sozlesmesi.md §4
 * Backend `/auth/*` endpoint'lerini yayınlayınca bu dosya silinir.
 *
 * K-09 akışı burada da birebir taklit ediliyor: kayıt 202 döner, kod
 * girilene kadar giriş 403. Mock'u gerçek davranıştan sadeleştirirsek
 * doğrulama yolunun hataları ilk kez gerçek backend'de görülür.
 *
 * ⚠️ Kod her zaman `MOCK_CODE` — gerçek e-posta göndermiyoruz.
 */
const MOCK_CODE = '123456';
const CODE_TTL_MINUTES = 15;

function normalize(email: string | undefined): string {
  return (email ?? '').trim().toLowerCase();
}

function findUser(email: string | undefined) {
  const target = normalize(email);
  // users.email sütunu `citext` — büyük/küçük harf duyarsız karşılaştırma.
  return mockDb.users.find((u) => u.email.toLowerCase() === target);
}

function pending(email: string) {
  const body: PendingVerificationResponse = {
    status: 'verification_required',
    email,
    expiresInMinutes: CODE_TTL_MINUTES,
    message:
      `${email} adresine 6 haneli bir doğrulama kodu gönderdik. ` +
      `Kod ${CODE_TTL_MINUTES} dakika geçerli. (Mock: ${MOCK_CODE})`,
  };
  return HttpResponse.json(body, { status: 202 });
}

export const authHandlers = [
  // ─── POST /auth/register ───
  http.post(`${API_BASE_URL}/auth/register`, async ({ request }) => {
    const body = (await request.json()) as RegisterRequest;
    const email = (body.email ?? '').trim();

    const errors: Record<string, string[]> = {};
    if (!email.includes('@')) {
      errors.email = ['Geçerli bir e-posta adresi girin.'];
    }
    if (!body.password || body.password.length < 8) {
      errors.password = ['En az 8 karakter olmalı.'];
    }
    if (Object.keys(errors).length > 0) return validationProblem(errors);

    const existing = findUser(email);

    // Doğrulanmış hesap → 409. Doğrulanmamış hesap → kayıt tazelenir,
    // kullanıcı duvara toslamaz (gerçek backend ile aynı kural).
    if (existing?.emailVerified) {
      return problem(
        409,
        'Bu e-posta zaten kayıtlı',
        'EMAIL_ALREADY_EXISTS',
        `${email} adresiyle bir hesap mevcut.`,
      );
    }

    if (existing) {
      existing.password = body.password;
      if (body.displayName) existing.displayName = body.displayName;
      return pending(email);
    }

    mockDb.users.push({
      id: newId(),
      email,
      password: body.password,
      displayName: body.displayName ?? null,
      emailVerified: false,
      isAdmin: false,
    });

    return pending(email);
  }),

  // ─── POST /auth/verify-email ───
  http.post(`${API_BASE_URL}/auth/verify-email`, async ({ request }) => {
    const body = (await request.json()) as VerifyEmailRequest;
    const user = findUser(body.email);

    // Kullanıcı yoksa da INVALID_CODE — "bu e-posta kayıtlı değil" demek
    // kayıtlı adresleri tarayan birine bedava bilgi vermek olur.
    if (!user) return problem(400, 'Kod geçersiz', 'INVALID_CODE');

    if (!user.emailVerified && body.code !== MOCK_CODE) {
      return problem(
        400,
        'Kod geçersiz',
        'INVALID_CODE',
        `Mock ortamında kod her zaman ${MOCK_CODE}.`,
      );
    }

    user.emailVerified = true;

    const response: AuthResponse = {
      user: toAuthUser(user),
      tokens: issueTokens(user.id),
    };
    return HttpResponse.json(response);
  }),

  // ─── POST /auth/resend-verification ───
  http.post(`${API_BASE_URL}/auth/resend-verification`, async ({ request }) => {
    const body = (await request.json()) as ResendVerificationRequest;
    // Hesap yoksa bile 202 — numaralandırmaya kapalı.
    return pending((body.email ?? '').trim());
  }),

  // ─── POST /auth/login ───
  http.post(`${API_BASE_URL}/auth/login`, async ({ request }) => {
    const body = (await request.json()) as LoginRequest;
    const user = findUser(body.email);

    // E-posta yok ve şifre yanlış AYNI cevabı döner —
    // ayırmak saldırgana hangi e-postaların kayıtlı olduğunu söyler.
    if (!user || user.password !== body.password) {
      return problem(401, 'E-posta veya şifre hatalı', 'INVALID_CREDENTIALS');
    }

    // ⚠️ Sıra önemli: doğrulama kontrolü şifreden SONRA.
    if (!user.emailVerified) {
      return problem(
        403,
        'E-posta adresi doğrulanmamış',
        'EMAIL_NOT_VERIFIED',
        'Giriş yapabilmek için e-postanıza gönderilen 6 haneli kodu girin.',
      );
    }

    const response: AuthResponse = {
      user: toAuthUser(user),
      tokens: issueTokens(user.id),
    };
    return HttpResponse.json(response);
  }),

  // ─── POST /auth/forgot-password ───
  http.post(`${API_BASE_URL}/auth/forgot-password`, async ({ request }) => {
    const body = (await request.json()) as ForgotPasswordRequest;
    const email = (body.email ?? '').trim();

    // Hesap var olmasa bile HER ZAMAN 202 — bu uç noktanın
    // "bu e-posta kayıtlı mı?" sorusuna cevap vermemesi gerekiyor.
    const response: MessageResponse = {
      status: 'reset_code_sent',
      message:
        `${email} adresi kayıtlıysa 6 haneli bir sıfırlama kodu gönderdik. ` +
        `(Mock: ${MOCK_CODE})`,
    };
    return HttpResponse.json(response, { status: 202 });
  }),

  // ─── POST /auth/reset-password ───
  http.post(`${API_BASE_URL}/auth/reset-password`, async ({ request }) => {
    const body = (await request.json()) as ResetPasswordRequest;

    if (!body.newPassword || body.newPassword.length < 8) {
      return validationProblem({ newPassword: ['En az 8 karakter olmalı.'] });
    }

    const user = findUser(body.email);
    if (!user || body.code !== MOCK_CODE) {
      return problem(400, 'Kod geçersiz', 'INVALID_CODE');
    }

    user.password = body.newPassword;
    // Kodu e-postasından okuyabilen kişi adresin sahibidir.
    user.emailVerified = true;

    // Gerçek backend tüm refresh token'ları iptal ediyor; mock'ta da
    // aynısını yapmazsak "sıfırladım ama eski sekme hâlâ açık" farkı
    // ilk kez üretimde görülür.
    for (const [token, userId] of mockDb.sessions) {
      if (userId === user.id) mockDb.sessions.delete(token);
    }

    const response: MessageResponse = {
      status: 'password_reset',
      message: 'Şifreniz güncellendi. Yeni şifrenizle giriş yapabilirsiniz.',
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
