import type { AuthResponse, ProblemDetails } from '@vivido/shared';
import { API_BASE_URL } from '@/shared/config';
import {
  clearTokens,
  getAccessToken,
  getRefreshToken,
  setTokens,
} from '@/shared/api/tokens';

/**
 * Tek API istemcisi. Uygulamada BAŞKA hiçbir yerde çıplak `fetch` çağrılmaz.
 *
 * Sorumlulukları:
 *   1. Base URL ekleme
 *   2. `Authorization: Bearer` başlığı
 *   3. 401 → token yenile → isteği bir kez tekrarla
 *   4. `problem+json` gövdesini ApiError'a çevirme
 */

/** Sunucudan gelen RFC 7807 gövdesini taşıyan hata.
 *
 *  Arayüz `problem.code`'a göre dallanır, `title` metnine göre DEĞİL —
 *  metin Türkçe ve değişebilir, kod sabittir. */
export class ApiError extends Error {
  // Alanlar açıkça yazılıyor: tsconfig'de `erasableSyntaxOnly` açık,
  // constructor parametre özellikleri (readonly status: number) kod ürettiği
  // için yasak.
  readonly status: number;
  readonly problem: ProblemDetails;

  constructor(status: number, problem: ProblemDetails) {
    super(problem.title || `HTTP ${status}`);
    this.name = 'ApiError';
    this.status = status;
    this.problem = problem;
  }
}

/** Ağ hatası / sunucuya hiç ulaşılamaması. `status` yoktur. */
export class NetworkError extends Error {
  constructor(cause: unknown) {
    super('Sunucuya ulaşılamadı');
    this.name = 'NetworkError';
    this.cause = cause;
  }
}

// ─────────────────────────────────────────────────────────────
//  Tek-uçuş (single-flight) yenileme
//
//  Aynı anda 5 istek 401 alırsa 5 kez /auth/refresh çağrılmamalı.
//  İlk çağrı promise'i buraya yazar, diğerleri onu bekler.
//
//  Bu ZORUNLU: refresh token rotasyonlu (K-E). Paralel iki yenileme
//  denemesinin ikincisi iptal edilmiş token gönderir, TOKEN_REVOKED
//  alır ve kullanıcı sebepsiz yere çıkış yer.
// ─────────────────────────────────────────────────────────────
let refreshInFlight: Promise<AuthResponse | null> | null = null;

/** Oturum düştüğünde haber verilecek yer — AuthContext buraya abone olur.
 *  Böylece istemci React'e bağımlı olmaz. */
let onSessionExpired: (() => void) | null = null;

export function setSessionExpiredHandler(handler: (() => void) | null): void {
  onSessionExpired = handler;
}

