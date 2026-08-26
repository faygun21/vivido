import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import type {
  LocationSearchResult,
  UserProfile,
  Persona,
  PropertyDetail,
  PropertyMapItem,
  PropertySummary,
} from '@vivido/shared';
import { MAX_ANCHORS } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { useAuthStore } from '@/features/auth/authStore';
import { AnchorEditor } from '@/features/anchors/AnchorEditor';
import {
  CankayaMap,
  type MapFocus,
  type MapMarker,
  type MapPoint,
  type PropertyPoint,
} from '@/shared/map/CankayaMap';
import { LocationSearch } from './LocationSearch';
import { PropertyDetailPanel } from './PropertyDetailPanel';
import { TopPropertiesPanel } from './TopPropertiesPanel';
import {
  DEFAULT_WALKING_MINUTES,
  WALKING_MINUTE_OPTIONS,
  isWalkingMinutes,
  type WalkingLocation,
  type WalkingMinutes,
} from '@/shared/map/walkingAccessibility';
import {
  ANALYSIS_RADIUS_OPTIONS_KM,
  DEFAULT_ANALYSIS_RADIUS_KM,
  isAnalysisRadiusKm,
  type AnalysisRadiusKm,
} from '@/shared/map/analysisArea';

/**
 * Ana ekran — Çankaya haritası.
 *
 * ⭐ DÜZEN: harita ARKA PLAN değil, ekranın kendisidir.
 *
 * Eskiden 22rem'lik sabit bir sütun haritayı yanda sıkıştırıyordu ve
 * `.app-main` 68rem ile sınırlı olduğu için geniş ekranlarda harita
 * gereğinden küçük kalıyordu. Artık harita kenardan kenara; profil, konum
 * analizi ve harita bilgisi sol üstteki ☰ düğmesinin açtığı **çekmecede**.
 * Çekmece haritanın ÜSTÜNDE yüzer (yanına itmez) — böylece panel açıkken
 * de harita tam genişlikte kalır.
 *
 * İki kitlesi var:
 *   · giriş yapmış kullanıcı — profil özeti, anchor yönetimi, konum analizi
 *   · misafir (W0) — harita ve konutların temel bilgileri; skor YOK
 */

type DrawerTab = 'profil' | 'analiz' | 'harita';

/**
 * Konut tipleri artık `packages/shared`'dan geliyor.
 *
 * Eskiden bu dosyada YEREL arayüzler olarak yeniden tanımlıydılar; sunucu
 * yanıtı değiştiğinde derleme geçiyor, ekran sessizce boş kalıyordu.
 * Sözleşme tek yerde yaşamalı (CONTRIBUTING §6).
 */

/** CSS'teki `21.5rem` + kenar boşluğunun piksel karşılığı (16px kök punto). */
const DRAWER_WIDTH_PX = 21.5 * 16 + 29;

/**
 * Listede kaç konut gösterilecek.
 *
 * Sunucu 50'de kesiyor; buradaki değer o tavanı aşarsa sessizce kırpılır.
 */
const TOP_PROPERTY_LIMIT = 20;

/** Çekmecenin yüzen panel mi yoksa alttan açılan sayfa mı olduğu eşiği. */
const WIDE_SCREEN = '(min-width: 900px)';

function matchesWide(): boolean {
  return typeof window !== 'undefined' && window.matchMedia(WIDE_SCREEN).matches;
}

/**
 * Ekran genişliği eşiğini React durumu olarak izler.
 *
 * Yalnızca CSS ile çözülemiyor: harita padding'i ve çekmecenin ilk açıklığı
 * JavaScript tarafında biliniyor olmalı.
 */
function useWideScreen(): boolean {
  const [wide, setWide] = useState(matchesWide);

  useEffect(() => {
    const query = window.matchMedia(WIDE_SCREEN);
    const onChange = (event: MediaQueryListEvent) => setWide(event.matches);
    query.addEventListener('change', onChange);
    return () => query.removeEventListener('change', onChange);
  }, []);

  return wide;
}

