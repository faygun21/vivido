import type { Anchor, AuthUser, RouteDetail, UserProfile } from '@vivido/shared';

/**
 * MSW handler'larının paylaştığı bellek içi durum.
 *
 * Sayfa yenilenince sıfırlanır — kasıtlı. Kalıcılık isteseydik gerçek
 * backend'i taklit etmeye başlar ve iki ayrı "doğru" üretirdik.
 *
 * Amaç gerçek bir veritabanı taklidi değil; arayüzün akışını
 * (kayıt → giriş → profil → anchor) uçtan uca çalıştırabilmek.
 */

interface MockUser {
  id: string;
  email: string;
  password: string;
  displayName: string | null;
  /** K-09: false iken giriş 403 EMAIL_NOT_VERIFIED alır. */
  emailVerified: boolean;
}

export const mockDb = {
  users: [] as MockUser[],
  /** userId → profil (anchors hariç) */
  profiles: new Map<string, Omit<UserProfile, 'anchors'>>(),
  /** userId → anchor listesi */
  anchors: new Map<string, Anchor[]>(),
  /** userId → oluşturulmuş rotalar (en yeni başta — backend CreatedAt sıralı döner) */
  routes: new Map<string, RouteDetail[]>(),
  /** geçerli refreshToken → userId */
  sessions: new Map<string, string>(),
};

export function newId(): string {
  return crypto.randomUUID();
}

export function toAuthUser(user: MockUser): AuthUser {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    emailVerified: user.emailVerified,
  };
}

/** `Authorization: Bearer <token>` başlığından kullanıcıyı çözer.
 *
 *  Sahte access token biçimi: `mock-access.<userId>`
 *  Gerçek JWT üretmeye çalışmıyoruz — doğrulama backend'in işi. */
export function userIdFromAuthHeader(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice('Bearer '.length);
  return token.startsWith('mock-access.') ? token.slice('mock-access.'.length) : null;
}

export function issueTokens(userId: string) {
  const refreshToken = `mock-refresh.${newId()}`;
  mockDb.sessions.set(refreshToken, userId);
  return {
    accessToken: `mock-access.${userId}`,
    refreshToken,
    expiresIn: 900,
  };
}