/** @returns yenilenen oturum, başarısızsa null */
async function refreshTokens(): Promise<AuthResponse | null> {
  const refreshToken = getRefreshToken();
  if (!refreshToken) return null;

  let response: Response;
  try {
    response = await fetch(`${API_BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    });
  } catch {
    // Ağ hatası — token'ları SİLME. Kullanıcı internetsiz kaldı diye
    // oturumu düşürmek, bağlantı geri geldiğinde yeniden giriş yaptırır.
    return null;
  }

  if (!response.ok) {
    // TOKEN_EXPIRED veya TOKEN_REVOKED — oturum gerçekten bitti.
    clearTokens();
    return null;
  }

  const auth = (await response.json()) as AuthResponse;
  setTokens(auth.tokens);
  return auth;
}

/** Yenilemeyi tek-uçuşlu çalıştırır. */
function refreshOnce(): Promise<AuthResponse | null> {
  refreshInFlight ??= refreshTokens().finally(() => {
    refreshInFlight = null;
  });
  return refreshInFlight;
}

// ─────────────────────────────────────────────────────────────

interface RequestOptions extends Omit<RequestInit, 'body'> {
  body?: unknown;
  /** true ise 401'de yenileme denenmez.
   *  `/auth/login`'den gelen 401 "şifre yanlış" demektir, "token eskidi" değil. */
  skipAuth?: boolean;
}

async function toProblem(response: Response): Promise<ProblemDetails> {
  try {
    const body = (await response.json()) as ProblemDetails;
    if (typeof body === 'object' && body !== null && 'title' in body) {
      return { ...body, status: body.status ?? response.status };
    }
  } catch {
    /* gövde JSON değil — aşağıdaki genel hataya düş */
  }
  return {
    type: 'about:blank',
    title: `Beklenmeyen hata (${response.status})`,
    status: response.status,
  };
}

async function send(path: string, options: RequestOptions): Promise<Response> {
  const { body, skipAuth, headers, ...rest } = options;
  const accessToken = getAccessToken();

  const finalHeaders = new Headers(headers);
  if (body !== undefined) finalHeaders.set('Content-Type', 'application/json');
  if (accessToken && !skipAuth) {
    finalHeaders.set('Authorization', `Bearer ${accessToken}`);
  }

  try {
    return await fetch(`${API_BASE_URL}${path}`, {
      ...rest,
      headers: finalHeaders,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch (cause) {
    throw new NetworkError(cause);
  }
}

/**
 * Gövdeyle birlikte HTTP durum kodunu da taşıyan sonuç.
 *
 * Yalnızca aynı uç noktanın iki farklı BAŞARILI yanıt verdiği yerlerde
 * gerekiyor: `POST /auth/register` doğrulama zorunluyken 202, kapalıyken
 * 201 döner ve gövdeler farklı (K-09). Diğer her yerde `api.post` yeterli.
 */
export interface ApiResult<T> {
  status: number;
  data: T;
}

/**
 * API çağrısı yapar.
 *
 * @throws {ApiError}     sunucu 4xx/5xx döndüyse
 * @throws {NetworkError} sunucuya ulaşılamadıysa
 */
export async function apiFetch<T>(
  path: string,
  options?: RequestOptions,
): Promise<T>;
export async function apiFetch<T>(
  path: string,
  options: RequestOptions,
  meta: { withStatus: true },
): Promise<ApiResult<T>>;
export async function apiFetch<T>(
  path: string,
  options: RequestOptions = {},
  meta?: { withStatus?: boolean },
): Promise<T | ApiResult<T>> {
  let response = await send(path, options);

  // 401 → bir kez yenile, isteği tekrarla.
  if (response.status === 401 && !options.skipAuth) {
    const refreshed = await refreshOnce();
    if (refreshed) {
      response = await send(path, options);
    } else {
      clearTokens();
      onSessionExpired?.();
    }
  }

  // Not: yenileme sonrası ikinci kez 401 gelirse tekrar denenmez.
  // Sonsuz döngüyü engelleyen şey bu.

  if (!response.ok) {
    throw new ApiError(response.status, await toProblem(response));
  }

  // 204 No Content — gövde yok (ör. DELETE /profile/anchors/{id})
  const data =
    response.status === 204 ? (undefined as T) : ((await response.json()) as T);

  return meta?.withStatus ? { status: response.status, data } : data;
}

export const api = {
  get:    <T>(path: string) => apiFetch<T>(path),
  post:   <T>(path: string, body?: unknown, opts?: RequestOptions) =>
            apiFetch<T>(path, { ...opts, method: 'POST', body }),
  put:    <T>(path: string, body?: unknown) =>
            apiFetch<T>(path, { method: 'PUT', body }),
  patch:  <T>(path: string, body?: unknown) =>
            apiFetch<T>(path, { method: 'PATCH', body }),
  delete: <T>(path: string) => apiFetch<T>(path, { method: 'DELETE' }),
};

/**
 * Uygulama açılışında çağrılır.
 *
 * Access token yalnızca bellekte olduğu için sayfa yenilenince kaybolur.
 * Elde refresh token varsa sessizce yeni bir access token alınır —
 * kullanıcı F5'e bastı diye çıkış yapmış olmaz.
 *
 * @returns geri yüklenen oturum, yoksa null
 */
export async function bootstrapSession(): Promise<AuthResponse | null> {
  if (!getRefreshToken()) return null;
  return refreshOnce();
}
