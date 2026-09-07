import type { TokenPair } from '@vivido/shared';

/**
 * Token saklama.
 *
 * KARAR (vivido-api-sozlesmesi.md → K-A):
 *   · accessToken  → YALNIZCA BELLEKTE. Sayfa yenilenince kaybolur; bu kasıtlı.
 *   · refreshToken → localStorage. Yenilemeden sonra oturum devam etsin diye.
 *
 * Neden access token'ı diske yazmıyoruz: kısa ömürlü (15 dk) ve en sık
 * kullanılan token o. Bellekte tutmak XSS'in eline geçme yüzeyini daraltır.
 *
 * Bilinen takas: refreshToken localStorage'da olduğu için XSS ile okunabilir.
 * `httpOnly` cookie daha güvenli olurdu ama mobil (React Native) aynı
 * endpoint'leri kullanıyor ve orada cookie yönetimi ayrı bir akış gerektirirdi.
 * Sentetik veriyle çalışan bir demo için kabul edilen bir takas.
 */

const REFRESH_KEY = 'vivido.refreshToken';

let accessToken: string | null = null;

export function getAccessToken(): string | null {
  return accessToken;
}

export function getRefreshToken(): string | null {
  try {
    return localStorage.getItem(REFRESH_KEY);
  } catch {
    // Gizli sekme / depolama kapalı — oturum sekme ömrüyle sınırlı kalır.
    return null;
  }
}

export function setTokens(tokens: TokenPair): void {
  accessToken = tokens.accessToken;
  try {
    localStorage.setItem(REFRESH_KEY, tokens.refreshToken);
  } catch {
    /* yoksay — bellekteki access token ile devam edilir */
  }
}

export function clearTokens(): void {
  accessToken = null;
  try {
    localStorage.removeItem(REFRESH_KEY);
  } catch {
    /* yoksay */
  }
}
