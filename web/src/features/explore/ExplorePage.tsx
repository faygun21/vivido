import { useEffect, useRef, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { keepPreviousData, useMutation, useQueries, useQuery, useQueryClient } from '@tanstack/react-query';
import { GuideMascot } from '@/components/GuideMascot';
import type {
  CreateRouteRequest,
  FavoriteResponse,
  LocationSearchResult,
  Persona,
  Poi,
  PoiCategory,
  PropertiesMapResponse,
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
import { LocationSearch } from '@/shared/location/LocationSearch';
import { PropertyDetailPanel } from './PropertyDetailPanel';
import { TopPropertiesPanel } from './TopPropertiesPanel';
import {
  DEFAULT_WALKING_MINUTES,
  WALKING_MINUTE_OPTIONS,
  haversineDistanceMetres,
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
import { matchesWide, useWideScreen } from '@/shared/useWideScreen';

type DrawerTab = 'profil' | 'analiz' | 'harita' | 'rota';

const DRAWER_WIDTH_PX = 21.5 * 16 + 29;
const TOP_PROPERTY_LIMIT = 20;
const DEFAULT_ANALYSIS_LOCATION: WalkingLocation = { lat: 39.87, lon: 32.85 };

/**
 * Yoğunluk bonusu olan bir kriterde en fazla kaç POI gösterilecek.
 *
 * "Dip dibe 2 market" senaryosunu göstermek yeterli — bazı kategoriler veri
 * kalitesi sorunu yüzünden (bkz. 2026-08-27 notu, `park`) yarıçapta
 * yüzlerce nokta dönebiliyor, sınır olmasa kalabalık sorunu geri gelirdi.
 */
const MAX_DENSITY_POIS_PER_CATEGORY = 8;

/** Güçlü yön ipucu bandını bir daha göstermemek için — kalıcı, oturumlar arası. */
const POI_HINT_STORAGE_KEY = 'vivido:poiHintSeen';

export function ExplorePage() {
  const location = useLocation();
  const navigate = useNavigate();
  const wideScreen = useWideScreen();
  const [drawerOpen, setDrawerOpen] = useState(matchesWide);
  const [tab, setTab] = useState<DrawerTab>('profil');
  const [mapFocus, setMapFocus] = useState<MapFocus | null>(null);
  const [selectedLocation, setSelectedLocation] = useState<WalkingLocation | null>(null);
  const [walkingMinutes, setWalkingMinutes] = useState<WalkingMinutes>(DEFAULT_WALKING_MINUTES);
  const [analysisRadiusKm, setAnalysisRadiusKm] = useState<AnalysisRadiusKm>(
    DEFAULT_ANALYSIS_RADIUS_KM,
  );

  const [picking, setPicking] = useState(false);
  const [pendingAnchor, setPendingAnchor] = useState<MapPoint | null>(null);
  const [selectedPropertyId, setSelectedPropertyId] = useState<string | null>(null);
  const [topPanelOpen, setTopPanelOpen] = useState(false);
  // Haritadaki "güçlü yön" ikonlarının ne olduğunu bir kez açıklıyoruz —
  // ilk evi seçtiğinde bandı görür, kapattığında/bir daha görmez (2026-08-28).
  const [poiHintDismissed, setPoiHintDismissed] = useState(
    () => localStorage.getItem(POI_HINT_STORAGE_KEY) === '1',
  );

  function dismissPoiHint() {
    localStorage.setItem(POI_HINT_STORAGE_KEY, '1');
    setPoiHintDismissed(true);
  }

  useEffect(() => {
    const focus = (location.state as { favoriteFocus?: MapFocus } | null)?.favoriteFocus;
    if (!focus) return;

    setMapFocus(focus);
    setSelectedPropertyId(focus.id);
    navigate('/explore', { replace: true, state: null });
  }, [location.state, navigate]);

  // ─── R-120/121 — rota oluşturucu durumu ───
  const [routeIds, setRouteIds] = useState<number[]>([]);
  const [routeStart, setRouteStart] = useState<RouteStart | null>(null);

  const {
    status: locationStatus,
    location: userLocation,
    message: locationMessage,
    request: requestUserLocation,
  } = useUserLocation();

  const activeRoute = useRouteStore((s) => s.activeRoute);
  const setActiveRoute = useRouteStore((s) => s.setActiveRoute);

  const isGuest = useAuthStore((s) => s.isGuest);
  const status = useAuthStore((s) => s.status);
  const authenticated = status === 'authenticated';

  const { data: profile } = useSessionQuery({
    queryKey: ['profile'],
    queryFn: () => api.get<UserProfile>('/profile'),
    retry: false,
  });

  // Kayıt sihirbazı (lifestyle → preferences → budget) yarıda bırakılabilir:
  // her adım profili KISMEN kaydediyor, yani "profil var" (404 dönmüyor)
  // ama bütçe hâlâ boş kalabiliyor. Bu durumda GetScoredProperties/
  // GetTopProperties bütçe filtresi uygulamadan TÜM evleri gösteriyordu ve
  // kullanıcı hiçbir uyarı almadan kişiselleştirmesiz kalıyordu — burayı
  // ziyaret eden her oturumda (yeniden giriş yapmasa bile) sihirbaza geri
  // gönderiyoruz, aksi halde eksik profil sonsuza dek fark edilmeyebilir.
  useEffect(() => {
    if (!authenticated || isGuest || !profile) return;
    if (profile.minMonthlyBudget == null && profile.maxMonthlyBudget == null) {
      navigate('/lifestyle', { replace: true });
    }
  }, [authenticated, isGuest, profile, navigate]);

  const { data: personas = [] } = useSessionQuery({
    queryKey: ['personas'],
    queryFn: () => api.get<Persona[]>('/personas'),
  });

  const [showAllProperties, setShowAllProperties] = useState(false);

  const { data: propertiesResponse } = useSessionQuery({
    queryKey: ['properties', 'map', showAllProperties],
    queryFn: () =>
      api.get<PropertiesMapResponse>(`/properties?showAll=${showAllProperties}`),
  });
  const properties = propertiesResponse?.items ?? [];

  const { data: selectedProperty = null } = useSessionQuery({
    queryKey: ['properties', 'detail', selectedPropertyId],
    queryFn: () => api.get<PropertyDetail>(`/properties/${selectedPropertyId}`),
    enabled: selectedPropertyId !== null,
  });

  const strengths = selectedProperty?.score.strengths ?? [];
  const singlePoiIds = Array.from(new Set(
    strengths
      .filter((row) => row.densityBonus === 0)
      .map((row) => row.poiId)
      .filter((id): id is number => id !== null),
  ));
  const densityRows = strengths.filter((row) => row.densityBonus !== 0);

  const { data: singlePois = [] } = useQuery({
    queryKey: ['pois', 'by-id', singlePoiIds.join(',')],
    queryFn: () => api.get<Poi[]>(`/pois/by-id?ids=${singlePoiIds.join(',')}`),
    enabled: singlePoiIds.length > 0,
  });
  const densityQueries = useQueries({
    queries: densityRows.map((row) => ({
      queryKey: [
        'pois', 'near', selectedProperty?.id, row.categoryCode, row.searchRadiusM,
      ],
      queryFn: () =>
        api.get<Poi[]>(
          `/pois/near?lat=${selectedProperty!.latitude}&lon=${selectedProperty!.longitude}` +
            `&radiusM=${row.searchRadiusM}&category=${encodeURIComponent(row.categoryCode)}`,
        ),
      enabled: selectedProperty != null,
    })),
  });

  const densityPois = selectedProperty
    ? densityQueries.flatMap((q) =>
        (q.data ?? [])
          .map((poi) => ({
            poi,
            distance: haversineDistanceMetres(
              { lat: selectedProperty.latitude, lon: selectedProperty.longitude },
              { lat: poi.latitude, lon: poi.longitude },
            ),
          }))
          .sort((a, b) => a.distance - b.distance)
          .slice(0, MAX_DENSITY_POIS_PER_CATEGORY)
          .map((entry) => entry.poi),
      )
    : [];
  const highlightedPois = [...singlePois, ...densityPois];

  const persona = personas.find((p) => p.code === profile?.personaCode);

  const { data: topResponse, isLoading: topLoading } = useSessionQuery({
    queryKey: ['properties', 'top', showAllProperties],
    queryFn: () =>
      api.get<TopPropertiesResponse>(
        `/properties/top?limit=${TOP_PROPERTY_LIMIT}&showAll=${showAllProperties}`,
      ),
  });
  const topProperties = topResponse?.items ?? [];
  const topNearestFallback = topResponse?.nearestFallback ?? null;

  const queryClient = useQueryClient();

  /**
   * `POST /routes` çift tıklama/kayıt korumasını backend `Idempotency-Key`
   * header'ıyla yapıyor (5dk pencere, aynı anahtarla ikinci istek yeniden
   * kaydetmez, ilk sonucu döner) — ama bu header'ı ÜRETEN taraf istemci.
   * Her yeni önizleme (bkz. `routeMutation.onSuccess`) farklı bir rotadır,
   * bu yüzden yeni bir anahtar alır; aynı önizlemeyi kaydetmeye yönelik
   * art arda "Kaydet" tıklamaları aynı anahtarı paylaşır.
   */
  const routeIdempotencyKeyRef = useRef(crypto.randomUUID());

  const routeMutation = useMutation({
    mutationFn: (body: CreateRouteRequest) =>
      api.post<RouteDetail>('/routes/preview', body),
    onSuccess: (data) => {
      routeIdempotencyKeyRef.current = crypto.randomUUID();
      setActiveRoute(data);
    },
  });

  const saveRouteMutation = useMutation({
    mutationFn: (body: CreateRouteRequest) =>
      api.post<RouteDetail>('/routes', body, {
        headers: { 'Idempotency-Key': routeIdempotencyKeyRef.current },
      }),
    onSuccess: (data) => {
      setActiveRoute(data);
      void queryClient.invalidateQueries({ queryKey: ['routes'] });
    },
  });

  const activeRouteError = routeMutation.error ?? saveRouteMutation.error;
  const routeError =
    activeRouteError instanceof ApiError
      ? routeProblemMessage(activeRouteError.problem.code)
      : activeRouteError
        ? 'Rota oluşturulamadı. Lütfen yeniden dene.'
        : null;

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

  function reoptimizeRoute(nextPropertyIds: number[]) {
    if (!activeRoute) return;

    if (nextPropertyIds.length < MIN_ROUTE_STOPS) {
      setActiveRoute(null);
      setRouteIds(nextPropertyIds);
      routeMutation.reset();
      return;
    }

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

  /**
   * Rota durağını ekler/çıkarır (toggle) — R-120/122/124.
   *
   * Harita pinine "Rota" sekmesindeyken tıklamakla AYNI mantık, ama artık
   * "En uygun evler" panelindeki ve ev detayındaki "Rotaya ekle"
   * düğmelerinden de çağrılıyor — favori düğmesiyle aynı tema, herhangi bir
   * sekmedeyken/haritanın neresinde olursan ol çalışır.
   */
  function toggleRouteStop(propertyId: number) {
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
  }

  // ─── R-108/109/110 — POI & konut katmanları ───
  const [bounds, setBounds] = useState<MapBounds | null>(null);
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  const [propertiesVisible, setPropertiesVisible] = useState(true);
  // Favori katmanı KAPALI başlar: harita zaten konut, POI ve anchor
  // katmanlarını taşıyor. Kullanıcı favorilerini görmek istediğinde
  // açar — açık başlasaydı favorisi olmayan kullanıcı için hiçbir şey
  // yapmayan, olan içinse istemediği bir katman olurdu.
  const [favoritesVisible, setFavoritesVisible] = useState(false);
  const boundsTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const { data: poiCategories = [] } = useQuery({
    queryKey: ['poi-categories'],
    queryFn: () => api.get<PoiCategory[]>('/pois/categories'),
    staleTime: 5 * 60 * 1000,
  });

  /*
    Favoriler — haritada yıldızla gösterilecek konutlar.

    ⚠️ Sorgu anahtarı `['favorites']`: profil sayfası ve "en uygun evler"
    panelindeki kalp düğmesi (`useFavoriteMutation`) tam bu anahtarı
    invalidate ediyor. Yani kullanıcı listeden bir evi favorilerine
    eklediği an haritadaki yıldız da beliriyor — ayrıca bir tazeleme
    kablosu çekmeye gerek yok.

    Misafir kullanıcıda `useSessionQuery` isteği hiç atmaz (oturum
    koşuluyla VE'leniyor, bkz. K-14), bu yüzden ayrı bir `enabled`
    koşulu yok.
  */
  const { data: favorites = [] } = useSessionQuery({
    queryKey: ['favorites'],
    queryFn: () => api.get<FavoriteResponse[]>('/profile/favorites'),
    retry: false,
  });

  // Konutu silinmiş favoriler `property: null` döner (bkz. profildeki
  // `FavoriteCard`) — koordinatı olmayan bir noktayı haritaya koyamayız.
  const favoritePoints: PropertyPoint[] = favorites.flatMap((favorite) =>
    favorite.property
      ? [{
          id: String(favorite.property.id),
          lat: favorite.property.latitude,
          lon: favorite.property.longitude,
        }]
      : [],
  );

  function handleBoundsChange(next: MapBounds) {
    if (boundsTimer.current) clearTimeout(boundsTimer.current);
    boundsTimer.current = setTimeout(() => setBounds(next), 250);
  }

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
    // ⚠️ `placeholderData` OLMADAN: harita her hareket ettiğinde `boundsKey`
    // değişip yeni sorgu başlıyor, TanStack Query yeni veri gelene kadar
    // `pois`'i `undefined`'a (→ `[]`'e) düşürüyordu — ikonlar bir anlığına
    // kayboluyor, veri gelince geri geliyordu ("titreme", 2026-08-28).
    // Eski liste yeni veri gelene kadar EKRANDA KALIYOR artık.
    placeholderData: keepPreviousData,
  });

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

  const propertyPoints: PropertyPoint[] = properties.map((p) => ({
    id: p.id,
    lat: p.latitude,
    lon: p.longitude,
  }));

  // Pin tıklaması her sekmede AYNI şeyi yapar: detay panelini açar.
  //
  // Eskiden "Rota" sekmesindeyken tıklamak konutu doğrudan rotaya
  // ekliyordu/çıkarıyordu — kullanıcı evin özelliklerine hiç bakmadan,
  // "unutarak" bir sürü ev ekleyebiliyordu (2026-08-28). Artık rotaya
  // ekleme SADECE detay panelindeki/liste kartındaki açık "Rotaya ekle"
  // düğmesinden oluyor — kullanıcı önce evi görür, sonra karar verir.
  function handlePropertyClick(id: string) {
    // Dar ekranda çekmece VE konut paneli aynı anda "açık" kalırsa ikisi de
    // aynı alt-sayfa (bottom sheet) düzenini paylaştığı için üst üste biner
    // (konut paneli üstte görünür ama çekmece DOM'da hâlâ açık kalır —
    // klavye/screen-reader gezinmesi görünmeyen çekmeceye düşebilir).
    if (!wideScreen) setDrawerOpen(false);
    setSelectedPropertyId(id);
  }

  function handleTopSelect(property: PropertySummary) {
    if (!wideScreen) setDrawerOpen(false);
    setSelectedPropertyId(property.id);
    setMapFocus({
      id: property.id,
      label: property.address.formatted,
      lat: property.latitude,
      lon: property.longitude,
    });
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
    if (!wideScreen) setDrawerOpen(false);
  }

  function useLiveLocationAsStart() {
    if (userLocation) {
      setRouteStart(startFromLiveLocation(userLocation));
      return;
    }
    requestUserLocation();
  }

  useEffect(() => {
    if (!userLocation || routeStart !== null || locationStatus !== 'ready') return;
    setRouteStart(startFromLiveLocation(userLocation));
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
  const rightSlotOpen = topPanelOpen || selectedProperty !== null;

  // "Rotaya ekle" düğmesi favori düğmesiyle aynı temada ("En uygun evler"
  // panelinde ve ev detayında), ama rota tamamen istemci-taraflı bir
  // seçim (henüz kaydedilmiş bir sunucu kaydı değil) — bu yüzden
  // `isFavorite` gibi API'den gelmiyor, burada türetiliyor. Rota
  // ZATEN hesaplanmışsa (`activeRoute`) oradaki duraklar, değilse
  // henüz-kaydedilmemiş seçim (`routeIds`) esas alınır.
  const routePropertyIds = new Set(
    activeRoute ? activeRoute.stops.map((stop) => stop.propertyId) : routeIds,
  );
  const routeAtCapacity = routePropertyIds.size >= MAX_ROUTE_STOPS;
  // Rota oluşturma zaten misafire kapalı (bkz. "rota" sekmesindeki
  // GuestPanel) — düğmeyi de aynı koşulla gösteriyoruz.
  const showRouteButton = authenticated && !isGuest;

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
        markers={activeRoute ? markers : [...markers, ...routeSelectionMarkers]}
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
        highlightedPois={highlightedPois}
        favorites={favoritesVisible ? favoritePoints : []}
        selectedPropertyId={selectedPropertyId}
        onBoundsChange={handleBoundsChange}
        userLocation={userLocation}
        route={activeRoute}
        padLeft={drawerOpen && wideScreen ? DRAWER_WIDTH_PX : 0}
      />

      {selectedProperty && (
        <PropertyDetailPanel
          property={selectedProperty}
          onClose={() => setSelectedPropertyId(null)}
          onBack={topPanelOpen ? () => setSelectedPropertyId(null) : undefined}
          showRouteButton={showRouteButton}
          isInRoute={routePropertyIds.has(Number(selectedProperty.id))}
          routeAtCapacity={routeAtCapacity}
          onToggleRoute={() => toggleRouteStop(Number(selectedProperty.id))}
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
          emptyReason={
            topProperties.length > 0 ? null : topNearestFallback ? 'anchor-area' : 'budget'
          }
          onShowAllProperties={() => setShowAllProperties(true)}
          nearestFallback={topNearestFallback}
          onSelectFallback={handleTopSelect}
          routePropertyIds={routePropertyIds}
          routeAtCapacity={routeAtCapacity}
          onToggleRoute={toggleRouteStop}
        />
      )}

      {/* Sağ alta sabitlenmiş menü açma tuşu (FAB) */}
      {!drawerOpen && (
        <button
          className="map-fab"
          type="button"
          aria-expanded={false}
          aria-controls="explore-drawer"
          aria-label="Paneli aç"
          onClick={() => setDrawerOpen(true)}
          style={{
            position: 'absolute',
            bottom: '2.5rem', 
            right: 'calc(var(--right-slot) + 1.25rem)',
            zIndex: 6,
            transition: 'right 0.22s ease, background 0.15s ease, border-color 0.15s ease'
          }}
        >
          <span className="map-fab-bars" aria-hidden="true" />
        </button>
      )}

      <div className="map-topbar">
        {showTopPanelToggle && !topPanelOpen && (
          <button
            className="top-panel-toggle"
            type="button"
            aria-expanded={false}
            aria-controls="top-properties-panel"
            onClick={() => setTopPanelOpen(true)}
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

      {highlightedPois.length > 0 && !poiHintDismissed && (
        <div className="map-banner map-banner--info" role="status">
          <span>Haritadaki işaretler bu evin güçlü yönleri</span>
          <button className="btn-chip" type="button" onClick={dismissPoiHint}>
            Anladım
          </button>
        </div>
      )}

      <aside
        id="explore-drawer"
        className="explore-drawer"
        aria-hidden={!drawerOpen}
        inert={!drawerOpen}
      >
        <header className="drawer-head">
          <div>
            <h1>Keşfet</h1>
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

        {authenticated && (
          <div style={{ padding: '0.75rem 0.85rem 0 0.85rem', position: 'relative', zIndex: 2 }}>
            <LocationSearch onSelect={focusLocation} onClear={() => setMapFocus(null)} />
          </div>
        )}

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
              {/* Rota kapasitesi HER sekmede görünsün — kullanıcı doluluğu
                  yalnızca ekleyemeyince (title tooltip'iyle) öğrenmesin. */}
              {value === 'rota' && routePropertyIds.size > 0 && (
                <span className="drawer-tab-count">
                  {routePropertyIds.size}/{MAX_ROUTE_STOPS}
                </span>
              )}
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
                Analiz için haritadan bir konum seç. Çevresini ve yaklaşık yürüme erişimini haritada gösterelim.
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
                  ? walkingMinutes > 15
                    ? 'Seçilen süre için yaya erişimi yerine taşıt kullanımı önerilir.'
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

              {isGuest && (
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
                hasAnchorArea={anchorCount > 0}
                showAllProperties={showAllProperties}
                onToggleShowAllProperties={() => setShowAllProperties((v) => !v)}
                canUseFavorites={authenticated && !isGuest}
                favoritesVisible={favoritesVisible}
                onToggleFavorites={() => setFavoritesVisible((v) => !v)}
                favoriteCount={favoritePoints.length}
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
                {/* Gösterge yalnızca katman AÇIKKEN — kapalıyken haritada
                    karşılığı olmayan bir sembolü açıklamak kafa karıştırır. */}
                {favoritesVisible && (
                  <li>
                    <span
                      className="map-pin map-pin--favorite"
                      style={{ position: 'static', width: '1.2rem', height: '1.2rem' }}
                    />
                    Favori konutun
                  </li>
                )}
              </ul>
              <p className="data-badge">Konut verisi sentetiktir</p>
            </section>
          )}
        </div>
      </aside>

      <GuideMascot 
        isOpen={drawerOpen} 
        onTabChange={setTab} 
      />
    </section>
  );
}

function formatBudgetRange(minMonthlyBudget: number | null, maxMonthlyBudget: number | null) {
  if (minMonthlyBudget != null && maxMonthlyBudget != null) {
    return `${minMonthlyBudget.toLocaleString('tr-TR')} ₺ – ${maxMonthlyBudget.toLocaleString('tr-TR')} ₺`;
  }
  if (minMonthlyBudget != null) return `${minMonthlyBudget.toLocaleString('tr-TR')} ₺ ve üzeri`;
  if (maxMonthlyBudget != null) return `${maxMonthlyBudget.toLocaleString('tr-TR')} ₺&apos;ye kadar`;
  return 'Girilmedi';
}

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