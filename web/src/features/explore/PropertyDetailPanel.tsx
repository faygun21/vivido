import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react';
import type { PropertyDetail, PropertyScoreRow } from '@vivido/shared';
import { BAND_LABEL, formatMinutes, formatRent, splitAddress } from './propertyFormat';
import { useFavoriteMutation } from './useFavorite';
import { usePropertyNote } from './usePropertyNote';
import { useIsAuthenticated } from '@/shared/api/sessionQuery';
import { useWideScreen } from '@/shared/useWideScreen';

/** Mobilde daraltılmış halde görünen üst şerit yüksekliği (px) — tutamaç + başlık. */
const PEEK_HEIGHT_PX = 96;

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
  /** Rota oluşturma misafire kapalı — bu düğme de aynı koşulla gösterilir. */
  showRouteButton: boolean;
  /**
   * Bu ev rota seçimindeyse (henüz kaydedilmemiş `routeIds` ya da hesaplanmış
   * `activeRoute.stops`) — favorinin aksine `PropertyDetail`'da gelmiyor,
   * `ExplorePage` türetip geçiyor.
   */
  isInRoute: boolean;
  /** Rota `MAX_ROUTE_STOPS`'a ulaştıysa VE bu ev içinde değilse düğme kilitlenir. */
  routeAtCapacity: boolean;
  onToggleRoute: () => void;
}

