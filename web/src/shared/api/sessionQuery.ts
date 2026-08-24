import { useQuery, type UseQueryOptions, type UseQueryResult } from '@tanstack/react-query';
import { useAuthStore } from '@/features/auth/authStore';

/**
 * Oturuma bağlı sunucu verisi için tek giriş kapısı — SAHİBİ: Kişi 1
 *
 * ⭐ NEDEN VAR
 *
 * Sunucudan gelen profil / anchor / favori / rota verisi BİR KİŞİYE aittir.
 * Doğrudan `useQuery({ queryKey: ['profile'] })` yazıldığında bu bilgi
 * hiçbir yerde durmuyordu ve şu hata çıktı:
 *
 *   A hesabıyla pin eklendi → çıkış yapıldı → misafir olarak gezildi
 *   → pinler HÂLÂ haritada. B hesabıyla girildi → yine A'nın pinleri.
 *
 * İki ayrı sebep vardı, ikisi de burada kapanıyor:
 *
 * 1. **Anahtar kimliğe bağlı değildi.** `['profile']` herkes için aynı
 *    kutuydu; B kullanıcısı A'nın kutusunu açıyordu.
 * 2. **`enabled: false` veriyi GİZLEMEZ.** Yaygın yanılgı: "misafirken
 *    istek atmıyoruz, o hâlde veri de görünmez." Hayır — `useQuery`
 *    istek atmasa bile önbellekteki `data`yı döndürür. Misafir ekranında
 *    A'nın pinlerini çizen tam olarak buydu.
 *
 * ⭐ NASIL ÇALIŞIR
 *
 * Anahtarın SONUNA oturum kimliği eklenir: `['anchors'] → ['anchors', 'user:42']`.
 * Sona eklenmesi kasıtlı — TanStack Query önek eşleşmesi yaptığı için
 * `invalidateQueries({ queryKey: ['anchors'] })` çağrıları OLDUĞU GİBİ
 * çalışmaya devam eder, mutasyonlarda kimlik taşımak gerekmez.
 *
 * Ayrıca `enabled` otomatik olarak "giriş yapılmış mı" koşuluyla VE'lenir:
 * misafirken korumalı uç noktaya istek atılmaz. Atılsaydı
 * `401 → yenileme → refresh token yok → onSessionExpired → clearSession`
 * zinciri çalışır ve misafir kendi kendini kapı dışarı ederdi (K-10).
 *
 * İkinci savunma hattı `SessionCacheSync`: kimlik değiştiği an önbelleğin
 * TAMAMI boşaltılır. Anahtar kapsamı "yanlış veriyi okuma"yı, temizlik ise
 * "eski kullanıcının verisi bellekte kalması"nı engeller.
 *
 * ⛔ Oturuma bağlı bir uç nokta için doğrudan `useQuery` YAZMAYIN.
 *    Kimliğe bağlı olmayan veri (harita GeoJSON'ları gibi) zaten bu
 *    dosyadan geçmez.
 */

/** Aktif oturum kimliği — `user:<id>` | `guest` | `anon`. */
export function useSessionKey(): string {
  return useAuthStore((s) => s.sessionKey);
}

/** Kullanıcı gerçekten giriş yapmış mı? Misafir bu sorunun cevabında HAYIR'dır. */
export function useIsAuthenticated(): boolean {
  return useAuthStore((s) => s.status === 'authenticated');
}

type SessionQueryOptions<TData> = Omit<
  UseQueryOptions<TData, Error, TData, readonly unknown[]>,
  'queryKey'
> & {
  /**
   * Kimlik kısmı OLMADAN anahtar: `['anchors']`, `['properties', 'map']` …
   * Oturum kimliği sona eklenir.
   */
  queryKey: readonly unknown[];
};

/**
 * Oturum kapsamlı `useQuery`.
 *
 * Kullanımı normal `useQuery` ile aynı; tek fark anahtarı kimliksiz
 * vermeniz ve `enabled` için giriş kontrolü yazmanıza gerek olmaması.
 */
export function useSessionQuery<TData>(
  options: SessionQueryOptions<TData>,
): UseQueryResult<TData, Error> {
  const sessionKey = useSessionKey();
  const authenticated = useIsAuthenticated();
  const { queryKey, enabled, ...rest } = options;

  return useQuery({
    ...rest,
    queryKey: [...queryKey, sessionKey] as const,
    // Çağıran ek bir koşul verdiyse ONUNLA BİRLİKTE geçerli olmalı;
    // giriş koşulunu ezmesine izin verilmez.
    enabled: authenticated && (enabled ?? true),
  });
}
