import { create } from 'zustand';
import type { RouteDetail } from '@vivido/shared';

/**
 * Haritada çizilecek AKTİF rota — R-121/123.
 *
 * Neden zustand: aktif rota iki ekranı birden etkiler —
 *   · Explore (çizgi + numaralı duraklar + metrik kartı)
 *   · Profil → Kayıtlı Rotalarım (tıklanan rota haritada açılır)
 *
 * Sayfa değişimi sırasında (profil → explore) rota durumunun taşınması
 * için React state tek başına yetmez; bu yüzden `authStore` ile aynı
 * desende, oturum ömrüyle sınırlı küçük bir store kullanıyoruz.
 * Sayfa yenilenince sıfırlanır — kalıcılık backend'dedir (R-123).
 *
 * ⚠️ BURADAKİ VERİ BİR KİŞİYE AİTTİR — rota, o hesabın kayıtlı rotası ve
 * durakları o hesabın konut seçimleri. Modül ömürlü olduğu için sayfa
 * değişimini DE oturum değişimini DE aşar: çıkış yapıp misafir olarak
 * devam eden kullanıcının haritasında önceki hesabın rotası çizili
 * kalıyordu. `SessionCacheSync` kimlik değiştiği an `reset()` çağırır —
 * `useSessionQuery`'nin sunucu önbelleği için yaptığının istemci
 * durumundaki karşılığı (bkz. `sessionQuery.ts`).
 *
 * ⛔ Oturum ömrünü aşan yeni bir istemci store'u eklenirse temizliği
 *    `SessionCacheSync`e de eklenmeli.
 */
interface RouteStoreState {
  /** Harita üzerinde çizilecek rota; null = çizgi yok. */
  activeRoute: RouteDetail | null;
  setActiveRoute: (route: RouteDetail | null) => void;
  /** Kimlik değişti — önceki kullanıcıya ait ne varsa düşür. */
  reset: () => void;
}

export const useRouteStore = create<RouteStoreState>((set) => ({
  activeRoute: null,
  setActiveRoute: (activeRoute) => set({ activeRoute }),
  reset: () => set({ activeRoute: null }),
}));
