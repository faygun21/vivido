import { useState } from 'react';
import type { PropertyDetail, PropertyScoreRow } from '@vivido/shared';
import { BAND_LABEL, formatMinutes, formatRent, splitAddress } from './propertyFormat';
import { useFavoriteMutation } from './useFavorite';

/**
 * Konut detay paneli — bir pin'e tıklanınca haritanın üstünde açılır (W6).
 *
 * ⭐ NEDEN BÜYÜDÜ
 * Eskiden yalnızca kira, m², "77/100" ve referans kodu vardı. Kullanıcı
 * skoru görüyor ama NEDEN 77 olduğunu göremiyordu — ürünün tüm iddiası
 * açıklanabilirlik olduğu hâlde panel bir kara kutuydu.
 *
 * Panel üç soruya sırayla cevap veriyor:
 *   1. Bu ev nerede, ne kadar, nasıl bir ev?
 *   2. Skoru kaç ve bu iyi mi? (bant rozeti)
 *   3. NEDEN? — güçlü/zayıf yönler, istenirse tam kriter tablosu
 *
 * ⚠️ Bütçe AYRI bir bölümde ve skor satırlarının dışında duruyor: mevcut
 * skor motoru bütçeyi hesaba katmıyor. Gerekçe satırlarının arasına
 * karıştırsaydık kullanıcı "bütçem skorumu düşürmüş" sanırdı.
 */
interface PropertyDetailPanelProps {
  property: PropertyDetail;
  onClose: () => void;
  /**
   * Verilirse başlıkta "← Listeye dön" çıkar.
   *
   * Panel, "En uygun evler" listesiyle AYNI yuvayı paylaşıyor ve onun
   * üstünde açılıyor. Listeden gelindiğinde geri dönmenin bir yolu olmalı;
   * harita pin'inden gelindiğinde dönülecek bir liste yok, o yüzden
   * isteğe bağlı.
   */
  onBack?: () => void;
}

