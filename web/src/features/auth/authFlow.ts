import { ApiError, NetworkError, api } from '@/shared/api/client';

/**
 * Giriş ve kayıt sayfalarının paylaştığı yardımcılar.
 *
 * Ayrı dosyada çünkü bileşen dosyasından bileşen olmayan şeyler dışa
 * aktarılınca Vite'ın fast-refresh'i o dosya için devre dışı kalıyor.
 */

/**
 * Kimlik doğrulamadan sonra nereye gidileceğini belirler.
 *
 * K-C: profil ilk `PUT /profile` ile oluşur, o yüzden yeni kullanıcıda
 * `GET /profile` 404 döner ve bu "onboarding'e git" sinyalidir.
 */
export async function routeAfterAuth(
  navigate: (to: string, opts?: { replace?: boolean }) => void,
  from?: string,
): Promise<void> {
  try {
    await api.get('/profile');
    navigate(from ?? '/explore', { replace: true });
  } catch {
    // 404 → profil yok. Başka bir hata olsa bile onboarding güvenli varış
    // noktası: kullanıcı oradan profilini oluşturabiliyor.
    navigate('/onboarding', { replace: true });
  }
}

/** Hata gövdesindeki `code` alanına göre mesaj — `title` metnine göre DEĞİL (K-D). */
export function describeAuthError(err: unknown): string {
  if (err instanceof NetworkError) {
    return 'Sunucuya ulaşılamadı. API çalışıyor mu? (pnpm dev:api)';
  }

  if (err instanceof ApiError) {
    switch (err.problem.code) {
      case 'INVALID_CREDENTIALS':
        return 'E-posta veya şifre hatalı.';
      case 'EMAIL_ALREADY_EXISTS':
        return 'Bu e-posta zaten kayıtlı. Giriş yapmayı deneyin.';
      default:
        break;
    }

    // Doğrulama hatası — alan bazlı mesajları birleştir.
    if (err.problem.errors) {
      return Object.values(err.problem.errors).flat().join(' ');
    }
    return err.problem.title;
  }

  return 'Beklenmeyen bir hata oluştu.';
}