export function PropertyDetailPanel({
  property,
  onClose,
  onBack,
  showRouteButton,
  isInRoute,
  routeAtCapacity,
  onToggleRoute,
}: PropertyDetailPanelProps) {
  const [showAllRows, setShowAllRows] = useState(false);
  const favorite = useFavoriteMutation();
  const routeDisabled = routeAtCapacity && !isInRoute;
  const authenticated = useIsAuthenticated();
  const propertyNote = usePropertyNote(property.id);
  const [editingNote, setEditingNote] = useState(false);
  const [noteDraft, setNoteDraft] = useState('');
  const [confirmNoteDelete, setConfirmNoteDelete] = useState(false);

  useEffect(() => {
    setEditingNote(false);
    setNoteDraft('');
    setConfirmNoteDelete(false);
  }, [property.id]);

  /**
   * Mobilde panel alttan açılan bir sayfaya dönüyor (bkz. `@media
   * max-width: 899px`) ve haritanın ~%80'ini kaplıyor — seçili evin
   * güçlü yön POI'lerini haritada görmek isteyen kullanıcının hiçbir
   * şansı yoktu. Artık aşağı sürüklenip daraltılabiliyor (2026-08-28:
   * "aşağı sürükleyip haritadaki ev etrafı poileri görmek amacıyla").
   * Masaüstünde panel yan panel olduğu için bu tamamen devre dışı.
   */
  const wide = useWideScreen();
  const [collapsed, setCollapsed] = useState(false);
  const panelRef = useRef<HTMLElement | null>(null);
  const dragRef = useRef<{ startY: number; panelHeight: number; wasCollapsed: boolean } | null>(null);

  function handleGripPointerDown(event: ReactPointerEvent<HTMLDivElement>) {
    if (wide || !panelRef.current) return;
    event.currentTarget.setPointerCapture(event.pointerId);
    dragRef.current = {
      startY: event.clientY,
      panelHeight: panelRef.current.getBoundingClientRect().height,
      wasCollapsed: collapsed,
    };
    panelRef.current.style.transition = 'none';
  }

  function handleGripPointerMove(event: ReactPointerEvent<HTMLDivElement>) {
    const drag = dragRef.current;
    if (!drag || !panelRef.current) return;
    const maxHide = Math.max(drag.panelHeight - PEEK_HEIGHT_PX, 0);
    const base = drag.wasCollapsed ? maxHide : 0;
    const offset = Math.min(Math.max(base + (event.clientY - drag.startY), 0), maxHide);
    panelRef.current.style.transform = `translateY(${offset}px)`;
  }

  function handleGripPointerUp(event: ReactPointerEvent<HTMLDivElement>) {
    const drag = dragRef.current;
    dragRef.current = null;
    if (!drag || !panelRef.current) return;

    panelRef.current.style.transition = '';
    panelRef.current.style.transform = '';

    const deltaY = event.clientY - drag.startY;
    if (Math.abs(deltaY) < 6) {
      // Sürükleme değil, tek dokunuş — durumu tersine çevir.
      setCollapsed((current) => !current);
      return;
    }

    const maxHide = Math.max(drag.panelHeight - PEEK_HEIGHT_PX, 0);
    const base = drag.wasCollapsed ? maxHide : 0;
    const finalOffset = Math.min(Math.max(base + deltaY, 0), maxHide);
    setCollapsed(finalOffset > maxHide / 2);
  }

  const { score } = property;
  const address = splitAddress(property.address);
  // Bilerek yuvarlanmıyor: skorlar artık (Yol A + zayıf halka cezası +
  // yoğunluk bonusu ile) çok daha ayrışık — tam sayıya yuvarlamak farklı
  // evleri yeniden aynı görünen puana taşırdı (örn. 96.4 ile 96.6 ikisi de
  // "96" gösterip aradaki farkı gizlerdi).
  const displayTotal = score.total.toFixed(1);

  // Kırılım boşsa (erişim matrisi eksik bir konut) tabloyu hiç çizmiyoruz —
  // boş bir "Neden?" başlığı, olmayan bir açıklamayı vaat eder.
  const hasBreakdown = score.rows.length > 0;

  function toggleFavorite() {
    favorite.mutate({ propertyId: property.id, isFavorite: property.isFavorite });
  }

  function beginNoteEdit() {
    setNoteDraft(propertyNote.note ?? '');
    setEditingNote(true);
    setConfirmNoteDelete(false);
  }

  function saveNote() {
    const note = noteDraft.trim();
    if (!note) return;
    propertyNote.saveNote({ note }, {
      onSuccess: () => setEditingNote(false),
    });
  }

  return (
    <aside
      ref={panelRef}
      className={`property-panel${collapsed ? ' is-collapsed' : ''}`}
      role="dialog"
      aria-label="Konut detayları"
    >
      {/* Sadece mobilde görünür (bkz. CSS) — aşağı sürükleyip haritayı,
          yukarı sürükleyip detayları görmek için. Tek dokunuş da aynı işi
          (aç/kapa) yapıyor, sürüklemeyi keşfetmeyen kullanıcı için. */}
      <div
        className="property-panel-grip"
        onPointerDown={handleGripPointerDown}
        onPointerMove={handleGripPointerMove}
        onPointerUp={handleGripPointerUp}
        onPointerCancel={handleGripPointerUp}
        role="button"
        tabIndex={wide ? -1 : 0}
        aria-expanded={!collapsed}
        aria-label={collapsed ? 'Detayları genişlet' : 'Haritayı görmek için daralt'}
        onKeyDown={(event) => {
          if (event.key !== 'Enter' && event.key !== ' ') return;
          event.preventDefault();
          setCollapsed((current) => !current);
        }}
      >
        <span aria-hidden="true" />
      </div>

      {onBack && (
        <button className="property-panel-back" type="button" onClick={onBack}>
          <span aria-hidden="true">←</span> En uygun evler listesine dön
        </button>
      )}

      <header className="property-panel-head">
        <div className={`score-badge score-badge--${score.band}`}>
          <strong>{displayTotal}</strong>
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

        {showRouteButton && (
          <button
            className={`route-btn${isInRoute ? ' is-active' : ''}`}
            type="button"
            onClick={onToggleRoute}
            disabled={routeDisabled}
            aria-pressed={isInRoute}
            title={routeDisabled ? 'Rota dolu — önce bir durak çıkar' : undefined}
          >
            {/* Bayrak deseni: kalp ♥/♡'nin aktif/pasif mantığı, ama ayrı sembol
                — "+" favoriden görsel olarak ayrışmıyordu (2026-08-28). */}
            <span aria-hidden="true">{isInRoute ? '⚑' : '⚐'}</span>
            {isInRoute ? 'Rotada' : 'Rotaya ekle'}
          </button>
        )}

        <section className="property-section">
          <h3>Bu ev nasıl bir ev?</h3>
          <ul className="feature-grid">
            <FeatureItem label="Kat" value={formatFloor(property.features.floorNo, property.features.totalFloors)} />
            <FeatureItem label="Bina yaşı" value={property.features.buildingAge != null ? `${property.features.buildingAge} yıl` : null} />
            <FeatureItem label="Depozito" value={property.features.deposit != null ? formatRent(property.features.deposit) : null} />
          </ul>

          <ul className="tag-row">
            <Tag active={property.features.hasElevator}>Asansör</Tag>
            <Tag active={property.features.hasParking}>Otopark</Tag>
            <Tag active={property.features.isFurnished}>Eşyalı</Tag>
            <Tag active={property.features.petsAllowed}>Evcil hayvan</Tag>
          </ul>
        </section>

        {authenticated && (
          <section className="property-section property-note-section">
            <div className="property-note-heading">
              <h3>Kişisel Notum</h3>
              <span className="muted property-note-private">Yalnızca sen görebilirsin</span>
            </div>

            {propertyNote.isLoading ? (
              <p className="muted property-note-status">Not yükleniyor…</p>
            ) : propertyNote.loadError ? (
              <div className="property-note-error" role="alert">
                <p>Not yüklenemedi.</p>
                <button className="btn-chip" type="button" onClick={() => void propertyNote.retryLoad()}>
                  Tekrar dene
                </button>
              </div>
            ) : editingNote ? (
              <div className="property-note-editor">
                <textarea
                  value={noteDraft}
                  onChange={(event) => setNoteDraft(event.target.value)}
                  maxLength={1000}
                  rows={4}
                  autoFocus
                  aria-label="Kişisel not"
                  placeholder="Bu ev hakkında kendine bir not bırak…"
                  disabled={propertyNote.isSaving}
                />
                <div className="property-note-editor-meta">
                  <span className="muted">{noteDraft.length} / 1000</span>
                  <span className="property-note-actions">
                    <button
                      className="btn-chip"
                      type="button"
                      onClick={() => setEditingNote(false)}
                      disabled={propertyNote.isSaving}
                    >
                      Vazgeç
                    </button>
                    <button
                      className="btn-primary property-note-save"
                      type="button"
                      onClick={saveNote}
                      disabled={!noteDraft.trim() || propertyNote.isSaving}
                    >
                      {propertyNote.isSaving ? 'Kaydediliyor…' : 'Kaydet'}
                    </button>
                  </span>
                </div>
                {propertyNote.saveError && (
                  <p className="field-error" role="alert">Not kaydedilemedi. Tekrar dene.</p>
                )}
              </div>
            ) : propertyNote.note ? (
              <div className="property-note-view">
                <p>{propertyNote.note}</p>
                <div className="property-note-actions">
                  <button className="btn-chip" type="button" onClick={beginNoteEdit}>
                    Düzenle
                  </button>
                  {confirmNoteDelete ? (
                    <>
                      <button
                        className="btn-chip is-danger"
                        type="button"
                        onClick={() => propertyNote.deleteNote(undefined, {
                          onSuccess: () => setConfirmNoteDelete(false),
                        })}
                        disabled={propertyNote.isDeleting}
                      >
                        {propertyNote.isDeleting ? 'Siliniyor…' : 'Evet, sil'}
                      </button>
                      <button
                        className="btn-chip"
                        type="button"
                        onClick={() => setConfirmNoteDelete(false)}
                        disabled={propertyNote.isDeleting}
                      >
                        Vazgeç
                      </button>
                    </>
                  ) : (
                    <button className="btn-chip" type="button" onClick={() => setConfirmNoteDelete(true)}>
                      Sil
                    </button>
                  )}
                </div>
                {propertyNote.deleteError && (
                  <p className="field-error" role="alert">Not silinemedi. Tekrar dene.</p>
                )}
              </div>
            ) : (
              <button className="property-note-add" type="button" onClick={beginNoteEdit}>
                + Not ekle
              </button>
            )}
          </section>
        )}

        {hasBreakdown && (
          <section className="property-section">
            <h3>Bu ev sana neden {displayTotal} puan?</h3>
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
                {/*
                  Bilerek sadece 3 sütun: Kriter | Süre | Puan. Katkı sütunu
                  ("puan × ağırlık") ve yoğunluk metni ("X yer · ±Y puan")
                  içsel hesap detaylarıydı, kullanıcı için anlamsız bir jargon
                  gibi duruyordu (bkz. eczane/spor salonu örnekleri — "zaten
                  düşük puan aldı, neden bir de burada ceza yiyor" karışıklığı
                  yaratıyordu). Süre + hedef + puan kendi başına anlaşılır;
                  yoğunluk zaten puanın İÇİNDE, ayrıca göstermeye gerek yok.
                  Zayıf halka cezası da bu yüzden tablonun DIŞINDA, kendi net
                  cümlesiyle duruyor (yukarıda) — burada tekrar edilmiyor.
                */}
                <table className="score-table">
                  <thead>
                    <tr>
                      <th scope="col">Kriter</th>
                      <th scope="col">Süre</th>
                      <th scope="col">Puan</th>
                    </tr>
                  </thead>
                  <tbody>
                    {score.rows.map((row) => (
                      <tr key={row.categoryCode}>
                        <th scope="row">
                          <span className={`status-dot status-dot--${row.status}`} aria-hidden="true" />
                          {row.label}
                        </th>
                        <td>
                          {formatMinutes(row.durationMin)}
                          <span className="muted table-target">hedef ≤{formatMinutes(row.targetMin)}</span>
                        </td>
                        <td>{Math.round(row.subScore)}</td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot>
                    <tr>
                      <th scope="row" colSpan={2}>
                        TOPLAM
                      </th>
                      <td>{displayTotal}</td>
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