export function PropertyDetailPanel({ property, onClose, onBack }: PropertyDetailPanelProps) {
  const [showAllRows, setShowAllRows] = useState(false);
  const favorite = useFavoriteMutation();

  const { score } = property;
  const address = splitAddress(property.address);
  const rounded = Math.round(score.total);

  // Kırılım boşsa (erişim matrisi eksik bir konut) tabloyu hiç çizmiyoruz —
  // boş bir "Neden?" başlığı, olmayan bir açıklamayı vaat eder.
  const hasBreakdown = score.rows.length > 0;

  function toggleFavorite() {
    favorite.mutate({ propertyId: property.id, isFavorite: property.isFavorite });
  }

  return (
    <aside className="property-panel" role="dialog" aria-label="Konut detayları">
      {onBack && (
        <button className="property-panel-back" type="button" onClick={onBack}>
          <span aria-hidden="true">←</span> En uygun evler listesine dön
        </button>
      )}

      <header className="property-panel-head">
        <div className={`score-badge score-badge--${score.band}`}>
          <strong>{rounded}</strong>
          <span>/ 100</span>
        </div>

        <div className="property-panel-title">
          <h2>
            {property.roomCount} · {property.areaM2} m²
          </h2>
          <p className="property-address">
            <span className="property-address-primary">{address.primary}</span>
            {address.secondary && <span className="muted">{address.secondary}</span>}
          </p>
        </div>

        <button className="btn-icon property-panel-close" type="button" onClick={onClose} aria-label="Kapat">
          ✕
        </button>
      </header>

      <div className="property-panel-body">
        <div className="property-headline">
          <div className="property-rent">
            <strong>{formatRent(property.monthlyRent)}</strong>
            <span className="muted">/ ay</span>
          </div>
          <span className={`band-chip band-chip--${score.band}`}>{BAND_LABEL[score.band]}</span>
        </div>

        <button
          className={`favorite-btn${property.isFavorite ? ' is-active' : ''}`}
          type="button"
          onClick={toggleFavorite}
          disabled={favorite.isPending}
          aria-pressed={property.isFavorite}
        >
          <span aria-hidden="true">{property.isFavorite ? '♥' : '♡'}</span>
          {property.isFavorite ? 'Favorilerimde' : 'Favorilere ekle'}
        </button>

        {favorite.isError && (
          <p className="field-error" role="alert">
            Favori güncellenemedi. Tekrar dene.
          </p>
        )}

        <section className="property-section">
          <h3>Bu ev nasıl bir ev?</h3>
          <ul className="feature-grid">
            <FeatureItem label="Kat" value={formatFloor(property.features.floorNo, property.features.totalFloors)} />
            <FeatureItem label="Bina yaşı" value={property.features.buildingAge != null ? `${property.features.buildingAge} yıl` : null} />
            <FeatureItem label="m² başı" value={property.features.rentPerM2 != null ? formatRent(property.features.rentPerM2) : null} />
            <FeatureItem label="Depozito" value={property.features.deposit != null ? formatRent(property.features.deposit) : null} />
          </ul>

          <ul className="tag-row">
            <Tag active={property.features.hasElevator}>Asansör</Tag>
            <Tag active={property.features.hasParking}>Otopark</Tag>
            <Tag active={property.features.isFurnished}>Eşyalı</Tag>
            <Tag active={property.features.petsAllowed}>Evcil hayvan</Tag>
          </ul>
        </section>

        {/* Bütçe skorun PARÇASI DEĞİL — o yüzden gerekçe tablosunun dışında,
            kendi başlığıyla duruyor. */}
        <section className={`budget-note budget-note--${score.budget.status}`}>
          <h3>Bütçe uyumu</h3>
          <p>{score.budget.message}</p>
          {score.budget.ratioToMax != null && (
            <div
              className="budget-bar"
              role="img"
              aria-label={`Kira, üst bütçenin yüzde ${Math.round(score.budget.ratioToMax * 100)}'i`}
            >
              <span style={{ width: `${Math.min(score.budget.ratioToMax * 100, 100)}%` }} />
            </div>
          )}
        </section>

        {hasBreakdown && (
          <section className="property-section">
            <h3>Bu ev sana neden {rounded} puan?</h3>
            <p className="muted score-explainer">
              Puan, senin personana göre ağırlıklandırılmış <strong>yürüme süreleridir</strong>.
              Her kriter hedefine ne kadar yakınsa o kadar puan getirir; yakında{' '}
              <strong>kaç tane</strong> olduğu da hesaba katılır.
            </p>

            <div className="reason-columns">
              <div className="reason-col">
                <h4 className="reason-title reason-title--good">Neden uygun</h4>
                {score.strengths.length > 0 ? (
                  <ul className="reason-list">
                    {score.strengths.map((row) => (
                      <ReasonItem key={row.categoryCode} row={row} kind="strength" />
                    ))}
                  </ul>
                ) : (
                  <p className="muted reason-empty">Öne çıkan güçlü bir kriter yok.</p>
                )}
              </div>

              <div className="reason-col">
                <h4 className="reason-title reason-title--bad">Neden uygun değil</h4>
                {score.weaknesses.length > 0 ? (
                  <ul className="reason-list">
                    {score.weaknesses.map((row) => (
                      <ReasonItem key={row.categoryCode} row={row} kind="weakness" />
                    ))}
                  </ul>
                ) : (
                  <p className="muted reason-empty">Zayıf bir yönü yok — tüm kriterler hedefine yakın.</p>
                )}
              </div>
            </div>

            {/* Zayıf halka cezası ayrı duruyor çünkü bir KRİTER değil, tüm
                skora uygulanan bir kısıtlama. Kategori satırlarının arasına
                koysaydık "bu da bir kriter" sanılırdı. */}
            {score.weakLink && (
              <div className="weak-link-note">
                <div className="weak-link-head">
                  <span className="weak-link-label">Zayıf halka cezası</span>
                  <strong className="weak-link-points">{score.weakLink.points.toFixed(1)}</strong>
                </div>
                <p className="muted">{score.weakLink.message}</p>
              </div>
            )}

            <button
              className="btn-chip reason-toggle"
              type="button"
              onClick={() => setShowAllRows((open) => !open)}
              aria-expanded={showAllRows}
            >
              {showAllRows ? 'Tabloyu gizle' : `Tüm kriterleri göster (${score.rows.length})`}
            </button>

            {showAllRows && (
              <div className="score-table-wrap">
                <table className="score-table">
                  <thead>
                    <tr>
                      <th scope="col">Kriter</th>
                      <th scope="col">Ölçülen</th>
                      <th scope="col">Hedef</th>
                      <th scope="col">Puan</th>
                      <th scope="col">Katkı</th>
                    </tr>
                  </thead>
                  <tbody>
                    {score.rows.map((row) => (
                      <tr key={row.categoryCode}>
                        <th scope="row">
                          <span className={`status-dot status-dot--${row.status}`} aria-hidden="true" />
                          {row.label}
                          {/* Yoğunluk yalnızca fark yarattığında yazılıyor;
                              1.0 çarpan için "×1.00" basmak gürültü olurdu. */}
                          {row.poiCountInRadius != null && row.densityFactor !== 1 && (
                            <span className="muted density-hint">
                              {row.poiCountInRadius} yer · ×{row.densityFactor.toFixed(2)}
                            </span>
                          )}
                        </th>
                        <td>{formatMinutes(row.durationMin)}</td>
                        <td className="muted">≤{formatMinutes(row.targetMin)}</td>
                        <td>{Math.round(row.subScore)}</td>
                        <td className="score-table-contrib">+{row.contribution.toFixed(1)}</td>
                      </tr>
                    ))}

                    {/* Ceza satırı tablonun İÇİNDE olmalı, yoksa TOPLAM
                        satırların toplamıyla tutmaz ve tablo yalan söyler. */}
                    {score.weakLink && (
                      <tr className="score-table-penalty">
                        <th scope="row">
                          <span className="status-dot status-dot--weak" aria-hidden="true" />
                          Zayıf halka cezası
                          <span className="muted density-hint">{score.weakLink.label}</span>
                        </th>
                        <td className="muted">—</td>
                        <td className="muted">—</td>
                        <td className="muted">—</td>
                        <td className="score-table-contrib">{score.weakLink.points.toFixed(1)}</td>
                      </tr>
                    )}
                  </tbody>
                  <tfoot>
                    {/*
                      TOPLAM, satırların katkıları TOPLANARAK yazılıyor —
                      `score.total` doğrudan basılmıyor. Backend'de bir
                      tutarsızlık olursa burada anında görünür (W6 kuralı).
                      Zayıf halka cezası da toplama dahil: motor onu son
                      adımda çarpan olarak uyguluyor, kategori katkılarına
                      dağıtılmıyor.
                    */}
                    <tr>
                      <th scope="row" colSpan={4}>
                        TOPLAM
                      </th>
                      <td className="score-table-contrib">
                        {(
                          score.rows.reduce((sum, row) => sum + row.contribution, 0) +
                          (score.weakLink?.points ?? 0)
                        ).toFixed(1)}
                      </td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            )}
          </section>
        )}

        <footer className="property-panel-foot">
          <span className="muted property-ref">{property.externalRef}</span>
          {property.isSynthetic && <span className="data-badge">Konut verisi sentetiktir</span>}
        </footer>
      </div>
    </aside>
  );
}

