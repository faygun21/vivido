import { ApiError, NetworkError, api } from '@/shared/api/client';

/**
 * Giriş ve kayıt sayfalarının paylaştığı yardımcılar.
 *
 * Ayrı dosyada çünkü bileşen dosyasından bileşen olmayan şeyler dışa
 * aktarılınca Vite'ın fast-refresh'i o dosya için devre dışı kalıyor.
 */

/**
 * Giriş yapmış kullanıcının "ana menüsü".
 *
 * Logo/marka bağlantısı buraya gider — kullanıcı zaten içerideyken onu
 * tanıtım sayfasına ve oradan giriş formuna geri atmak, "yeniden giriş
 * yapmam mı gerekiyor?" hissi yaratıyordu.
 */
export const HOME_PATH = '/explore';

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
    navigate(from ?? HOME_PATH, { replace: true });
  } catch (error) {
    // Yalnızca gerçekten profil yoksa onboarding'e git. 500/ağ hatasını burada
    // yutmak giriş başarılıymış gibi gösteriyor ve asıl sunucu arızasını
    // kullanıcının profil kaydetme adımına kadar gizliyordu.
    if (
      error instanceof ApiError &&
      (error.status === 404 || error.problem.code === 'PROFILE_NOT_FOUND')
    ) {
      navigate('/onboarding', { replace: true });
      return;
    }

    throw error;
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
      case 'EMAIL_NOT_VERIFIED':
        return 'E-posta adresiniz henüz doğrulanmamış. Size gönderdiğimiz kodu girin.';
      case 'INVALID_CODE':
        return 'Kod hatalı. E-postadaki 6 haneli kodu kontrol edip tekrar deneyin.';
      case 'CODE_EXPIRED':
        return 'Kodun süresi doldu. "Kodu tekrar gönder" ile yenisini isteyin.';
      case 'TOO_MANY_ATTEMPTS':
        return 'Çok fazla hatalı deneme yapıldı. "Kodu tekrar gönder" ile yeni bir kod isteyin.';
      case 'RESEND_TOO_SOON':
        return 'Çok sık kod istiyorsunuz. Bir dakika bekleyip tekrar deneyin.';
      case 'EMAIL_SEND_FAILED':
        return 'Doğrulama e-postası gönderilemedi. Birkaç dakika sonra tekrar deneyin.';
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

/** Hatanın belirli bir sözleşme kodu olup olmadığını sorar. */
export function hasErrorCode(err: unknown, code: string): boolean {
  return err instanceof ApiError && err.problem.code === code;
}
