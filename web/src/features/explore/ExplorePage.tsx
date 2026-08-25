import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import type {
  LocationSearchResult,
  Persona,
  Poi,
  PoiCategory,
  UserProfile,
} from '@vivido/shared';
import { MAX_ANCHORS } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { useAuthStore } from '@/features/auth/authStore';
import { AnchorEditor } from '@/features/anchors/AnchorEditor';
import {
  CankayaMap,
  type MapBounds,
  type MapFocus,
  type MapMarker,
  type MapPoint,
  type PropertyPoint,
} from '@/shared/map/CankayaMap';
import { PoiLayerPanel } from './PoiLayerPanel';
import { LocationSearch } from './LocationSearch';
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

/** `PropertyMapItemDto` — bütçeye göre süzülmüş, skorlanmış konut özeti. */
interface PropertyMapItem {
  id: string;
  monthlyRent: number;
  areaM2: number;
  roomCount: string;
  latitude: number;
  longitude: number;
  totalScore: number;
}

/** `PropertyDetailDto` — pin'e tıklanınca açılan detay panelinin verisi. */
interface PropertyDetail {
  id: string;
  externalRef: string;
  monthlyRent: number;
  areaM2: number;
  roomCount: string;
  totalScore: number;
}

/** CSS'teki `21.5rem` + kenar boşluğunun piksel karşılığı (16px kök punto). */
const DRAWER_WIDTH_PX = 21.5 * 16 + 29;

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

  const persona = personas.find((p) => p.code === profile?.personaCode);

  // ─── R-108/109/110 — POI & konut katmanları ───
  const [bounds, setBounds] = useState<MapBounds | null>(null);
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  const [propertiesVisible, setPropertiesVisible] = useState(true);
  const selectionInitialized = useRef(false);
  const boundsTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Kategorileri tek sefer çeker; paneldeki isimler ve renkler buradan gelir.
  const { data: poiCategories = [] } = useQuery({
    queryKey: ['poi-categories'],
    queryFn: () => api.get<PoiCategory[]>('/pois/categories'),
    staleTime: 5 * 60 * 1000,
  });

  // İlk yüklemede tüm kategorileri açık başlat; kullanıcı sonradan kapatırsa
  // geri dönüp hepsini yeniden seçme.
  useEffect(() => {
    if (poiCategories.length > 0 && !selectionInitialized.current) {
      selectionInitialized.current = true;
      setSelectedCategories(poiCategories.map((c) => c.code));
    }
  }, [poiCategories]);

  // Harita taşındıkça gelen bbox'ı debounce ile sorguya işle.
  function handleBoundsChange(next: MapBounds) {
    if (boundsTimer.current) clearTimeout(boundsTimer.current);
    boundsTimer.current = setTimeout(() => setBounds(next), 250);
  }

  // Bekleyen debounce zamanlayıcısı unmount'ta temizlenmezse setState sonrası
  // uyarı üretir; ekran kapanınca sızıntı kalmasın.
  useEffect(() => {
    return () => {
      if (boundsTimer.current) clearTimeout(boundsTimer.current);
    };
  }, []);

  const boundsKey = bounds
    ? `${bounds.west.toFixed(4)},${bounds.south.toFixed(4)},${bounds.east.toFixed(4)},${bounds.north.toFixed(4)}`
    : null;

  const categoryParam = selectedCategories.join(',');

  const { data: pois = [] } = useQuery({
    queryKey: ['pois', boundsKey, categoryParam],
    queryFn: () =>
      api.get<Poi[]>(
        `/pois?west=${bounds!.west}&south=${bounds!.south}&east=${bounds!.east}` +
          `&north=${bounds!.north}&categories=${encodeURIComponent(categoryParam)}`,
      ),
    enabled: bounds != null && selectedCategories.length > 0,
    staleTime: 30_000,
  });

  /*
   * ⚠️ Burada bbox tabanlı bir KONUT sorgusu YOK — bilerek.
   *
   * Konutlar zaten yukarıdaki `['properties', 'map']` sorgusundan geliyor:
   * o uç nokta kullanıcının kira aralığına göre süzüyor ve her konutu
   * SKORLUYOR (W3/W5). İkinci bir bbox sorgusu aynı evleri skorsuz olarak
   * bir kez daha çizerdi — aynı ev haritada iki pin.
   *
   * `/properties/map` (herkese açık, skorsuz) sunucuda duruyor ve misafir
   * görünümü için hazır; ekrana bağlanması ayrı bir iş (bkz. PR açıklaması).
   */

  const poiCategoryNames = Object.fromEntries(
    poiCategories.map((c) => [c.code, c.displayNameTr]),
  );

  function toggleCategory(code: string) {
    setSelectedCategories((current) =>
      current.includes(code)
        ? current.filter((c) => c !== code)
        : [...current, code],
    );
  }

  // Esc her iki geçici durumu da iptal eder: önce nokta seçme kipi, sonra
  // çekmece. Modal olmayan bir panelde beklenen davranış budur.
  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key !== 'Escape') return;
      if (picking) setPicking(false);
      else if (drawerOpen && !wideScreen) setDrawerOpen(false);
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [picking, drawerOpen, wideScreen]);

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

  return (
    <section className={`explore${drawerOpen ? ' explore--drawer-open' : ''}`}>
      <CankayaMap
        markers={markers}
        // Katman panelindeki "Konutlar" anahtarı kapalıysa boş dizi gider —
        // kaynak yerinde kalır, yalnızca verisi boşalır.
        properties={propertiesVisible ? propertyPoints : []}
        focus={mapFocus}
        onMapClick={handleMapClick}
        onPropertyClick={handlePropertyClick}
        selectedLocation={selectedLocation}
        walkingMinutes={walkingMinutes}
        analysisRadiusKm={analysisRadiusKm}
        pois={pois}
        poiCategoryNames={poiCategoryNames}
        onBoundsChange={handleBoundsChange}
        // Çekmece haritanın üstünde yüzüyor; örttüğü genişliği haritaya
        // bildiriyoruz ki ilçe sınırı panelin altında kalmasın.
        padLeft={drawerOpen && wideScreen ? DRAWER_WIDTH_PX : 0}
      />

      {selectedProperty && (
        <div className="property-detail-card" role="dialog" aria-label="Konut detayları">
          <header>
            <h3>{selectedProperty.roomCount} · {selectedProperty.areaM2} m²</h3>
            <button
              className="btn-icon"
              type="button"
              onClick={() => setSelectedPropertyId(null)}
              aria-label="Kapat"
            >
              ✕
            </button>
          </header>
          <dl className="kv">
            <dt>Aylık kira</dt>
            <dd>{selectedProperty.monthlyRent.toLocaleString('tr-TR')} ₺</dd>
            <dt>Uygunluk skoru</dt>
            <dd>{Math.round(selectedProperty.totalScore)} / 100</dd>
            <dt>Referans</dt>
            <dd>{selectedProperty.externalRef}</dd>
          </dl>
          <p className="data-badge">Konut verisi sentetiktir</p>
        </div>
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
              <p className="muted">
                Hizmet noktaları ve konutlar haritada küme olarak çizilir; yakınlaşınca
                tek tek noktalara ayrışır. Noktaya tıklayınca bilgi penceresi açılır.
              </p>

              {authenticated && !isGuest && (
                <p className="muted">
                  Bütçene uygun <strong>{properties.length} konut</strong> haritada 🏠 ile
                  işaretli. Bir pin&apos;e tıklayınca kira ve uygunluk skoru açılır.
                </p>
              )}

              <PoiLayerPanel
                categories={poiCategories}
                selectedCategories={selectedCategories}
                onToggleCategory={toggleCategory}
                propertiesVisible={propertiesVisible}
                onToggleProperties={() => setPropertiesVisible((v) => !v)}
              />

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
