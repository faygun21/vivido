import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { useAuthStore } from '@/features/auth/authStore';
import { useRouteStore } from '@/shared/route/routeStore';

/**
 * Kimlik değişince önceki kullanıcıya ait ne varsa düşürür — SAHİBİ: Kişi 1
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
 *
 * ⭐ SUNUCU ÖNBELLEĞİ TEK BAŞINA YETMİYOR
 *
 * Kimliğe ait veri yalnızca TanStack'in önbelleğinde durmuyor; sunucudan
 * bir kez okunup İSTEMCİ DURUMUNA kopyalanan şeyler de var. `activeRoute`
 * böyle: kullanıcı kayıtlı bir rotayı açtığında `useRouteStore`a yazılıyor
 * ve o store modül ömürlü — sayfa değişimini de oturum değişimini de aşar.
 * `queryClient.clear()` ona dokunmadığı için çıkış yapıp misafir olarak
 * devam eden kullanıcının haritasında önceki hesabın rotası çizili
 * kalıyordu.
 *
 * ⛔ Oturum ömrünü aşan (modül ömürlü) yeni bir istemci store'u eklenirse
 *    temizliği BURAYA eklenmeli — kimlik değişiminin tek kapısı burası.
 */
export function SessionCacheSync() {
  const queryClient = useQueryClient();

  useEffect(() => {
    return useAuthStore.subscribe((state, previous) => {
      if (state.sessionKey === previous.sessionKey) return;
      queryClient.clear();
      useRouteStore.getState().reset();
    });
  }, [queryClient]);

  return null;
}