export function ExplorePage() {
  const wideScreen = useWideScreen();
  // Çekmece geniş ekranda açık başlar; dar ekranda haritayı kapatmasın diye kapalı.
  const [drawerOpen, setDrawerOpen] = useState(matchesWide);
  const [tab, setTab] = useState<DrawerTab>('profil');
  const [mapFocus, setMapFocus] = useState<MapFocus | null>(null);
  const [selectedLocation, setSelectedLocation] = useState<WalkingLocation | null>(null);
  const [walkingMinutes, setWalkingMinutes] = useState<WalkingMinutes>(DEFAULT_WALKING_MINUTES);
  const [analysisRadiusKm, setAnalysisRadiusKm] = useState<AnalysisRadiusKm>(
    DEFAULT_ANALYSIS_RADIUS_KM,
  );

  /**
   * Haritaya tıklamak iki farklı iş yapabilir. Kip olmadan hangisinin
   * kastedildiği bilinemez, o yüzden açıkça iki mod var:
   *   · normal  → analiz konumu seçilir (yürüme/analiz alanı çizilir)
   *   · picking → yeni bir anchor noktası seçilir
   */
  const [picking, setPicking] = useState(false);
  const [pendingAnchor, setPendingAnchor] = useState<MapPoint | null>(null);
  const [selectedPropertyId, setSelectedPropertyId] = useState<string | null>(null);
  // Sağdaki liste kapalı başlar: kullanıcı önce haritayı görsün, listeyi
  // isteyince açsın. Soldaki çekmece geniş ekranda açık başlıyor; ikisi
  // birden açık açılsaydı harita iki panel arasında sıkışırdı.
  const [topPanelOpen, setTopPanelOpen] = useState(false);

  const isGuest = useAuthStore((s) => s.isGuest);
  const status = useAuthStore((s) => s.status);
  const authenticated = status === 'authenticated';

  // `useSessionQuery` iki şeyi birden halleder: anahtarı oturum kimliğine
  // bağlar (başka hesabın verisi okunamaz) ve misafirken korumalı uç
  // noktaya istek atılmasını engeller. Atılsaydı 401 → yenileme denemesi →
  // refresh token yok → `onSessionExpired` → `clearSession()` zinciri
  // çalışır ve misafir kendi kendini kapı dışarı ederdi.
  const { data: profile } = useSessionQuery({
    queryKey: ['profile'],
    queryFn: () => api.get<UserProfile>('/profile'),
    retry: false,
  });

  const { data: personas = [] } = useSessionQuery({
    queryKey: ['personas'],
    queryFn: () => api.get<Persona[]>('/personas'),
  });

  // Profile bağlı: bütçe aralığı sunucu tarafında `UserProfile` üzerinden
  // okunuyor, burada ayrıca göndermemiz gerekmiyor. `useSessionQuery` zaten
  // misafirken bu korumalı uca isteği hiç atmıyor (401 zincirini engeller).
  const { data: properties = [] } = useSessionQuery({
    queryKey: ['properties', 'map'],
    queryFn: () => api.get<PropertyMapItem[]>('/properties'),
  });

  const { data: selectedProperty = null } = useSessionQuery({
    queryKey: ['properties', 'detail', selectedPropertyId],
    queryFn: () => api.get<PropertyDetail>(`/properties/${selectedPropertyId}`),
    enabled: selectedPropertyId !== null,
  });

  // "En uygun evler" listesi. Ayrı bir uç nokta: `/properties` haritanın
  // TAMAMINI döndürüyor (binlerce kayıt) ve adres/gerekçe taşımıyor;
  // bunları 6.000 konut için hesaplatmak gereksiz iş olurdu.
  const { data: topProperties = [], isLoading: topLoading } = useSessionQuery({
    queryKey: ['properties', 'top'],
    queryFn: () => api.get<PropertySummary[]>(`/properties/top?limit=${TOP_PROPERTY_LIMIT}`),
  });

  const persona = personas.find((p) => p.code === profile?.personaCode);

  // Esc geçici durumları EN İÇTEKİNDEN dışarıya doğru iptal eder: önce nokta
  // seçme kipi, sonra açık konut detayı, sonra paneller. Hepsini birden
  // kapatmak kullanıcının tek tuşla ekranı boşaltmasına yol açardı.
  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key !== 'Escape') return;
      if (picking) setPicking(false);
      else if (selectedPropertyId) setSelectedPropertyId(null);
      else if (topPanelOpen) setTopPanelOpen(false);
      else if (drawerOpen && !wideScreen) setDrawerOpen(false);
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [picking, selectedPropertyId, topPanelOpen, drawerOpen, wideScreen]);

  const markers: MapMarker[] = [
    ...(profile?.anchors ?? []).map((a) => ({
      id: a.id,
      lat: a.lat,
      lon: a.lon,
      label: a.label,
      priority: a.priority,
    })),
    ...(pendingAnchor
      ? [{ id: '__yeni', lat: pendingAnchor.lat, lon: pendingAnchor.lon, label: 'Yeni yer' }]
      : []),
  ];

  // Konutlar `markers`'a DEĞİL, ayrı bir cluster kaynağına gider — bkz.
  // CankayaMap'teki `konutlar` GeoJSON source (R-109: yakınlaştırma
  // seviyesine göre gruplanma/ayrılma).
  const propertyPoints: PropertyPoint[] = properties.map((p) => ({
    id: p.id,
    lat: p.latitude,
    lon: p.longitude,
  }));

  function handlePropertyClick(id: string) {
    setSelectedPropertyId(id);
  }

  /**
   * Listeden bir konut seçildi.
   *
   * Haritayı o eve uçuruyoruz — aksi halde kullanıcı listede gördüğü evin
   * haritada NEREDE olduğunu bilmiyor ve iki panel birbirinden kopuk iki
   * uygulama gibi davranıyordu.
   */
  function handleTopSelect(property: PropertySummary) {
    setSelectedPropertyId(property.id);
    setMapFocus({
      id: property.id,
      label: property.address.formatted,
      lat: property.latitude,
      lon: property.longitude,
    });
    // Liste KAPATILMIYOR: detay onun üstünde açılıyor ve "← Listeye dön"
    // ile geri dönülüyor. Kapatsaydık geri dönülecek bir liste kalmaz,
    // kullanıcı düğmeye yeniden basmak zorunda kalırdı.
  }

  function handleMapClick(point: MapPoint) {
    if (picking) {
      setPendingAnchor(point);
      setPicking(false);
      setDrawerOpen(true);
      setTab('profil');
      return;
    }
    setSelectedLocation(point);
  }

  function startPicking() {
    setPicking(true);
    setPendingAnchor(null);
    // Dar ekranda çekmece haritanın tamamını kaplıyor; seçim yapılabilsin
    // diye kapatıyoruz. Geniş ekranda yüzen panel haritanın solunu örtüyor
    // ama tıklanacak alan zaten açıkta.
    if (!wideScreen) setDrawerOpen(false);
  }

  function focusLocation(location: LocationSearchResult) {
    setMapFocus({
      id: location.id,
      label: location.label,
      lat: location.latitude,
      lon: location.longitude,
      bounds: location.bounds,
    });
    setSelectedLocation({ lat: location.latitude, lon: location.longitude });
  }

  const anchorCount = profile?.anchors.length ?? 0;

  const showTopPanelToggle = authenticated && !isGuest;
  // Sağ yuva doluysa harita kontrolleri ve üst şerit sola kayar — ikisi de
  // aynı yuvayı paylaşıyor (master-detail), bkz. index.css `--right-slot`.
  const rightSlotOpen = topPanelOpen || selectedProperty !== null;

  return (
    <section
      className={
        'explore' +
        (drawerOpen ? ' explore--drawer-open' : '') +
        (topPanelOpen ? ' explore--top-open' : '') +
        (rightSlotOpen ? ' explore--right-open' : '')
      }
    >
      <CankayaMap
        markers={markers}
        properties={propertyPoints}
        focus={mapFocus}
        onMapClick={handleMapClick}
        onPropertyClick={handlePropertyClick}
        selectedLocation={selectedLocation}
        walkingMinutes={walkingMinutes}
        analysisRadiusKm={analysisRadiusKm}
        // Çekmece haritanın üstünde yüzüyor; örttüğü genişliği haritaya
        // bildiriyoruz ki ilçe sınırı panelin altında kalmasın.
        padLeft={drawerOpen && wideScreen ? DRAWER_WIDTH_PX : 0}
      />

      {selectedProperty && (
        <PropertyDetailPanel
          property={selectedProperty}
          onClose={() => setSelectedPropertyId(null)}
          // "← Listeye dön" yalnızca listeden gelindiğinde anlamlı; harita
          // pin'ine tıklayıp gelen kullanıcının dönecek bir listesi yok.
          onBack={topPanelOpen ? () => setSelectedPropertyId(null) : undefined}
        />
      )}

      {showTopPanelToggle && (
        <TopPropertiesPanel
          open={topPanelOpen}
          items={topProperties}
          isLoading={topLoading}
          selectedId={selectedPropertyId}
          onSelect={handleTopSelect}
          onClose={() => setTopPanelOpen(false)}
        />
      )}

      {/* Harita üstü kontroller: ☰ + konum arama aynı satırda durur ki
          çekmece düğmesi arama kutusunun altında kaybolmasın. */}
      <div className="map-topbar">
        <button
          className="map-fab"
          type="button"
          aria-expanded={drawerOpen}
          aria-controls="explore-drawer"
          aria-label={drawerOpen ? 'Paneli kapat' : 'Paneli aç'}
          onClick={() => setDrawerOpen((open) => !open)}
        >
          <span className="map-fab-bars" aria-hidden="true" />
        </button>

        {authenticated && (
          <div className="map-topbar-search">
            <LocationSearch onSelect={focusLocation} onClear={() => setMapFocus(null)} />
          </div>
        )}

        {/* Sağdaki listenin tetikleyicisi. Soldakinin aksine İKON DEĞİL,
            adını yazan bir düğme: iki hamburger yan yana durunca kullanıcı
            hangisinin ne açtığını tıklamadan bilemiyordu. */}
        {showTopPanelToggle && (
          <button
            className={`top-panel-toggle${topPanelOpen ? ' is-active' : ''}`}
            type="button"
            aria-expanded={topPanelOpen}
            aria-controls="top-properties-panel"
            onClick={() => setTopPanelOpen((open) => !open)}
          >
            <span className="top-panel-toggle-mark" aria-hidden="true" />
            En uygun evler
            {topProperties.length > 0 && (
              <span className="top-panel-toggle-count">{topProperties.length}</span>
            )}
          </button>
        )}
      </div>

      {picking && (
        <div className="map-banner" role="status">
          <span>Haritada bir noktaya tıkla</span>
          <button className="btn-chip" type="button" onClick={() => setPicking(false)}>
            Vazgeç
          </button>
        </div>
      )}

      <aside
        id="explore-drawer"
        className="explore-drawer"
        aria-hidden={!drawerOpen}
        // `inert` odak sırasını da kapatır: kapalı panelde Tab ile
        // görünmeyen düğmelere gitmek erişilebilirlik hatasıdır.
        inert={!drawerOpen}
      >
        <header className="drawer-head">
          <div>
            <h1>Keşfet</h1>
            <p className="muted">Çankaya · 124 mahalle</p>
          </div>
          <button
            className="btn-icon drawer-close"
            type="button"
            onClick={() => setDrawerOpen(false)}
            aria-label="Paneli kapat"
          >
            ✕
          </button>
        </header>

        <nav className="drawer-tabs" aria-label="Panel bölümleri">
          {(
            [
              ['profil', 'Profil'],
              ['analiz', 'Analiz'],
              ['harita', 'Harita'],
            ] as const
          ).map(([value, title]) => (
            <button
              key={value}
              type="button"
              className={`drawer-tab${tab === value ? ' is-active' : ''}`}
              aria-current={tab === value}
              onClick={() => setTab(value)}
            >
              {title}
            </button>
          ))}
        </nav>

        <div className="drawer-body">
          {tab === 'profil' &&
            (isGuest || !authenticated ? (
              <GuestPanel />
            ) : (
              <>
                <section className="drawer-section">
                  <h2>Profilin</h2>

                  {profile ? (
                    <dl className="kv">
                      <dt>Persona</dt>
                      <dd>{persona?.displayNameTr ?? profile.personaCode}</dd>

                      <dt>Kira aralığı</dt>
                      <dd>
                        {formatBudgetRange(profile.minMonthlyBudget, profile.maxMonthlyBudget)}
                      </dd>

                      <dt>Yerlerin</dt>
                      <dd>
                        {anchorCount} / {MAX_ANCHORS}
                      </dd>
                    </dl>
                  ) : (
                    <p className="muted">
                      Profil bulunamadı. <Link to="/onboarding">Onboarding&apos;i tamamla</Link>
                    </p>
                  )}

                  <Link className="btn-secondary btn-sm" to="/profile">
                    Profili düzenle
                  </Link>
                </section>

                <section className="drawer-section">
                  <h2>Düzenli gittiğin yerler</h2>
                  <p className="muted">
                    Önem sırasına dizdiğinde skorlar bu sıraya göre yeniden hesaplanır —
                    en önemli yer, diğerlerinin toplamı kadar ağırlık taşır.
                  </p>

                  <AnchorEditor
                    pending={pendingAnchor}
                    onPendingChange={setPendingAnchor}
                    onRequestPick={startPicking}
                    picking={picking}
                  />
                </section>
              </>
            ))}

          {tab === 'analiz' && (
            <section className="drawer-section">
              <h2>Konum analizi</h2>
              <p className="muted">
                Haritada bir konum seç veya arama yap. Analiz çevresini ve yaklaşık
                yürüme erişimini birlikte gösterelim.
              </p>

              <label className="field" htmlFor="analysis-radius">
                <span>Analiz mesafesi</span>
                <select
                  id="analysis-radius"
                  value={analysisRadiusKm}
                  onChange={(event) => {
                    const value = Number(event.target.value);
                    if (isAnalysisRadiusKm(value)) setAnalysisRadiusKm(value);
                  }}
                >
                  {ANALYSIS_RADIUS_OPTIONS_KM.map((radiusKm) => (
                    <option key={radiusKm} value={radiusKm}>
                      {radiusKm} km
                    </option>
                  ))}
                </select>
              </label>

              <label className="field" htmlFor="walking-minutes">
                <span>Yürüme süresi</span>
                <select
                  id="walking-minutes"
                  value={walkingMinutes}
                  onChange={(event) => {
                    const value = Number(event.target.value);
                    if (isWalkingMinutes(value)) setWalkingMinutes(value);
                  }}
                >
                  {WALKING_MINUTE_OPTIONS.map((minutes) => (
                    <option key={minutes} value={minutes}>
                      {minutes} dakika
                    </option>
                  ))}
                </select>
              </label>

              <ul className="legend">
                <li>
                  <span className="area-key area-key--analysis" />
                  {analysisRadiusKm} km analiz alanı
                </li>
                <li>
                  <span className="area-key area-key--walking" />
                  {walkingMinutes} dakika yürüme alanı
                </li>
              </ul>

              <p className="walking-access-status" aria-live="polite">
                {selectedLocation
                  ? walkingMinutes >= 15
                    ? 'Bu süre için arabayla gitmek daha gerçekçi.'
                    : `${walkingMinutes} dakikalık yürüme alanı gösteriliyor.`
                  : 'Alanı görmek için haritaya tıkla.'}
              </p>

              {selectedLocation && (
                <button
                  className="btn-secondary btn-sm"
                  type="button"
                  onClick={() => setSelectedLocation(null)}
                >
                  Seçimi temizle
                </button>
              )}
            </section>
          )}

          {tab === 'harita' && (
            <section className="drawer-section">
              <h2>Harita katmanları</h2>
              <p className="muted">
                Çankaya ilçe sınırı ve <strong>124 mahalle</strong> poligonu gösteriliyor.
                Mahalle üzerine gelince adı görünür.
              </p>
              {authenticated && !isGuest && (
                <p className="muted">
                  Bütçene uygun <strong>{properties.length} konut</strong> haritada 🏠 ile
                  işaretli. Bir pin&apos;e tıklayınca adres, kira ve skorun gerekçesi açılır.
                  Sağ üstteki <strong>En uygun evler</strong> düğmesi en yüksek skorluları
                  sıralar.
                </p>
              )}
              <ul className="legend">
                <li>
                  <span className="map-pin" style={{ position: 'static', width: '1.2rem', height: '1.2rem' }} />
                  Düzenli gittiğin yer
                </li>
                <li>
                  <span
                    className="map-pin map-pin--property"
                    style={{ position: 'static', width: '1.2rem', height: '1.2rem', fontSize: '0.7rem' }}
                  />
                  Bütçene uygun konut
                </li>
              </ul>
              <p className="data-badge">Konut verisi sentetiktir</p>
            </section>
          )}
        </div>
      </aside>
    </section>
  );
}

