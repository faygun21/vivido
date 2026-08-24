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
 * ⭐ OTURUM KİMLİĞİ — sunucudan gelen her verinin sahibi
 *
 * `status` "giriş yapılmış mı" sorusunu cevaplıyor ama "KİM" sorusunu
 * cevaplamıyor. Sunucu verisi (profil, anchor, favori, rota) bir kişiye
 * aittir; kimlik değişince o veri geçersizdir.
 *
 * Bu alan olmadan yaşanan hata: A hesabıyla eklenen pinler çıkış
 * yapıldıktan sonra misafir ekranında ve B hesabıyla girildiğinde
 * görünmeye devam ediyordu. Sebep, önbelleğin kimliğe bağlı olmaması ve
 * çıkışta temizlenmemesiydi — `useQuery` `enabled: false` iken bile ELDEKİ
 * ÖNBELLEĞİ döndürür, istek atmamak veriyi gizlemez.
 *
 * Değerler kasıtlı olarak ayrı: misafir de anonim de "giriş yapmamış"tır
 * ama aynı kişi değildir; ikisi arasında geçerken de önbellek düşmelidir.
 */
export type SessionKey = string;

export const SESSION_ANONYMOUS: SessionKey = 'anon';
export const SESSION_GUEST: SessionKey = 'guest';

/** Giriş yapmış kullanıcının önbellek kimliği. */
export function userSessionKey(userId: string): SessionKey {
  return `user:${userId}`;
}

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
  /**
   * Sunucu verisinin sahibi. Değiştiği an önbellek boşaltılır —
   * bkz. `SessionCacheSync` ve `useSessionQuery`.
   */
  sessionKey: SessionKey;
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
  // Açılışta kimlik henüz bilinmiyor; misafir bayrağı varsa oradan başlar.
  // `bootstrapSession` sonuçlanınca `setSession` ya da `markAnonymous`
  // gerçek kimliği yazar.
  sessionKey: readGuestFlag() ? SESSION_GUEST : SESSION_ANONYMOUS,

  setSession: (auth) => {
    setTokens(auth.tokens);
    // Giriş yapan kullanıcı artık misafir değil. Bayrağı bırakırsak
    // arayüz ona hâlâ "kayıt ol" çağrıları göstermeye devam ederdi.
    writeGuestFlag(false);
    set({
      status: 'authenticated',
      user: auth.user,
      isGuest: false,
      // Token yenilemede de bu çağrılır; kullanıcı aynıysa anahtar da aynı
      // kalır ve önbellek BOŞUNA düşmez.
      sessionKey: userSessionKey(auth.user.id),
    });
  },

  clearSession: () => {
    clearTokens();
    writeGuestFlag(false);
    set({
      status: 'anonymous',
      user: null,
      isGuest: false,
      sessionKey: SESSION_ANONYMOUS,
    });
  },

  markAnonymous: () =>
    set({ status: 'anonymous', user: null, sessionKey: SESSION_ANONYMOUS }),

  // Misafirlik bir kimlik DEĞİL, gezinti iznidir; giriş yapmış kullanıcının
  // kimliğini ezmemeli. `set((s) => …)` bu yüzden: aksi halde misafir
  // panelinden "Giriş yap"a basan biri `leaveGuest` ile kendi oturum
  // anahtarını `anon`a düşürür ve önbelleği sebepsiz kaybederdi.
  enterGuest: () => {
    writeGuestFlag(true);
    set((s) => ({
      isGuest: true,
      sessionKey: s.status === 'authenticated' ? s.sessionKey : SESSION_GUEST,
    }));
  },

  leaveGuest: () => {
    writeGuestFlag(false);
    set((s) => ({
      isGuest: false,
      sessionKey: s.status === 'authenticated' ? s.sessionKey : SESSION_ANONYMOUS,
    }));
  },
}));
