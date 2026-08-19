import { create } from 'zustand';
import type { AuthResponse, AuthUser } from '@vivido/shared';
import { clearTokens, setTokens } from '@/shared/api/tokens';

/**
 * Oturum durumu — SAHİBİ: Kişi 1
 *
 * Yalnızca DURUM tutar; ağ çağrısı yapmaz. Giriş/kayıt istekleri
 * `features/auth` altındaki sayfalarda yapılır, sonuç buraya yazılır.
 *
 * `status` üç değerli çünkü ikisi yetmiyor: uygulama açılışında elimizde
 * refresh token varsa yeni access token alınana kadar "giriş yapmış mı"
 * sorusunun cevabı HENÜZ BİLİNMİYOR. İki değerli olsaydı o aralıkta
 * kullanıcı bir an login ekranına atılırdı.
 */
export type AuthStatus = 'unknown' | 'authenticated' | 'anonymous';

interface AuthState {
  status: AuthStatus;
  user: AuthUser | null;
  /** Başarılı giriş/kayıt/yenileme sonrası çağrılır. */
  setSession: (auth: AuthResponse) => void;
  /** Çıkış ya da oturum düşmesi. */
  clearSession: () => void;
  /** Açılışta oturum geri yüklenemediğinde. */
  markAnonymous: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  status: 'unknown',
  user: null,

  setSession: (auth) => {
    setTokens(auth.tokens);
    set({ status: 'authenticated', user: auth.user });
  },

  clearSession: () => {
    clearTokens();
    set({ status: 'anonymous', user: null });
  },

  markAnonymous: () => set({ status: 'anonymous', user: null }),
}));
