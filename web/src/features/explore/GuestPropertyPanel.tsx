import type { MapProperty } from '@vivido/shared';
import { formatRent } from './propertyFormat';
import './GuestPropertyPanel.css';

/**
 * Misafirin haritadan bir konuta tıklayınca gördüğü özet.
 *
 * ⚠️ MİSAFİRE TIKLANAN PİN HİÇBİR ŞEY AÇMIYORDU
 *
 * Konut detayı (`/properties/{id}`) skor hesapladığı için oturum istiyor;
 * misafirin sorgusu `useSessionQuery` tarafından hiç atılmıyor ve panel
 * de açılmıyordu — pin tıklanabilir görünüyor ama ölüydü.
 *
 * Mobildeki `showPropertyDetailsSheet` ile aynı içerik: kira, oda/m²,
 * bina yaşı, asansör — hepsi herkese açık `/properties/map` yanıtında
 * ZATEN var, ek istek gerekmiyor. Skor gizlenmiyor, KİLİTLİ gösteriliyor:
 * "burada ne kaçırıyorum?" sorusunun cevabı, kayıt olmanın tek gerekçesi.
 */
interface GuestPropertyPanelProps {
  property: MapProperty;
  onClose: () => void;
  /** "Ücretsiz hesap oluştur" — misafirlikten çıkıp kayıt ekranına gider. */
  onRegister: () => void;
}

export function GuestPropertyPanel({
  property,
  onClose,
  onRegister,
}: GuestPropertyPanelProps) {
  return (
    <aside className="property-panel" role="dialog" aria-label="Konut özeti">
      <header className="property-panel-head">
        {/* Skor rozetinin yerinde kilit: rozetin OLMAMASI bir eksiklik gibi
            okunurdu, kilitli olması bir bilgi. */}
        <div className="guest-score-lock" aria-hidden="true">
          🔒
        </div>

        <div className="property-panel-title">
          <h2>
            {property.roomCount} · {property.areaM2} m²
          </h2>
          <p className="property-address">
            <span className="muted">Çankaya / Ankara</span>
          </p>
        </div>

        <button
          className="btn-icon property-panel-close"
          type="button"
          onClick={onClose}
          aria-label="Kapat"
        >
          ✕
        </button>
      </header>

      <div className="property-panel-body">
        <div className="property-headline">
          <div className="property-rent">
            <strong>{formatRent(property.monthlyRent)}</strong>
            <span className="muted">/ ay</span>
          </div>
        </div>

        <dl className="guest-facts">
          <div>
            <dt>Bina yaşı</dt>
            <dd>{property.buildingAge == null ? '—' : `${property.buildingAge} yıl`}</dd>
          </div>
          <div>
            <dt>Asansör</dt>
            <dd>{property.hasElevator ? 'Var' : 'Yok'}</dd>
          </div>
          <div>
            <dt>Konum</dt>
            <dd className="guest-facts-coord">
              {property.latitude.toFixed(5)}, {property.longitude.toFixed(5)}
            </dd>
          </div>
        </dl>

        <section className="guest-unlock">
          <p>
            <span className="lock" aria-hidden="true">🔒</span>
            Bu evin <strong>sana uygunluk skoru</strong> ve gerekçesi hesap ile açılıyor.
          </p>
          <button className="btn-primary btn-sm" type="button" onClick={onRegister}>
            Ücretsiz hesap oluştur
          </button>
        </section>

        {property.isSynthetic && (
          <p className="data-badge">Konut verisi sentetiktir — gerçek ilan değildir.</p>
        )}
      </div>
    </aside>
  );
}
