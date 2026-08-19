import { Link, Outlet } from 'react-router-dom';
import { useAuthStore } from '@/features/auth/authStore';

/**
 * Uygulama kabuğu — SAHİBİ: Kişi 1
 *
 * Şu an iskelet. Explore ekranı geldiğinde (Hafta 2) üst çubuğa
 * persona ve bütçe göstergeleri eklenecek.
 */
export function RootLayout() {
  const { status, user, clearSession } = useAuthStore();

  return (
    <div className="app-shell">
      <header className="app-header">
        <Link to="/" className="brand">
          Vivido
        </Link>

        <nav className="app-nav">
          {status === 'authenticated' ? (
            <>
              <Link to="/explore">Keşfet</Link>
              <Link to="/profile">Profil</Link>
              <span className="user-email">{user?.email}</span>
              <button type="button" onClick={clearSession}>
                Çıkış
              </button>
            </>
          ) : status === 'anonymous' ? (
            <>
              <Link to="/auth/login">Giriş</Link>
              <Link to="/auth/register">Kayıt ol</Link>
            </>
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
