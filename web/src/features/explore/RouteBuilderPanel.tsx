import { useState } from 'react';
import type { CreateRouteRequest, RouteDetail, TravelMode } from '@vivido/shared';
import { MAX_ROUTE_STOPS, MIN_ROUTE_STOPS } from '@vivido/shared';
import type { UserLocationStatus } from '@/shared/map/useUserLocation';
import { isWithinCankaya, type RouteStart } from '@/shared/route/routeStart';
import { RouteStartCombobox } from './RouteStartCombobox';
import {
  formatRouteDistance,
  formatRouteDuration,
  routeNameForToday,
  travelModeLabel,
} from '@/shared/route/routeFormat';

/**
 * Rota oluşturucu + metrik kartı (R-120, R-121) — Explore çekmecesinin
 * "Rota" sekmesi.
 *
 * DÜZEN: konut seçimi ev detayındaki/liste kartındaki "Rotaya ekle"
 * düğmesinden yapılır — pin'e tıklamak HER sekmede detay panelini açar
 * (2026-08-28: eskiden Rota sekmesindeyken pin tıklamak evi doğrudan
 * ekliyordu, kullanıcı evin özelliklerine hiç bakmadan "unutarak"
 * ekleyebiliyordu). Bu panel yalnızca seçilenleri listeler, başlangıç
 * noktasını ve ulaşım modunu toplar ve `POST /routes` isteğini tetikler.
 * Rota oluşunca metrik kartına geçer: toplam mesafe, tahmini süre ve
 * numaralı ziyaret sırası.
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
  /** Seçili başlangıç; null = henüz belirlenmedi (rota kurulamaz). */
  start: RouteStart | null;
  /** Canlı konumun durumu — panelde ne yazacağını belirler. */
  locationStatus: UserLocationStatus;
  /** Konum sorunluysa kullanıcıya gösterilecek Türkçe açıklama. */
  locationMessage: string | null;
  /** "Konumumu kullan" / "Tekrar dene". */
  onUseLiveLocation: () => void;
  /**
   * Konum kutusundan bir adres seçildi.
   *
   * `LocationSearchResult` değil `RouteStart` alıyor: dönüştürme
   * combobox'ta yapılıyor, panel ham arama sonucunu hiç görmüyor.
   */
  onPickAddress: (start: RouteStart) => void;
  /** `POST /routes` — gövde burada kurulur. */
  onCreate: (body: CreateRouteRequest) => void;
  isCreating: boolean;
  error: string | null;
  /** Oluşturulmuş rota — varsa metrik kartı gösterilir. */
  route: RouteDetail | null;
  /** Oluşturucuyu sıfırlar: çizgi + seçim + başlangıç. */
  onDiscardRoute: () => void;
  /**
   * R-122 — bir durağı rotadan çıkarır; kalanlar yeniden optimize edilir.
   * EKLEME ev detayındaki/liste kartındaki "Rotaya ekle" düğmesinden
   * yapılıyor (`ExplorePage.toggleRouteStop`), o yüzden burada karşılığı yok.
   */
  onRemoveStop: (propertyId: number) => void;
  /** Durak eklenip çıkarıldıktan sonra yeniden hesaplama sürüyor mu? */
  isReoptimizing: boolean;
  /** Önizlenen rotayı kaydeder (`POST /routes`). */
  onSave: (name: string, scheduledAt: string | null) => void;
  isSaving: boolean;
}

