/**
 * Hata sözleşmesi — RFC 7807 `application/problem+json`.
 *
 * KURAL: Arayüz `title` metnine göre dallanmaz, `code`'a göre dallanır.
 * `title` Türkçe ve değişebilir; `code` sabittir.
 *
 *   ✅  if (problem.code === 'EMAIL_ALREADY_EXISTS')
 *   ❌  if (problem.title === 'Bu e-posta zaten kayıtlı')
 *
 * Yeni bir kod gerekiyorsa önce `vivido-api-sozlesmesi.md` güncellenir,
 * sonra buraya eklenir — iki taraf da aynı listeye bakmalı.
 */

export type ErrorCode =
  | 'EMAIL_ALREADY_EXISTS'
  | 'INVALID_CREDENTIALS'
  | 'TOKEN_EXPIRED'
  | 'TOKEN_REVOKED'
  | 'PROFILE_NOT_FOUND'
  | 'ANCHOR_LIMIT_EXCEEDED'
  | 'INVALID_ANCHOR_ORDER';

export interface ProblemDetails {
  type: string;
  /** İnsan tarafından okunur, Türkçe. Mantık buna dayandırılmaz. */
  title: string;
  status: number;
  detail?: string;
  /** Makine tarafından okunur. Arayüz kararlarını bu belirler. */
  code?: ErrorCode;
  /** Doğrulama hataları: { alanAdı: [mesajlar] } — ASP.NET Core üretir. */
  errors?: Record<string, string[]>;
}

/** Yakalanan bir hatanın ProblemDetails olup olmadığını anlamak için.
 *  `catch` bloğunda gelen değer `unknown` olduğu için gerekli. */
export function isProblemDetails(value: unknown): value is ProblemDetails {
  return (
    typeof value === 'object' &&
    value !== null &&
    'status' in value &&
    'title' in value
  );
}
