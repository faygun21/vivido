import { Link, NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/features/auth/authStore';
import { HOME_PATH } from '@/features/auth/authFlow';

/**
 * Uygulama kabuğu — SAHİBİ: Kişi 1
 *
 * Gezinme bağlantıları **düğme** olarak çiziliyor: altı çizili metinler
 * tıklanabilir hissettirmiyordu ve "Giriş"/"Kayıt ol" ile "Keşfet"/"Profil"
 * aynı ağırlıkta görünüyordu. Artık birincil eylem dolu, ikincil eylemler
 * hayalet düğme.
 */
export function RootLayout() {
  const navigate = useNavigate();
  const { pathname } = useLocation();
  const { status, user, isGuest, clearSession, leaveGuest } = useAuthStore();

  const authenticated = status === 'authenticated';

  /**
   * Keşfet ekranı kenardan kenara çizilir: harita `.app-main`'in 68rem'lik
   * okuma genişliğine sıkıştırılırsa geniş ekranlarda yarısı boşa gider.
   */
  const fullBleed = pathname.startsWith('/explore');

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
    <div className={`app-shell${fullBleed ? ' app-shell--full' : ''}`}>
      <header className="app-header">
        <Link to={brandTarget} className="brand">
        <img src="/images/logo.svg" alt="Vivido Logo" className="brand-logo" />
        Vivido
        </Link>

        <nav className="app-nav">
          {authenticated ? (
            <>
              <NavLink
                to="/explore"
                className={({ isActive }) => `nav-btn${isActive ? ' is-active' : ''}`}
              >
                Keşfet
              </NavLink>
              <NavLink
                to="/favorites"
                className={({ isActive }) => `nav-btn${isActive ? ' is-active' : ''}`}
              >
                Favorilerim
              </NavLink>
              <NavLink
                to="/profile"
                className={({ isActive }) => `nav-btn${isActive ? ' is-active' : ''}`}
              >
                Profil
              </NavLink>
              <span className="user-email" title={user?.email}>
                {user?.email}
              </span>
              <button type="button" className="nav-btn nav-btn--quiet" onClick={handleLogout}>
                Çıkış
              </button>
            </>
          ) : status === 'anonymous' ? (
            isGuest ? (
              <>
                <span className="guest-chip" title="Skorlar ve kişiselleştirme kayıt gerektirir">
                  Misafir
                </span>
                <button
                  type="button"
                  className="nav-btn"
                  onClick={() => handleLeaveGuest('/auth/login')}
                >
                  Giriş yap
                </button>
                <button
                  type="button"
                  className="nav-btn nav-btn--primary"
                  onClick={() => handleLeaveGuest('/auth/register')}
                >
                  Kayıt ol
                </button>
              </>
            ) : (
              <>
                <Link to="/auth/login" className="nav-btn">
                  Giriş yap
                </Link>
                <Link to="/auth/register" className="nav-btn nav-btn--primary">
                  Kayıt ol
                </Link>
              </>
            )
          ) : null}
        </nav>
      </header>

      <main className={`app-main${fullBleed ? ' app-main--full' : ''}`}>
        <Outlet />
      </main>

      {/*
        ODbL yükümlülüğü: OpenStreetMap atfı harita üzerinde GÖRÜNÜR olmak
        zorunda. Harita ekranlarında bunu MapLibre'ın `attributionControl`ü
        üstleniyor; bu satır uygulama genelindeki atıf olarak kalır.
      */}
      <footer className="app-footer">
        Harita verisi © OpenStreetMap katkıcıları · Konut verisi sentetiktir
      </footer>
    </div>
  );
}