export function RouteBuilderPanel({
  options,
  onRemoveProperty,
  start,
  locationStatus,
  locationMessage,
  onUseLiveLocation,
  onPickAddress,
  onCreate,
  isCreating,
  error,
  route,
  onDiscardRoute,
  onRemoveStop,
  isReoptimizing,
  onSave,
  isSaving,
}: RouteBuilderPanelProps) {
  const [mode, setMode] = useState<TravelMode>('car');

  // Başlangıç Çankaya dışındaysa rota kurulamaz — OSRM grafiği yalnızca bu
  // ilçeyi kapsıyor, dışarıdaki bir nokta en yakın Çankaya yoluna yapışır
  // ve mesafe anlamsız büyür. Sessizce merkeze çekmek yerine kullanıcıdan
  // Çankaya'dan bir adres seçmesini istiyoruz.
  const startOutside = start != null && !isWithinCankaya(start);
  const hasUsableStart = start != null && !startOutside;
  const canCreate = options.length >= MIN_ROUTE_STOPS && hasUsableStart;

  function submit() {
    if (!canCreate || isCreating || !start) return;
    // Ad boş: `POST /routes/preview` ad istemiyor, kaydetme adımında
    // sorulacak.
    onCreate({
      name: '',
      start: { lat: start.lat, lon: start.lon, label: start.label },
      propertyIds: options.map((option) => option.id),
      mode,
    });
  }

  if (route) {
    return (
      <RouteMetricsCard
        route={route}
        onDiscard={onDiscardRoute}
        onRemoveStop={onRemoveStop}
        isReoptimizing={isReoptimizing}
        error={error}
        onSave={onSave}
        isSaving={isSaving}
      />
    );
  }

  return (
    <>
      <section className="drawer-section">
        <h2>Ziyaret rotası</h2>

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
                <span
                  className="route-item-score"
                  title={`Uygunluk skoru: ${option.totalScore.toFixed(1)}/100`}
                >
                  {/* Tam sayıya yuvarlanmıyor — bkz. PropertyDetailPanel'deki
                      aynı gerekçe: skorlar artık çok daha ayrışık, yuvarlama
                      farklı evleri aynı görünen puana taşıyabiliyordu. */}
                  {option.totalScore.toFixed(1)}
                  <span className="route-item-score-unit" aria-hidden="true">
                    /100
                  </span>
                </span>
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
          <p className="muted">
            Henüz konut seçilmedi — bir evin detayını aç, "Rotaya ekle" düğmesine bas.
          </p>
        )}
      </section>

      <section className="drawer-section">
        <h2>Nereden başlıyorsun?</h2>

        <RouteStartCombobox
          value={start}
          onChange={onPickAddress}
          onUseLiveLocation={onUseLiveLocation}
          locationStatus={locationStatus}
          locationMessage={locationMessage}
          invalid={startOutside}
        />

        {startOutside && (
          <p className="route-error" role="alert">
            Bu nokta <strong>Çankaya dışında</strong>. Konutların tamamı Çankaya&apos;da ve
            rota ağı yalnızca bu ilçeyi kapsıyor — kutuya dokunup Çankaya&apos;dan bir
            başlangıç adresi seç.
          </p>
        )}
      </section>

      <section className="drawer-section">
        <h2>Ulaşım</h2>
        {/* Rota adı burada SORULMUYOR — kaydetme adımına taşındı.
            Kullanıcı beğenmediği bir rota için ad uydurmak zorunda kalmasın. */}
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
      </section>

      {error && (
        <p className="route-error" role="alert">
          {error}
        </p>
      )}

      <div className="drawer-actions">
        {/* Pasif bir düğmenin SEBEBİ yazılmazsa kullanıcı çıkmaza girer:
            "neden basamıyorum?" sorusunun cevabı ekranda olmalı. */}
        {!canCreate && (
          <p className="muted route-blocked">
            {options.length < MIN_ROUTE_STOPS
              ? `Rota için en az ${MIN_ROUTE_STOPS} konut seç.`
              : 'Önce başlangıç noktanı belirle.'}
          </p>
        )}
        <button
          className="btn-primary btn-sm"
          type="button"
          disabled={!canCreate || isCreating}
          onClick={submit}
        >
          {isCreating ? 'Hesaplanıyor…' : 'Rota Oluştur'}
        </button>
      </div>
    </>
  );
}

/** Oluşturulmuş rotanın metrik kartı: toplam mesafe/süre + numaralı durak listesi.
 *  R-122: her durakta "Kaldır" — çıkarılan durak kalanlarla yeniden optimize edilir. */
