import { Link, Navigate, useNavigate } from 'react-router-dom';
import { useAuthStore } from '@/features/auth/authStore';
import { HOME_PATH } from '@/features/auth/authFlow';

/** SAHİBİ: Kişi 1 */
export function LandingPage() {
  const navigate = useNavigate();
  const status = useAuthStore((s) => s.status);
  const enterGuest = useAuthStore((s) => s.enterGuest);

  // Giriş yapmış kullanıcıya tanıtım sayfası göstermek anlamsız — üstelik
  // buradaki "Başla" düğmesi onu kayıt formuna götürüp oturumunun düştüğü
  // izlenimi veriyordu. Doğrudan ana ekranına al.
  if (status === 'authenticated') {
    return <Navigate to={HOME_PATH} replace />;
  }

  function browseAsGuest() {
    enterGuest();
    navigate(HOME_PATH);
  }

  return (
    <section className="landing">
      <h1>Sana uygun kiralık evi bul</h1>
      <p>
        Personanı ve düzenli gittiğin yerleri gir; sistem sana uygun kiralık
        evleri <strong>gerekçesiyle</strong> skorlasın. Seçtiğin evleri gezmek
        için en kısa rotayı kur, telefonda navigasyonla yürü.
      </p>
      <p className="muted">Pilot bölge: Ankara Çankaya</p>

      <div className="landing-actions">
        <Link to="/auth/register" className="cta">
          Başla
        </Link>
        <Link to="/auth/login" className="btn-secondary">
          Giriş yap
        </Link>
        <button type="button" className="btn-ghost" onClick={browseAsGuest}>
          Misafir olarak devam et
        </button>
      </div>

      <p className="muted landing-guest-note">
        Misafir olarak haritayı ve kiralık konutların temel bilgilerini
        inceleyebilirsin. <strong>Kişiselleştirilmiş skor</strong>, persona
        seçimi ve düzenli gittiğin yerleri eklemek için hesap gerekiyor.
      </p>
    </section>
  );
}
