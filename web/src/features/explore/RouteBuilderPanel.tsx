import { useState } from 'react';
import type { CreateRouteRequest, RouteDetail, TravelMode } from '@vivido/shared';
import { MAX_ROUTE_STOPS, MIN_ROUTE_STOPS } from '@vivido/shared';
import type { MapPoint } from '@/shared/map/CankayaMap';
import {
  DEFAULT_ROUTE_START,
  formatRouteDistance,
  formatRouteDuration,
  routeNameForToday,
  travelModeLabel,
} from '@/shared/route/routeFormat';

/**
 * Rota oluşturucu + metrik kartı (R-120, R-121) — Explore çekmecesinin
 * "Rota" sekmesi.
 *
 * DÜZEN: konut seçimi HARİTADAN yapılır (pin tıklaması); bu panel yalnızca
 * seçilenleri listeler, başlangıç noktasını ve ulaşım modunu toplar ve
 * `POST /routes` isteğini tetikler. Rota oluşunca metrik kartına geçer:
 * toplam mesafe, tahmini süre ve numaralı ziyaret sırası.
 */

/** Rota listesine eklenebilen konut özeti — Explore'daki konut verisinden. */
export interface RoutePropertyOption {
  id: number;
  monthlyRent: number;
  areaM2: number;
  roomCount: string;
  neighborhood?: string;
  latitude: number;
  longitude: number;
  totalScore: number;
}

export interface RouteBuilderPanelProps {
  /** Seçili konutlar — dizi sırası = numaralandırma sırası. */
  options: RoutePropertyOption[];
  onRemoveProperty: (propertyId: number) => void;
  /** Haritadan seçilen başlangıç; null = varsayılan Çankaya merkezi. */
  start: (MapPoint & { label: string }) | null;
  /** "Haritadan seç" kipini açar/kapatır. */
  onPickStart: () => void;
  pickingStart: boolean;
  /** `POST /routes` — gövde burada kurulur. */
  onCreate: (body: CreateRouteRequest) => void;
  isCreating: boolean;
  error: string | null;
  /** Oluşturulmuş rota — varsa metrik kartı gösterilir. */
  route: RouteDetail | null;
  /** Metrik kartından "Rota düzenle": çizgi kalkar, seçim korunur (R-122). */
  onCloseRoute: () => void;
  /** Oluşturucuyu sıfırlar: çizgi + seçim + başlangıç. */
  onDiscardRoute: () => void;
  /** R-122 — metrik kartından bir durağı çıkarır; kalanlar yeniden optimize edilir. */
  onRemoveStop: (propertyId: number) => void;
  /** Durak çıkarıldıktan sonra yeniden hesaplama sürüyor mu? */
  isReoptimizing: boolean;
}

export function RouteBuilderPanel({
  options,
  onRemoveProperty,
  start,
  onPickStart,
  pickingStart,
  onCreate,
  isCreating,
  error,
  route,
  onCloseRoute,
  onDiscardRoute,
  onRemoveStop,
  isReoptimizing,
}: RouteBuilderPanelProps) {
  const [mode, setMode] = useState<TravelMode>('car');
  const [name, setName] = useState(routeNameForToday);

  const startPoint = start ?? DEFAULT_ROUTE_START;
  const canCreate = options.length >= MIN_ROUTE_STOPS;

  function submit() {
    if (!canCreate || isCreating) return;
    onCreate({
      name: name.trim() || routeNameForToday(),
      start: { lat: startPoint.lat, lon: startPoint.lon, label: startPoint.label },
      propertyIds: options.map((option) => option.id),
      mode,
    });
  }

  if (route) {
    return (
      <RouteMetricsCard
        route={route}
        onClose={onCloseRoute}
        onDiscard={onDiscardRoute}
        onRemoveStop={onRemoveStop}
        isReoptimizing={isReoptimizing}
        error={error}
      />
    );
  }

  return (
    <>
      <section className="drawer-section">
        <h2>Ziyaret rotası</h2>
        <p className="muted">
          Haritada <strong>{MIN_ROUTE_STOPS}–{MAX_ROUTE_STOPS} konuta</strong> tıklayarak
          rotana ekle; sistem en kısa ziyaret sırasını hesaplar.
        </p>

        <div className="route-count">
          <span>Seçilen konut</span>
          <span className="section-count">
            {options.length} / {MAX_ROUTE_STOPS}
          </span>
        </div>

        {options.length > 0 ? (
          <ul className="route-list">
            {options.map((option, index) => (
              <li key={option.id}>
                <span className="route-seq">{index + 1}</span>
                <span className="route-item-main">
                  <strong>{option.roomCount} · {option.areaM2} m²</strong>
                  <span className="route-item-sub">
                    {option.neighborhood ? `${option.neighborhood} · ` : ''}
                    {option.monthlyRent.toLocaleString('tr-TR')} ₺
                  </span>
                </span>
                <span className="route-item-score">{Math.round(option.totalScore)}</span>
                <button
                  className="btn-icon route-remove"
                  type="button"
                  onClick={() => onRemoveProperty(option.id)}
                  aria-label={`${option.roomCount} konutunu rotadan çıkar`}
                >
                  ✕
                </button>
              </li>
            ))}
          </ul>
        ) : (
          <p className="muted">Henüz konut seçilmedi — haritada konut pinine tıkla.</p>
        )}
      </section>

      <section className="drawer-section">
        <h2>Başlangıç noktası</h2>
        <div className="route-start">
          <span className="route-start-label">{startPoint.label}</span>
          <button className="btn-chip" type="button" onClick={onPickStart}>
            {pickingStart ? 'Vazgeç' : 'Haritadan seç'}
          </button>
        </div>
        {pickingStart && (
          <p className="route-hint" role="status">
            Haritada başlangıç noktasına tıkla.
          </p>
        )}
      </section>

      <section className="drawer-section">
        <h2>Ulaşım ve ad</h2>
        <div className="field">
          <span>Ulaşım modu</span>
          <div className="route-mode-toggle">
            <button
              className={`btn-chip${mode === 'car' ? ' is-active' : ''}`}
              type="button"
              onClick={() => setMode('car')}
            >
              Araç
            </button>
            <button
              className={`btn-chip${mode === 'foot' ? ' is-active' : ''}`}
              type="button"
              onClick={() => setMode('foot')}
            >
              Yürüyerek
            </button>
          </div>
        </div>
        <div className="field">
          <span>Rota adı</span>
          <input value={name} onChange={(event) => setName(event.target.value)} />
        </div>
      </section>

      {error && (
        <p className="route-error" role="alert">
          {error}
        </p>
      )}

      <div className="drawer-actions">
        <button
          className="btn-primary btn-sm"
          type="button"
          disabled={!canCreate || isCreating}
          onClick={submit}
        >
          {isCreating ? 'Oluşturuluyor…' : 'Rota Oluştur'}
        </button>
      </div>
    </>
  );
}