function formatBudgetRange(minMonthlyBudget: number | null, maxMonthlyBudget: number | null) {
  if (minMonthlyBudget != null && maxMonthlyBudget != null) {
    return `${minMonthlyBudget.toLocaleString('tr-TR')} ₺ – ${maxMonthlyBudget.toLocaleString('tr-TR')} ₺`;
  }
  if (minMonthlyBudget != null) return `${minMonthlyBudget.toLocaleString('tr-TR')} ₺ ve üzeri`;
  if (maxMonthlyBudget != null) return `${maxMonthlyBudget.toLocaleString('tr-TR')} ₺'ye kadar`;
  return 'Girilmedi';
}

/**
 * Misafirin gördüğü panel.
 *
 * Kilitli özellikleri gizlemek yerine GÖSTERİP kilit sebebini yazıyoruz —
 * "burada ne kaçırıyorum?" sorusunun cevabı kayıt olmanın tek gerekçesi.
 */
function GuestPanel() {
  const navigate = useNavigate();
  const leaveGuest = useAuthStore((s) => s.leaveGuest);

  function goAuth(path: string) {
    leaveGuest();
    navigate(path, { state: { from: { pathname: '/explore' } } });
  }

  return (
    <section className="drawer-section guest-card">
      <h2>Misafir olarak geziyorsun</h2>
      <p className="muted">
        Haritayı ve kiralık konutların temel bilgilerini serbestçe inceleyebilirsin.
      </p>

      {/* Metin TEK bir <span> içinde: `li` flex kutusu olduğu için her metin
          parçası ayrı bir flex öğesi olur ve cümle sütunlara bölünürdü. */}
      <ul className="locked-list">
        <li>
          <span className="lock">🔒</span>
          <span>
            Kişiselleştirilmiş <strong>0–100 skor</strong> ve skorun gerekçe tablosu
          </span>
        </li>
        <li>
          <span className="lock">🔒</span>
          <span>
            <strong>Persona seçimi</strong> ve aylık kira aralığı
          </span>
        </li>
        <li>
          <span className="lock">🔒</span>
          <span>
            <strong>Düzenli gittiğin yerleri</strong> ekleme ve önem sırasına dizme
          </span>
        </li>
      </ul>

      <div className="drawer-actions">
        <button className="btn-primary btn-sm" type="button" onClick={() => goAuth('/auth/register')}>
          Ücretsiz hesap oluştur
        </button>
        <button
          className="btn-secondary btn-sm"
          type="button"
          onClick={() => goAuth('/auth/login')}
        >
          Zaten hesabım var
        </button>
      </div>
    </section>
  );
}
