import { Link, Outlet, useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/features/auth/authStore';
import { HOME_PATH } from '@/features/auth/authFlow';

/**
 * Uygulama kabuğu — SAHİBİ: Kişi 1
 *
 * Şu an iskelet. Explore ekranı geldiğinde (Hafta 2) üst çubuğa
 * persona ve bütçe göstergeleri eklenecek.
 */
export function RootLayout() {
  const navigate = useNavigate();
  const { status, user, isGuest, clearSession, leaveGuest } = useAuthStore();

  const authenticated = status === 'authenticated';

  /**
   * Marka bağlantısının hedefi.
   *
   * Giriş yapmış kullanıcı için `/` DEĞİL: tanıtım sayfası oradan "Başla →
   * kayıt ol" diyor ve kullanıcı logoya bastığında oturumunun düştüğünü
   * sanıyordu. İçerideki kullanıcının "ana menüsü" keşfet ekranıdır.
   */
  const brandTarget = authenticated ? HOME_PATH : '/';

  function handleLogout() {
    clearSession();
    navigate('/', { replace: true });
  }

  function handleLeaveGuest(to: string) {
    leaveGuest();
    navigate(to);
  }

  return (
    <div className="app-shell">
      <header className="app-header">
        <Link to={brandTarget} className="brand">
          Vivido
        </Link>

        <nav className="app-nav">
          {authenticated ? (
            <>
              <Link to="/explore">Keşfet</Link>
              <Link to="/profile">Profil</Link>
              <span className="user-email">{user?.email}</span>
              <button type="button" onClick={handleLogout}>
                Çıkış
              </button>
            </>
          ) : status === 'anonymous' ? (
            isGuest ? (
              <>
                <span className="guest-chip" title="Skorlar ve kişiselleştirme kayıt gerektirir">
                  Misafir
                </span>
                <button type="button" onClick={() => handleLeaveGuest('/auth/login')}>
                  Giriş
                </button>
                <button
                  type="button"
                  className="nav-cta"
                  onClick={() => handleLeaveGuest('/auth/register')}
                >
                  Kayıt ol
                </button>
              </>
            ) : (
              <>
                <Link to="/auth/login">Giriş</Link>
                <Link to="/auth/register">Kayıt ol</Link>
              </>
            )
          ) : null}
        </nav>
      </header>

      <main className="app-main">
        <Outlet />
      </main>

      {/*
        ODbL yükümlülüğü: OpenStreetMap atfı harita üzerinde GÖRÜNÜR olmak
        zorunda. Harita bileşeni geldiğinde MapLibre'ın attributionControl'ü
        bunu üstlenecek; bu satır genel atıf olarak kalır.
      */}
      <footer className="app-footer">
        Harita verisi © OpenStreetMap katkıcıları · Konut verisi{' '}
        <strong>sentetiktir</strong>
      </footer>
    </div>
  );
}