/** Oluşturulmuş rotanın metrik kartı: toplam mesafe/süre + numaralı durak listesi.
 *  R-122: her durakta "Kaldır" — çıkarılan durak kalanlarla yeniden optimize edilir. */
function RouteMetricsCard({
  route,
  onClose,
  onDiscard,
  onRemoveStop,
  isReoptimizing,
  error,
}: {
  route: RouteDetail;
  onClose: () => void;
  onDiscard: () => void;
  onRemoveStop: (propertyId: number) => void;
  isReoptimizing: boolean;
  error: string | null;
}) {
  const stops = [...route.stops].sort((a, b) => a.seq - b.seq);

  return (
    <>
      <section className="drawer-section">
        <div className="route-metrics-head">
          <h2>{route.name}</h2>
          <span className="route-mode-badge">{travelModeLabel(route.mode)}</span>
        </div>

        <dl className="kv">
          <dt>Toplam mesafe</dt>
          <dd>{formatRouteDistance(route.totalDistanceM)}</dd>
          <dt>Tahmini süre</dt>
          <dd>{formatRouteDuration(route.totalDurationS)}</dd>
          <dt>Durak</dt>
          <dd>{route.stopCount} konut</dd>
        </dl>

        <p className="data-badge">Rota kaydedildi · Profil → Kayıtlı Rotalarım</p>
      </section>

      <section className="drawer-section">
        <h2>Ziyaret sırası</h2>
        <ol className="route-stops">
          {stops.map((stop) => (
            <li key={stop.seq}>
              <span className="route-seq">{stop.seq}</span>
              <span className="route-item-main">
                <strong>{stop.property.roomCount} · {stop.property.areaM2} m²</strong>
                <span className="route-item-sub">
                  {stop.property.neighborhood ? `${stop.property.neighborhood} · ` : ''}
                  {stop.property.monthlyRent.toLocaleString('tr-TR')} ₺
                </span>
                <span className="route-item-sub route-item-leg">
                  {stop.legDistanceM != null ? formatRouteDistance(stop.legDistanceM) : '—'}
                  {stop.legDurationS != null
                    ? ` · ${formatRouteDuration(stop.legDurationS)}`
                    : ''}
                </span>
              </span>
              <span className="route-item-score">
                {stop.score != null ? Math.round(stop.score) : '—'}
              </span>
              <button
                className="btn-icon route-remove"
                type="button"
                onClick={() => onRemoveStop(stop.propertyId)}
                disabled={isReoptimizing}
                aria-label={`${stop.seq}. durağı rotadan çıkar`}
                title="Rotadan çıkar (yeniden hesaplanır)"
              >
                ✕
              </button>
            </li>
          ))}
        </ol>

        {isReoptimizing && (
          <p className="route-hint" role="status">
            Kalan konutlarla yeniden hesaplanıyor…
          </p>
        )}
        {error && (
          <p className="route-error" role="alert">
            {error}
          </p>
        )}
      </section>

      <div className="drawer-actions">
        <button className="btn-secondary btn-sm" type="button" onClick={onClose}>
          Rota düzenle
        </button>
        <button className="btn-chip" type="button" onClick={onDiscard}>
          Sıfırla
        </button>
      </div>
    </>
  );
}