function RouteMetricsCard({
  route,
  onDiscard,
  onRemoveStop,
  isReoptimizing,
  error,
  onSave,
  isSaving,
}: {
  route: RouteDetail;
  onDiscard: () => void;
  onRemoveStop: (propertyId: number) => void;
  isReoptimizing: boolean;
  error: string | null;
  onSave: (name: string, scheduledAt: string | null) => void;
  isSaving: boolean;
}) {
  const stops = [...route.stops].sort((a, b) => a.seq - b.seq);

  // Kaydetme formu yalnızca istenince açılır: rotayı görmek isteyen ama
  // kaydetmeyecek kullanıcı ad/tarih alanlarıyla karşılaşmasın.
  const [saveOpen, setSaveOpen] = useState(false);
  const [name, setName] = useState(routeNameForToday);
  const [scheduledAt, setScheduledAt] = useState('');

  return (
    <>
      <section className="drawer-section">
        <div className="route-metrics-head">
          <h2>{route.isSaved ? route.name : 'Rota hazır'}</h2>
          <span className="route-mode-badge">{travelModeLabel(route.mode)}</span>
        </div>

        <dl className="kv">
          <dt>Toplam mesafe</dt>
          <dd>{formatRouteDistance(route.totalDistanceM)}</dd>
          <dt>Tahmini süre</dt>
          <dd>{formatRouteDuration(route.totalDurationS)}</dd>
          <dt>Durak</dt>
          <dd>{route.stopCount} / {MAX_ROUTE_STOPS} konut</dd>
        </dl>

        {route.isSaved ? (
          <>
            <p className="data-badge">Rota kaydedildi · Profil → Kayıtlı Rotalarım</p>
            {route.scheduledAt && (
              <p className="route-schedule">🗓 {formatScheduledAt(route.scheduledAt)}</p>
            )}
          </>
        ) : (
          <p className="muted route-unsaved">
            Bu rota <strong>henüz kaydedilmedi</strong>. Beğendiysen kaydet, beğenmediysen
            durak çıkarıp yeniden hesaplat.
          </p>
        )}
      </section>

      {/* ─── Kaydetme (yalnızca kaydedilmemiş rotada) ─── */}
      {!route.isSaved && (
        <section className="drawer-section">
          {saveOpen ? (
            <>
              <h2>Rotayı kaydet</h2>
              <label className="field">
                <span>Rota adı</span>
                <input
                  value={name}
                  onChange={(event) => setName(event.target.value)}
                  maxLength={120}
                />
              </label>

              <label className="field">
                <span>Ne zaman gezeceksin? (isteğe bağlı)</span>
                <input
                  type="datetime-local"
                  value={scheduledAt}
                  onChange={(event) => setScheduledAt(event.target.value)}
                />
              </label>

              {/* Dürüstlük: tarih girmek bir HATIRLATICI kurmuyor. Mobil
                  bildirim henüz yok; olmayan bir özelliği ima etmek
                  kullanıcının randevuyu kaçırmasına yol açardı. */}
              <p className="route-hint" role="note">
                Tarih yalnızca planını kaydeder — şimdilik <strong>bildirim
                gönderilmez</strong>.
              </p>

              <div className="drawer-actions">
                <button
                  className="btn-primary btn-sm"
                  type="button"
                  disabled={isSaving || name.trim().length === 0}
                  onClick={() => onSave(name.trim(), toIsoOrNull(scheduledAt))}
                >
                  {isSaving ? 'Kaydediliyor…' : 'Kaydet'}
                </button>
                <button
                  className="btn-chip"
                  type="button"
                  onClick={() => setSaveOpen(false)}
                  disabled={isSaving}
                >
                  Vazgeç
                </button>
              </div>
            </>
          ) : (
            <button className="btn-primary btn-sm" type="button" onClick={() => setSaveOpen(true)}>
              Rotayı kaydet
            </button>
          )}
        </section>
      )}

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
              <span
                className="route-item-score"
                title={stop.score != null ? `Uygunluk skoru: ${stop.score.toFixed(1)}/100` : undefined}
              >
                {stop.score != null ? (
                  <>
                    {stop.score.toFixed(1)}
                    <span className="route-item-score-unit" aria-hidden="true">
                      /100
                    </span>
                  </>
                ) : (
                  '—'
                )}
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

        {/* Ekleme de çıkarma da aynı yeniden-hesaplamayı tetikliyor. */}
        {isReoptimizing && (
          <p className="route-hint" role="status">
            Rota yeniden hesaplanıyor…
          </p>
        )}

        <p className="muted route-edit-hint">
          Bir evin detayındaki ya da listedeki "Rotaya ekle" düğmesiyle
          <strong> ekleyebilir</strong>, buradaki ✕ ile çıkarabilirsin — rota
          kendiliğinden yeniden hesaplanır.
        </p>
        {error && (
          <p className="route-error" role="alert">
            {error}
          </p>
        )}
      </section>

      {/* "Rota düzenle" KALDIRILDI: rota açıkken haritadan konut
          ekleyip çıkarmak zaten aynı işi yapıyor, ayrı bir düzenleme kipi
          fazladan bir adımdan başka bir şey değildi. Geriye iki eylem
          kalıyor: kaydet ve sıfırla. */}
      <div className="drawer-actions">
        <button className="btn-chip" type="button" onClick={onDiscard} disabled={isSaving}>
          Sıfırla
        </button>
      </div>
    </>
  );
}

/**
 * `datetime-local` çıktısını (`2026-08-30T14:00`) ISO'ya çevirir.
 *
 * Değer YEREL saattir ve saat dilimi taşımaz. `new Date(...)` bunu yerel
 * kabul edip `toISOString()` ile UTC'ye çeviriyor — sunucudaki
 * `timestamptz` sütunu da böyle bekliyor. Ham string'i göndersek sunucu
 * onu UTC sanır ve randevu 3 saat kayardı.
 */
function toIsoOrNull(localValue: string): string | null {
  if (!localValue) return null;
  const parsed = new Date(localValue);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

/** ISO → '30 Ağustos Cumartesi, 14:00'. */
export function formatScheduledAt(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return '';
  return date.toLocaleString('tr-TR', {
    day: 'numeric',
    month: 'long',
    weekday: 'long',
    hour: '2-digit',
    minute: '2-digit',
  });
}
