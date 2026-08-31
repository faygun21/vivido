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
 * `GET /profile` 404 döner ve bu "ilk kayıt" sinyalidir — yaşam tarzı
 * seçimine gider. Profili olan (ister lifestyle ister onboarding'den
 * geçmiş) kullanıcı zaten HOME_PATH'e gidiyor; oraya tekrar "değiştirmek"
 * için gelmek istersen `/profile` → "Persona / kira aralığı değiştir"
 * linki `/onboarding`'e götürüyor.
 */
export async function routeAfterAuth(
  navigate: (to: string, opts?: { replace?: boolean }) => void,
  from?: string,
): Promise<void> {
  try {
    const profile = await api.get<{ minMonthlyBudget: number | null; maxMonthlyBudget: number | null }>(
      '/profile',
    );

    // Sihirbaz (lifestyle → preferences → budget) yarıda bırakılmış olabilir:
    // her adım profili KISMEN kaydediyor, yani `GET /profile` 404 vermez
    // ama bütçe hâlâ boş kalabiliyor. Bu durumda kullanıcıyı ana ekrana
    // (HOME_PATH) göndermek, bütçe filtresi hiç uygulanmadan tüm evleri
    // gösteren, sessizce kişiselleştirmesiz bir deneyime yol açıyordu —
    // sihirbaza geri gönderip tamamlatıyoruz.
    if (profile.minMonthlyBudget == null && profile.maxMonthlyBudget == null) {
      navigate('/lifestyle', { replace: true });
      return;
    }

    navigate(from ?? HOME_PATH, { replace: true });
  } catch {
    // 404 → profil yok, ilk kayıt. Başka bir hata olsa bile lifestyle
    // güvenli varış noktası: kullanıcı oradan profilini oluşturabiliyor.
    navigate('/lifestyle', { replace: true });
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
