/**
 * Kimlik doğrulama sözleşmesi.
 *
 * Kaynak: `vivido-api-sozlesmesi.md` §3 ve §4.
 * Bu dosya değişirse backend C# DTO'ları da değişmek zorundadır —
 * sözleşme PR'ı iki onay ister (backend + web).
 */

export interface RegisterRequest {
  email: string;
  password: string;
  displayName?: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface RefreshRequest {
  refreshToken: string;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  /** Access token ömrü, SANİYE cinsinden (varsayılan 900 = 15 dk). */
  expiresIn: number;
}

export interface AuthUser {
  id: string;
  email: string;
  displayName: string | null;
  /** E-posta doğrulandı mı? Doğrulanmamış hesapla giriş yapılamaz (K-09). */
  emailVerified: boolean;
}

/** Kayıt sonrası e-postaya gelen 6 haneli kod. */
export interface VerifyEmailRequest {
  email: string;
  code: string;
}

export interface ResendVerificationRequest {
  email: string;
}

/** "Şifremi unuttum" — e-postaya sıfırlama kodu gönderir. */
export interface ForgotPasswordRequest {
  email: string;
}

export interface ResetPasswordRequest {
  email: string;
  code: string;
  newPassword: string;
}

/**
 * `POST /auth/register` doğrulama beklerken dönen gövde — **HTTP 202**.
 *
 * Aynı uç nokta doğrulama kapalıyken (`Auth:RequireEmailVerification=false`)
 * 201 + {@link AuthResponse} döner. İstemci ikisini HTTP durum koduyla ayırır:
 * 202 → önce kod girilecek, 201 → oturum açıldı.
 */
export interface PendingVerificationResponse {
  status: 'verification_required';
  email: string;
  /** Kodun geçerlilik süresi, DAKİKA. */
  expiresInMinutes: number;
  message: string;
}

/** Gövdesi olmayan başarı yanıtlarının ortak zarfı. */
export interface MessageResponse {
  status: string;
  message: string;
}

/**
 * `register`, `login` ve `refresh` — üçü de AYNI gövdeyi döner.
 *
 * Bu bilinçli bir karar: arayüz tek bir işleme fonksiyonu yazar,
 * üç ayrı yol tutmaz. Backend bunu üç farklı DTO'ya bölmemeli.
 */
export interface AuthResponse {
  user: AuthUser;
  tokens: TokenPair;
}
