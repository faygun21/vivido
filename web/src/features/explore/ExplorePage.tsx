import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type {
  CreateRouteRequest,
  LocationSearchResult,
  Persona,
  Poi,
  PoiCategory,
  PropertyDetail,
  PropertyMapItem,
  PropertySummary,
  RouteDetail,
  TopPropertiesResponse,
  UserProfile,
} from '@vivido/shared';
import { MAX_ANCHORS, MAX_ROUTE_STOPS, MIN_ROUTE_STOPS } from '@vivido/shared';
import { ApiError, api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { useAuthStore } from '@/features/auth/authStore';
import { AnchorEditor } from '@/features/anchors/AnchorEditor';
import { RouteBuilderPanel, type RoutePropertyOption } from './RouteBuilderPanel';
import { routeProblemMessage } from '@/shared/route/routeFormat';
import { useRouteStore } from '@/shared/route/routeStore';
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
import { useUserLocation } from '@/shared/map/useUserLocation';
import { startFromLiveLocation, type RouteStart } from '@/shared/route/routeStart';
import { createAnchorAreaPolygon, haversineDistanceMetres } from '@/shared/map/anchorSweetSpot';

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

type DrawerTab = 'profil' | 'analiz' | 'harita' | 'rota';

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

/** Analiz sekmesi ilk açıldığında alanların yerleştirileceği Çankaya merkezi. */
const DEFAULT_ANALYSIS_LOCATION: WalkingLocation = { lat: 39.87, lon: 32.85 };

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
  const location = useLocation();
  const navigate = useNavigate();
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

  useEffect(() => {
    const focus = (location.state as { favoriteFocus?: MapFocus } | null)?.favoriteFocus;
    if (!focus) return;

    setMapFocus(focus);
    setSelectedPropertyId(focus.id);
    navigate('/explore', { replace: true, state: null });
  }, [location.state, navigate]);

  // ─── R-120/121 — rota oluşturucu durumu ───
  const [routeIds, setRouteIds] = useState<number[]>([]);
  // Başlangıç artık haritadan SEÇİLMİYOR: canlı konum ya da yazılan adres.
  // Haritaya tıklamak zaten konut seçmek/analiz için kullanılıyordu; üçüncü
  // bir anlam yüklemek kipleri karıştırıyordu (bkz. shared/route/routeStart.ts).
  const [routeStart, setRouteStart] = useState<RouteStart | null>(null);

  // Canlı konum TEK yerden geliyor: haritadaki mavi nokta ve rota başlangıcı
  // aynı okumayı paylaşıyor. İki ayrı `getCurrentPosition` çağrısı tarayıcıya
  // iki kez izin sordurur ve iki farklı koordinat üretirdi.
  const {
    status: locationStatus,
    location: userLocation,
    message: locationMessage,
    request: requestUserLocation,
  } = useUserLocation();

  // R-121/123 — aktif rota iki ekran arasında paylaşılır (Profil → Explore).
  const activeRoute = useRouteStore((s) => s.activeRoute);
  const setActiveRoute = useRouteStore((s) => s.setActiveRoute);

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

  // Anchor'lardan (özel yerler) hesaplanan ağırlık merkezi + arama alanı.
  // Anchor yoksa null — gösterilecek/filtrelenecek bir alan yok.
  const anchorArea = useMemo(() => {
    const anchors = profile?.anchors ?? [];
    if (anchors.length === 0) return null;
    return createAnchorAreaPolygon(
      anchors.map((a) => ({ lat: a.lat, lon: a.lon, priority: a.priority, mode: a.mode })),
    );
  }, [profile?.anchors]);

  // Anchor'lar (özel yerler) varsa varsayılan olarak SADECE onların
  // çevresindeki alan gösterilir — kullanıcı bilerek "Tüm evleri göster"i
  // açmadıkça tik KAPALI kalıyor.
  const [showAllProperties, setShowAllProperties] = useState(false);

  // "En uygun evler" listesi. Ayrı bir uç nokta: `/properties` haritanın
  // TAMAMINI döndürüyor (binlerce kayıt) ve adres/gerekçe taşımıyor;
  // bunları 6.000 konut için hesaplatmak gereksiz iş olurdu.
  //
  // Anchor alanı aktifse (ve "Tüm evleri göster" kapalıysa) sunucuya da
  // aynı merkez/yarıçapı gönderiyoruz — yoksa sunucu TÜM ilçedeki en iyi
  // 20'yi seçip döner, bunların hiçbiri anchor alanının içinde olmayabilir.
  // Harita pinlerindeki client-side filtreyle (bkz. `propertyPoints`) AYNI
  // formülü (haversine) kullanıyor — ikisi farklı sınır çizmesin diye.
  const useAnchorFilter = anchorArea !== null && !showAllProperties;
  const { data: topResponse, isLoading: topLoading } = useSessionQuery({
    queryKey: [
      'properties',
      'top',
      useAnchorFilter ? anchorArea.center.lat : null,
      useAnchorFilter ? anchorArea.center.lon : null,
      useAnchorFilter ? anchorArea.radiusMetres : null,
    ],
    queryFn: () => {
      const params = new URLSearchParams({ limit: String(TOP_PROPERTY_LIMIT) });
      if (useAnchorFilter) {
        params.set('anchorLat', String(anchorArea.center.lat));
        params.set('anchorLon', String(anchorArea.center.lon));
        params.set('anchorRadiusM', String(anchorArea.radiusMetres));
      }
      return api.get<TopPropertiesResponse>(`/properties/top?${params.toString()}`);
    },
  });
  const topProperties = topResponse?.items ?? [];
  const topNearestFallback = topResponse?.nearestFallback ?? null;

  // ─── R-120/121 — rota ÖNİZLEME (hesaplar, KAYDETMEZ) ───
  //
  // Akış ikiye ayrıldı: önce `/routes/preview` ile hesaplanıp haritada
  // gösterilir, kullanıcı beğenirse `/routes` ile kaydedilir. Eskiden tek
  // adımdı ve her deneme "Kayıtlı Rotalarım"da çöp bırakıyordu.
  const queryClient = useQueryClient();
  const routeMutation = useMutation({
    mutationFn: (body: CreateRouteRequest) =>
      api.post<RouteDetail>('/routes/preview', body),
    onSuccess: (data) => setActiveRoute(data),
  });

  // ─── R-123 — önizlenen rotayı kaydet ───
  // Sunucu aynı girdiyle yeniden hesaplar (TSP + OSRM deterministik), bu
  // yüzden istemcinin geometriyi geri göndermesine gerek yok.
  const saveRouteMutation = useMutation({
    mutationFn: (body: CreateRouteRequest) => api.post<RouteDetail>('/routes', body),
    onSuccess: (data) => {
      setActiveRoute(data);
      void queryClient.invalidateQueries({ queryKey: ['routes'] });
    },
  });

  // Arayüz title'a değil `problem.code`'a dallanır (kural) — bkz. routeFormat.
  const activeRouteError = routeMutation.error ?? saveRouteMutation.error;
  const routeError =
    activeRouteError instanceof ApiError
      ? routeProblemMessage(activeRouteError.problem.code)
      : activeRouteError
        ? 'Rota oluşturulamadı. Lütfen yeniden dene.'
        : null;

  /**
   * Önizlenen rotayı kaydeder.
   *
   * Gövde önizlemedekiyle AYNI olmalı — aksi halde kaydedilen rota
   * kullanıcının haritada gördüğünden farklı çıkardı. Bu yüzden duraklar
   * `activeRoute.stops` sırasından değil, ORİJİNAL `routeIds` seçiminden
   * kuruluyor: sunucu TSP'yi yeniden çalıştırıp aynı sırayı üretiyor.
   */
  function handleSaveRoute(name: string, scheduledAt: string | null) {
    if (!activeRoute || !routeStart) return;
    saveRouteMutation.mutate({
      name,
      start: { lat: routeStart.lat, lon: routeStart.lon, label: routeStart.label },
      propertyIds: activeRoute.stops.map((stop) => stop.propertyId),
      mode: activeRoute.mode,
      scheduledAt,
    });
  }

  // Profil → Explore akışında (R-123) yüklenen rota için Rota sekmesini ve
  // çekmeceyi bir kez aç. Sonraki sekme geçişlerine karışmaz — id değişmedikçe.
  const lastAutoTabRouteIdRef = useRef<string | null>(null);
  useEffect(() => {
    if (!activeRoute) {
      lastAutoTabRouteIdRef.current = null;
      return;
    }
    if (lastAutoTabRouteIdRef.current === activeRoute.id) return;
    lastAutoTabRouteIdRef.current = activeRoute.id;
    setTab('rota');
    setDrawerOpen(true);
  }, [activeRoute]);

  /**
   * R-122 — aktif rotanın durak kümesini değiştirir ve YENİDEN OPTİMİZE eder.
   *
   * Hem çıkarma hem EKLEME buradan geçiyor: "Rota düzenle" düğmesi kaldırıldı,
   * çünkü rota açıkken haritadan konut eklemek/çıkarmak zaten aynı işi
   * yapıyor — ayrı bir "düzenleme kipi" gereksiz bir adımdı.
   *
   * Sonuç `/routes/preview`'dan geliyor, yani değiştirilen rota KAYDEDİLMEMİŞ
   * hâle döner. Doğrusu bu: kullanıcı kaydettiği rotayı değiştirdiyse artık
   * elinde farklı bir rota var; kart "henüz kaydedilmedi" diyerek bunu
   * açıkça söylüyor.
   */
  function reoptimizeRoute(nextPropertyIds: number[]) {
    if (!activeRoute) return;

    // En az 2 durak kalmıyorsa rota geçersiz — oluşturucuya dön.
    if (nextPropertyIds.length < MIN_ROUTE_STOPS) {
      setActiveRoute(null);
      setRouteIds(nextPropertyIds);
      routeMutation.reset();
      return;
    }

    // Seçim listesi rotayla aynı kalmalı: "Sıfırla" ve yeniden oluşturma
    // bu diziyi okuyor.
    setRouteIds(nextPropertyIds);

    routeMutation.mutate({
      name: activeRoute.name,
      start: {
        lat: activeRoute.start.lat,
        lon: activeRoute.start.lon,
        label: activeRoute.start.label,
      },
      propertyIds: nextPropertyIds,
      mode: activeRoute.mode,
    });
  }

  function handleRemoveRouteStop(propertyId: number) {
    if (!activeRoute) return;

    const remainingStops = activeRoute.stops.filter((stop) => stop.propertyId !== propertyId);

    // Optimistik: durak/sayaç anında düşer, toplamlar kalan bacaklardan
    // tahmin edilir. Sunucu yanıtı kesin TSP sırası/geometriyle değiştirir.
    // (Ekleme tarafında optimistik güncelleme YOK: yeni durağın nereye
    // gireceğini ve bacak sürelerini ancak sunucu bilir, uydurmak yanlış
    // sayı göstermek olurdu.)
    if (remainingStops.length >= MIN_ROUTE_STOPS) {
      setActiveRoute({
        ...activeRoute,
        stopCount: remainingStops.length,
        stops: remainingStops.map((stop, index) => ({ ...stop, seq: index + 1 })),
        totalDistanceM: remainingStops.reduce((sum, stop) => sum + (stop.legDistanceM ?? 0), 0),
        totalDurationS: remainingStops.reduce((sum, stop) => sum + (stop.legDurationS ?? 0), 0),
      });
    }

    reoptimizeRoute(remainingStops.map((stop) => stop.propertyId));
  }

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

  // Esc geçici durumları EN İÇTEKİNDEN dışarıya doğru, TEK TEK iptal eder:
  // önce nokta seçme kipleri (anchor / rota başlangıcı), sonra açık konut
  // detayı, sonra paneller. Hepsini birden kapatmak kullanıcının tek tuşla
  // ekranı boşaltmasına yol açardı.
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
  }, [
    picking,
    selectedPropertyId,
    topPanelOpen,
    drawerOpen,
    wideScreen,
  ]);

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
    // R-120 — rota başlangıcı haritada "A" pini ile işaretlenir.
    //
    // ⚠️ Başlangıç CANLI KONUMSA pin BASILMIYOR: aynı koordinatta zaten mavi
    // konum noktası var, ikisi üst üste binince kullanıcı iki ayrı yer
    // sanıyordu. Adresten seçilen başlangıç ise konumdan farklı bir nokta,
    // orada pin gerçekten bilgi taşıyor.
    ...(routeStart && routeStart.source === 'address'
      ? [{
          id: '__rota-baslangic',
          lat: routeStart.lat,
          lon: routeStart.lon,
          label: `Rota başlangıcı — ${routeStart.label}`,
          className: 'map-pin map-pin--route-start',
          text: 'A',
        }]
      : []),
  ];

  // R-120 — seçilen konutlar oluşturulmadan önce numaralı mavi pinlerle gösterilir.
  // Rota oluşunca yerlerini rota durağı pinleri alır (CankayaMap `route` prop'u).
  const routeSelectionMarkers: MapMarker[] = routeIds
    .map((id) => properties.find((p) => Number(p.id) === id))
    .filter((property): property is PropertyMapItem => property != null)
    .map((property, index) => ({
      id: `rota-secim-${property.id}`,
      lat: property.latitude,
      lon: property.longitude,
      label: `${index + 1}. rota durağı`,
      priority: index + 1,
      className: 'map-pin map-pin--route',
    }));

  // Rota panelinin listesi — seçim sırası korunur.
  const routeOptions: RoutePropertyOption[] = routeIds
    .map((id) => properties.find((p) => Number(p.id) === id))
    .filter((property): property is PropertyMapItem => property != null)
    .map((property) => ({
      id: Number(property.id),
      monthlyRent: property.monthlyRent,
      areaM2: property.areaM2,
      roomCount: property.roomCount,
      latitude: property.latitude,
      longitude: property.longitude,
      totalScore: property.totalScore,
    }));

  // Konutlar `markers`'a DEĞİL, ayrı bir cluster kaynağına gider — bkz.
  // CankayaMap'teki `konutlar` GeoJSON source (R-109: yakınlaştırma
  // seviyesine göre gruplanma/ayrılma).
  //
  // Anchor alanı varsa VE "Tüm evleri göster" kapalıysa, sadece o alana
  // düşen evler gösteriliyor — client-side filtre, backend'e dokunmadan
  // (harita zaten bütçeye uygun tüm evlerin konumunu getiriyor).
  const propertyPoints: PropertyPoint[] = properties
    .filter((p) => {
      if (showAllProperties || !anchorArea) return true;
      return (
        haversineDistanceMetres(anchorArea.center, { lat: p.latitude, lon: p.longitude })
        <= anchorArea.radiusMetres
      );
    })
    .map((p) => ({
      id: p.id,
      lat: p.latitude,
      lon: p.longitude,
    }));

  function handlePropertyClick(id: string) {
    // R-120 — "Rota" sekmesindeyken pin tıklaması detay yerine seçimi ekler/çıkarır.
    if (tab === 'rota') {
      const propertyId = Number(id);

      // Rota ZATEN oluşturulmuşsa aynı tıklama durak ekler/çıkarır ve rota
      // yeniden optimize edilir. Eskiden bunun için önce "Rota düzenle"ye
      // basmak gerekiyordu; o düğme kalktı çünkü fazladan bir kipten başka
      // bir şey yapmıyordu.
      if (activeRoute) {
        const currentIds = activeRoute.stops.map((stop) => stop.propertyId);
        if (currentIds.includes(propertyId)) {
          handleRemoveRouteStop(propertyId);
        } else if (currentIds.length < MAX_ROUTE_STOPS) {
          reoptimizeRoute([...currentIds, propertyId]);
        }
        return;
      }

      setRouteIds((current) => {
        if (current.includes(propertyId)) {
          return current.filter((value) => value !== propertyId);
        }
        if (current.length >= MAX_ROUTE_STOPS) return current;
        return [...current, propertyId];
      });
      return;
    }
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

  /**
   * "Konumumu kullan" — canlı konumu rota başlangıcı yapar.
   *
   * Konum henüz elde değilse yeniden ister; izin reddedilmişse tarayıcı
   * penceresi bir daha çıkmaz, o yüzden panel `locationMessage` ile ayarı
   * nasıl açacağını anlatıyor ve altında adres alternatifi duruyor.
   */
  function useLiveLocationAsStart() {
    if (userLocation) {
      setRouteStart(startFromLiveLocation(userLocation));
      return;
    }
    requestUserLocation();
  }

  // Konum "Konumumu kullan"a basıldıktan SONRA gelirse başlangıç kendiliğinden
  // dolsun — kullanıcı düğmeye ikinci kez basmak zorunda kalmasın. Yalnızca
  // başlangıç boşken devreye giriyor ki seçilmiş bir adresi ezmesin.
  useEffect(() => {
    if (!userLocation || routeStart !== null || locationStatus !== 'ready') return;
    setRouteStart(startFromLiveLocation(userLocation));
    // `routeStart` bilerek bağımlılıkta: null'dan çıktığı an efekt susmalı.
  }, [userLocation, routeStart, locationStatus]);

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

  function selectTab(nextTab: DrawerTab) {
    setTab(nextTab);
    if (nextTab === 'analiz' && !selectedLocation) {
      setSelectedLocation(DEFAULT_ANALYSIS_LOCATION);
    }
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
        // Rota oluşunca seçim pinleri yerine rota durağı pinleri + çizgi çizilir.
        markers={activeRoute ? markers : [...markers, ...routeSelectionMarkers]}
        // Katman panelindeki "Konutlar" anahtarı kapalıysa boş dizi gider —
        // kaynak yerinde kalır, yalnızca verisi boşalır.
        properties={propertiesVisible ? propertyPoints : []}
        focus={mapFocus}
        onMapClick={handleMapClick}
        onPropertyClick={handlePropertyClick}
        selectedLocation={tab === 'analiz' ? selectedLocation : null}
        onSelectedLocationChange={setSelectedLocation}
        walkingMinutes={walkingMinutes}
        analysisRadiusKm={analysisRadiusKm}
        pois={pois}
        poiCategoryNames={poiCategoryNames}
        onBoundsChange={handleBoundsChange}
        // Canlı konum haritada da rota başlangıcında da AYNI okuma —
        // bileşen kendi başına `getCurrentPosition` çağırmıyor.
        userLocation={userLocation}
        // R-121 — oluşturulmuş rota: çizgi + numaralı duraklar + otomatik sığdırma.
        route={activeRoute}
        anchorArea={anchorArea}
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
          // Liste boşsa NEDENİ ayırt etmek lazım: bütçeye uyan hiç ev yok mu
          // (properties zaten boş), yoksa bütçeye uyan evler var ama hiçbiri
          // anchor alanının içinde değil mi? İkincisinde "kira aralığını
          // genişlet" mesajı yanıltıcı olurdu — asıl sorun anchor alanı.
          emptyReason={
            topProperties.length > 0
              ? null
              : properties.length === 0
                ? 'budget'
                : useAnchorFilter
                  ? 'anchor-area'
                  : 'budget'
          }
          onShowAllProperties={() => setShowAllProperties(true)}
          nearestFallback={topNearestFallback}
          onSelectFallback={handleTopSelect}
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
              ['rota', 'Rota'],
              ['harita', 'Harita'],
            ] as const
          ).map(([value, title]) => (
            <button
              key={value}
              type="button"
              className={`drawer-tab${tab === value ? ' is-active' : ''}`}
              aria-current={tab === value}
              onClick={() => selectTab(value)}
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

          {tab === 'rota' &&
            (isGuest || !authenticated ? (
              <GuestPanel />
            ) : (
              <RouteBuilderPanel
                options={routeOptions}
                onRemoveProperty={(propertyId) =>
                  setRouteIds((current) => current.filter((id) => id !== propertyId))
                }
                start={routeStart}
                locationStatus={locationStatus}
                locationMessage={locationMessage}
                onUseLiveLocation={useLiveLocationAsStart}
                onPickAddress={setRouteStart}
                onCreate={(body) => routeMutation.mutate(body)}
                isCreating={routeMutation.isPending}
                error={routeError}
                route={activeRoute}
                // "Sıfırla" ASLA veri silmez: yalnızca ekranı ve
                // oluşturucuyu temizler. Kayıtlı rota Profil'de durur;
                // silmek için oradaki çöp kutusu kullanılır. Yanlışlıkla
                // basılması bu sayede zararsız.
                onDiscardRoute={() => {
                  setActiveRoute(null);
                  setRouteIds([]);
                  setRouteStart(null);
                  routeMutation.reset();
                  saveRouteMutation.reset();
                }}
                onRemoveStop={handleRemoveRouteStop}
                isReoptimizing={routeMutation.isPending}
                onSave={handleSaveRoute}
                isSaving={saveRouteMutation.isPending}
              />
            ))}

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
                  işaretli. Bir pin&apos;e tıklayınca adres, kira ve skorun gerekçesi açılır.
                  Sağ üstteki <strong>En uygun evler</strong> düğmesi en yüksek skorluları
                  sıralar.
                </p>
              )}

              <PoiLayerPanel
                categories={poiCategories}
                selectedCategories={selectedCategories}
                onToggleCategory={toggleCategory}
                propertiesVisible={propertiesVisible}
                onToggleProperties={() => setPropertiesVisible((v) => !v)}
                hasAnchorArea={anchorArea !== null}
                showAllProperties={showAllProperties}
                onToggleShowAllProperties={() => setShowAllProperties((v) => !v)}
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
