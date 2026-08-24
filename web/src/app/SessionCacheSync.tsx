import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { useAuthStore } from '@/features/auth/authStore';

/**
 * Kimlik değişince sunucu önbelleğini boşaltır — SAHİBİ: Kişi 1
 *
 * `useSessionQuery` anahtarları kimliğe bağlıyor, yani B kullanıcısı
 * A'nın kutusunu AÇAMIYOR. Bu bileşen ikinci savunma hattı: A'nın verisi
 * bellekte ÖYLECE DURMASIN.
 *
 * İkisi de gerekli:
 *   · Yalnız anahtar kapsamı → veri okunmaz ama bellekte kalır; çıkış
 *     yapan kullanıcının profili sekme kapanana kadar RAM'de durur.
 *   · Yalnız temizlik → efekt render'DAN SONRA çalışır; arada bir kare
 *     boyunca yeni kimlik eski veriyle çizilebilir.
 *
 * Zustand'ın `subscribe`'ı `set()` içinde SENKRON çağrılır: temizlik,
 * React yeni kimliği boyamadan önce biter. `queryClient.clear()` hem
 * önbelleği hem de uçuştaki sorguları düşürür.
 *
 * Neden `status` değil `sessionKey` dinleniyor: token yenilemesi de
 * `setSession` çağırır. `status` karşılaştırsaydık her yenilemede
 * önbellek boşuna düşer, kullanıcı 15 dakikada bir boş ekran görürdü.
 */
export function SessionCacheSync() {
  const queryClient = useQueryClient();

  useEffect(() => {
    return useAuthStore.subscribe((state, previous) => {
      if (state.sessionKey === previous.sessionKey) return;
      queryClient.clear();
    });
  }, [queryClient]);

  return null;
}
