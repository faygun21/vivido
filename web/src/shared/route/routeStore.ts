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
 */
interface RouteStoreState {
  /** Harita üzerinde çizilecek rota; null = çizgi yok. */
  activeRoute: RouteDetail | null;
  setActiveRoute: (route: RouteDetail | null) => void;
}

export const useRouteStore = create<RouteStoreState>((set) => ({
  activeRoute: null,
  setActiveRoute: (activeRoute) => set({ activeRoute }),
}));
