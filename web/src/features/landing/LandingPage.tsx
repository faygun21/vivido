import { Link } from 'react-router-dom';

/** SAHİBİ: Kişi 1 */
export function LandingPage() {
  return (
    <section className="landing">
      <h1>Sana uygun kiralık evi bul</h1>
      <p>
        Personanı ve düzenli gittiğin yerleri gir; sistem sana uygun kiralık
        evleri <strong>gerekçesiyle</strong> skorlasın. Seçtiğin evleri gezmek
        için en kısa rotayı kur, telefonda navigasyonla yürü.
      </p>
      <p className="muted">Pilot bölge: Ankara Çankaya</p>
      <Link to="/auth/register" className="cta">
        Başla
      </Link>
    </section>
  );
}
