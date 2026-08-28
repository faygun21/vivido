import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { AuthResponse } from '@vivido/shared';
import { apiFetch, ApiError } from '@/shared/api/client';
import { clearTokens, setTokens } from '@/shared/api/tokens';

/**
 * API istemcisi testleri.
 *
 * Buradaki asıl hedef TEK-UÇUŞ yenileme: aynı anda birden fazla istek
 * 401 alırsa `/auth/refresh` YALNIZCA BİR KEZ çağrılmalı.
 *
 * Neden önemli: refresh token rotasyonlu (sözleşme K-E). İkinci bir
 * yenileme çağrısı iptal edilmiş token gönderir, TOKEN_REVOKED alır ve
 * kullanıcı sebepsiz yere çıkış yer. Bu hata elle test edilirken
 * neredeyse hiç yakalanmaz — yarış durumu olduğu için ancak yük altında
 * ortaya çıkar.
 */

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

const freshAuth: AuthResponse = {
  user: { id: 'u1', email: 'a@b.com', displayName: null, emailVerified: true, isAdmin: false,},
  tokens: { accessToken: 'yeni-access', refreshToken: 'yeni-refresh', expiresIn: 900 },
};

beforeEach(() => {
  clearTokens();
  setTokens({ accessToken: 'eski-access', refreshToken: 'eski-refresh', expiresIn: 900 });
});

afterEach(() => {
  vi.unstubAllGlobals();
  clearTokens();
});

describe('apiFetch — token yenileme', () => {
  it('paralel 401 isteklerinde /auth/refresh yalnızca BİR kez çağrılır', async () => {
    let refreshCalls = 0;
    let accessTokenYenilendi = false;

    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string) => {
        if (url.endsWith('/auth/refresh')) {
          refreshCalls++;
          // Gerçek ağ gecikmesini taklit et — gecikme olmazsa çağrılar
          // sıraya girer ve yarış durumu hiç oluşmaz, test yalancı geçer.
          await new Promise((r) => setTimeout(r, 10));
          accessTokenYenilendi = true;
          return jsonResponse(freshAuth);
        }
        return accessTokenYenilendi
          ? jsonResponse({ ok: true })
          : jsonResponse({ title: 'Süre doldu' }, 401);
      }),
    );

    const sonuclar = await Promise.all([
      apiFetch<{ ok: boolean }>('/profile'),
      apiFetch<{ ok: boolean }>('/personas'),
      apiFetch<{ ok: boolean }>('/profile/anchors'),
    ]);

    expect(refreshCalls).toBe(1);
    expect(sonuclar.every((s) => s.ok)).toBe(true);
  });

  it('yenileme başarısız olursa oturum düşer ve hata fırlatılır', async () => {
    const oturumDustu = vi.fn();
    const { setSessionExpiredHandler } = await import('@/shared/api/client');
    setSessionExpiredHandler(oturumDustu);

    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string) =>
        url.endsWith('/auth/refresh')
          ? jsonResponse({ title: 'İptal edildi', code: 'TOKEN_REVOKED' }, 401)
          : jsonResponse({ title: 'Süre doldu' }, 401),
      ),
    );

    await expect(apiFetch('/profile')).rejects.toBeInstanceOf(ApiError);
    expect(oturumDustu).toHaveBeenCalledOnce();

    setSessionExpiredHandler(null);
  });

  it('skipAuth verilen istekte 401 alınca yenileme DENENMEZ', async () => {
    // /auth/login'den gelen 401 "şifre yanlış" demektir, "token eskidi" değil.
    // Yenilemeye kalkmak anlamsız bir istek daha üretir.
    let refreshCalls = 0;

    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string) => {
        if (url.endsWith('/auth/refresh')) refreshCalls++;
        return jsonResponse(
          { title: 'E-posta veya şifre hatalı', code: 'INVALID_CREDENTIALS' },
          401,
        );
      }),
    );

    await expect(
      apiFetch('/auth/login', { method: 'POST', body: {}, skipAuth: true }),
    ).rejects.toBeInstanceOf(ApiError);

    expect(refreshCalls).toBe(0);
  });
});

describe('apiFetch — hata dönüşümü', () => {
  it('problem+json gövdesi ApiError.problem içine taşınır', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () =>
        jsonResponse(
          {
            type: 'https://vivido.dev/errors/email-already-exists',
            title: 'Bu e-posta zaten kayıtlı',
            status: 409,
            code: 'EMAIL_ALREADY_EXISTS',
          },
          409,
        ),
      ),
    );

    const hata = await apiFetch('/auth/register', {
      method: 'POST',
      body: {},
      skipAuth: true,
    }).catch((e: unknown) => e);

    expect(hata).toBeInstanceOf(ApiError);
    expect((hata as ApiError).status).toBe(409);
    // Arayüz `title` metnine değil `code`'a bakar — sözleşme K-D.
    expect((hata as ApiError).problem.code).toBe('EMAIL_ALREADY_EXISTS');
  });

  it('204 No Content gövdesiz döner', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(null, { status: 204 })));
    await expect(apiFetch('/profile/anchors/abc')).resolves.toBeUndefined();
  });
});
