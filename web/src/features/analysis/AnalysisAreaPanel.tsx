import type { CSSProperties } from 'react';
import type { AnalysisArea } from '@/shared/map/CankayaMap';

/**
 * R-106 — Analiz alanı (buffer) kontrol paneli.
 *
 * Kullanıcı haritadan bir konum seçer; varsayılan 2 km yarıçaplı analiz
 * alanı çizilir. Yarıçap, izin verilen sınırlar (min/max) içinde kaydırıcı
 * veya hızlı seçim çipleriyle değiştirilebilir.
 *
 * Durum ExplorePage'de tutulur; bu bileşen yalnızca görünüm + etkileşimdir.
 */

/** R-106 — varsayılan analiz yarıçapı (km). */
export const ANALYSIS_AREA_DEFAULT_KM = 2;

/** R-106 — izin verilen en küçük yarıçap (km). */
export const ANALYSIS_AREA_MIN_KM = 0.5;

/** R-106 — izin verilen en büyük yarıçap (km). */
export const ANALYSIS_AREA_MAX_KM = 5;

/** Kaydırıcı adımı (km). */
export const ANALYSIS_AREA_STEP_KM = 0.1;

/** Hızlı seçim çipleri — sınırlar içinde kalan yuvarlak değerler. */
const PRESET_RADII_KM = [1, 2, 3, 5] as const;

interface AnalysisAreaPanelProps {
  /** Aktif analiz alanı; null ise henüz merkez seçilmemiş. */
  area: AnalysisArea | null;
  /** Merkez seçme modu açık mı (haritadan tıklama bekleniyor mu). */
  picking: boolean;
  /** Merkez seçme modunu başlatır — harita tıklaması merkezi belirler. */
  onStartPick: () => void;
  /** Merkez seçme modundan vazgeçer. */
  onCancelPick: () => void;
  /** Yarıçapı günceller; sınır uygulaması çağıran tarafın işidir. */
  onRadiusChange: (radiusKm: number) => void;
  /** Analiz alanını kaldırır. */
  onClear: () => void;
}

export function AnalysisAreaPanel({
  area,
  picking,
  onStartPick,
  onCancelPick,
  onRadiusChange,
  onClear,
}: AnalysisAreaPanelProps) {
  return (
    <div className="info-card">
      <h2>Analiz alanı</h2>

      {!area ? (
        <>
          <p className="muted" style={styles.aciklama}>
            Haritadan bir konum seçin; çevresinde varsayılan 2 km'lik analiz
            alanı (buffer) çizilir.
          </p>
          <button
            className="btn-primary"
            type="button"
            onClick={picking ? onCancelPick : onStartPick}
          >
            {picking ? 'İptal' : 'Konum seç'}
          </button>
        </>
      ) : (
        <>
          <dl className="kv">
            <dt>Merkez</dt>
            <dd>
              {area.center.lat.toFixed(5)}°, {area.center.lon.toFixed(5)}°
            </dd>
          </dl>

          <div style={styles.sliderBlok}>
            <span style={styles.sliderUst}>
              <span style={styles.sliderLabel}>Yarıçap</span>
              <span style={styles.sliderDeger}>{area.radiusKm.toFixed(1)} km</span>
            </span>
            <input
              type="range"
              min={ANALYSIS_AREA_MIN_KM}
              max={ANALYSIS_AREA_MAX_KM}
              step={ANALYSIS_AREA_STEP_KM}
              value={area.radiusKm}
              onChange={(e) => onRadiusChange(Number(e.target.value))}
              style={styles.slider}
              aria-label="Analiz yarıçapı (km)"
            />
            <span style={styles.sliderSinirlar}>
              {ANALYSIS_AREA_MIN_KM} km – {ANALYSIS_AREA_MAX_KM} km
            </span>
          </div>

          <div style={styles.cipBlok} role="group" aria-label="Hızlı yarıçap seçimi">
            {PRESET_RADII_KM.map((km) => (
              <button
                key={km}
                type="button"
                className="btn-secondary"
                style={{ ...styles.cip, ...(area.radiusKm === km ? styles.cipAktif : {}) }}
                onClick={() => onRadiusChange(km)}
              >
                {km} km
              </button>
            ))}
          </div>

          <div className="row-actions">
            <button className="btn-secondary" type="button" onClick={onStartPick}>
              Konumu değiştir
            </button>
            <button className="btn-secondary" type="button" onClick={onClear}>
              Temizle
            </button>
          </div>

          {picking && (
            <p style={styles.bilgi}>
              Haritaya tıklayarak yeni merkezi seçin — yarıçap korunur.
            </p>
          )}
        </>
      )}
    </div>
  );
}

const styles: Record<string, CSSProperties> = {
  aciklama: { marginTop: 0 },
  sliderBlok: { display: 'grid', gap: '0.35rem', marginBottom: '0.75rem' },
  sliderUst: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'baseline',
  },
  sliderLabel: { fontSize: '0.9rem', fontWeight: 600 },
  sliderDeger: { fontWeight: 700, fontVariantNumeric: 'tabular-nums' },
  slider: { accentColor: 'var(--accent)', width: '100%' },
  sliderSinirlar: { fontSize: '0.78rem', color: 'var(--ink-muted)' },
  cipBlok: { display: 'flex', gap: '0.4rem', marginBottom: '0.75rem' },
  cip: { padding: '0.2rem 0.6rem', fontSize: '0.82rem' },
  cipAktif: {
    background: 'var(--accent)',
    color: 'var(--accent-ink)',
    borderColor: 'transparent',
    fontWeight: 600,
  },
  bilgi: {
    margin: '0.6rem 0 0',
    fontSize: '0.85rem',
    color: 'var(--accent)',
    fontWeight: 600,
  },
};