function ReasonItem({ row, kind }: { row: PropertyScoreRow; kind: 'strength' | 'weakness' }) {
  return (
    <li className={`reason-item reason-item--${kind}`}>
      <span className="reason-mark" aria-hidden="true">
        {kind === 'strength' ? '✓' : '✗'}
      </span>
      <span className="reason-body">
        <span className="reason-label">{row.label}</span>
        <span className="muted reason-detail">
          {formatMinutes(row.durationMin)} · hedef ≤{formatMinutes(row.targetMin)}
        </span>
      </span>
      <span className="reason-score">{Math.round(row.subScore)}</span>
    </li>
  );
}

function FeatureItem({ label, value }: { label: string; value: string | null }) {
  return (
    <li>
      <span className="muted">{label}</span>
      <strong>{value ?? '—'}</strong>
    </li>
  );
}

/**
 * Özellik rozetleri var/yok olarak DEĞİL, "var" ise vurgulu "yok" ise soluk
 * gösteriliyor. Yokları tamamen gizlemek, kullanıcının "asansör bilgisi yok
 * mu, asansör mü yok?" diye sormasına yol açıyordu.
 */
function Tag({ active, children }: { active: boolean; children: React.ReactNode }) {
  return (
    <li className={`feature-tag${active ? ' is-on' : ''}`}>
      <span aria-hidden="true">{active ? '✓' : '—'}</span>
      {children}
    </li>
  );
}

function formatFloor(floorNo: number | null, totalFloors: number | null): string | null {
  if (floorNo == null && totalFloors == null) return null;
  if (floorNo == null) return `? / ${totalFloors}`;
  if (totalFloors == null) return `${floorNo}`;
  return `${floorNo} / ${totalFloors}`;
}
