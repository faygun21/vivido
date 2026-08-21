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

/**
 * Misafir modu bayrağı `sessionStorage`'da.
 *
 * Neden `localStorage` değil: misafir gezintisi geçici bir niyet, kalıcı
 * bir tercih değil. Sekme kapanınca unutulması doğru davranış — aksi halde
 * kullanıcı haftalar sonra açtığında hâlâ "misafir" olarak karşılanırdı.
 */
const GUEST_KEY = 'vivido.guest';

function readGuestFlag(): boolean {
  try {
    return sessionStorage.getItem(GUEST_KEY) === '1';
  } catch {
    // Gizli sekme / depolama kapalı — misafirlik sayfa ömrüyle sınırlı kalır.
    return false;
  }
}

function writeGuestFlag(active: boolean): void {
  try {
    if (active) sessionStorage.setItem(GUEST_KEY, '1');
    else sessionStorage.removeItem(GUEST_KEY);
  } catch {
    /* yoksay */
  }
}

interface AuthState {
  status: AuthStatus;
  user: AuthUser | null;
  /**
   * Kullanıcı "misafir olarak devam et" dedi mi?
   *
   * Bu bir kimlik DEĞİL, bir gezinti izni. Misafir haritayı ve konutların
   * temel bilgilerini görür; skor, persona ve anchor kayıt ister.
   */
  isGuest: boolean;
  /** Başarılı giriş/kayıt/yenileme sonrası çağrılır. */
  setSession: (auth: AuthResponse) => void;
  /** Çıkış ya da oturum düşmesi. */
  clearSession: () => void;
  /** Açılışta oturum geri yüklenemediğinde. */
  markAnonymous: () => void;
  /** "Misafir olarak devam et". */
  enterGuest: () => void;
  /** Misafirlikten çıkış — giriş/kayıt ekranına dönerken. */
  leaveGuest: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  status: 'unknown',
  user: null,
  isGuest: readGuestFlag(),

  setSession: (auth) => {
    setTokens(auth.tokens);
    // Giriş yapan kullanıcı artık misafir değil. Bayrağı bırakırsak
    // arayüz ona hâlâ "kayıt ol" çağrıları göstermeye devam ederdi.
    writeGuestFlag(false);
    set({ status: 'authenticated', user: auth.user, isGuest: false });
  },

  clearSession: () => {
    clearTokens();
    writeGuestFlag(false);
    set({ status: 'anonymous', user: null, isGuest: false });
  },

  markAnonymous: () => set({ status: 'anonymous', user: null }),

  enterGuest: () => {
    writeGuestFlag(true);
    set({ isGuest: true });
  },

  leaveGuest: () => {
    writeGuestFlag(false);
    set({ isGuest: false });
  },
}));
