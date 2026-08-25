import { useEffect, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link, useNavigate } from 'react-router-dom';
import type {
  LocationSearchResult,
  UserProfile,
  Persona,
  Poi,
  PoiCategory,
  MapProperty,
} from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';
import {
  CankayaMap,
  type MapFocus,
  type MapMarker,
  type MapBounds,
} from '@/shared/map/CankayaMap';
import { LocationSearch } from './LocationSearch';
import { PoiLayerPanel } from './PoiLayerPanel';

/**
 * Ana ekran — Çankaya haritası.
 *
 * İki kitlesi var:
 *   · giriş yapmış kullanıcı — profil özeti, anchor pinleri, (Hafta 2'de) skorlar
 *   · misafir (W0) — sadece harita ve konutların temel bilgileri; skor YOK
 *
 * Bu tur kapsamı: harita görünür ve gezilebilir, profil özeti yanda.
 * Skorlanmış ev listesi + filtreler Hafta 2'nin backend işleri
 * (`GET /properties`) bitince buraya eklenecek — harita bileşeni aynı kalır,
 * üzerine nokta katmanı serilir.
 */
export function ExplorePage() {
  const [mapFocus, setMapFocus] = useState<MapFocus | null>(null);
  const isGuest = useAuthStore((s) => s.isGuest);
  const status = useAuthStore((s) => s.status);
  const authenticated = status === 'authenticated';

  // ⚠️ Misafirken korumalı uç noktalara İSTEK ATILMAZ. Atılsaydı 401 →
  // yenileme denemesi → refresh token yok → `onSessionExpired` →
  // `clearSession()` zinciri çalışır ve misafir kendi kendini kapı dışarı
  // ederdi. `enabled` bayrağı bunu tek satırda kesiyor.
  const { data: profile } = useQuery({
    queryKey: ['profile'],
    queryFn: () => api.get<UserProfile>('/profile'),
    retry: false,
    enabled: authenticated,
  });

  const { data: personas = [] } = useQuery({
    queryKey: ['personas'],
    queryFn: () => api.get<Persona[]>('/personas'),
    enabled: authenticated,
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

  const { data: properties = [] } = useQuery({
    queryKey: ['map-properties', boundsKey],
    queryFn: () =>
      api.get<MapProperty[]>(
        `/properties?west=${bounds!.west}&south=${bounds!.south}&east=${bounds!.east}` +
          `&north=${bounds!.north}`,
      ),
    enabled: bounds != null && propertiesVisible,
    staleTime: 30_000,
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

  const markers: MapMarker[] = (profile?.anchors ?? []).map((a) => ({
    id: a.id,
    lat: a.lat,
    lon: a.lon,
    label: a.label,
    priority: a.priority,
  }));

  function focusLocation(location: LocationSearchResult) {
    setMapFocus({
      id: location.id,
      label: location.label,
      lat: location.latitude,
      lon: location.longitude,
      bounds: location.bounds,
    });
  }

  function formatBudgetRange(
    minMonthlyBudget: number | null,
    maxMonthlyBudget: number | null,
  ) {
    if (minMonthlyBudget != null && maxMonthlyBudget != null) {
      return `${minMonthlyBudget.toLocaleString('tr-TR')} ₺ - ${maxMonthlyBudget.toLocaleString('tr-TR')} ₺`;
    }

    if (minMonthlyBudget != null) {
      return `${minMonthlyBudget.toLocaleString('tr-TR')} ₺ ve üzeri`;
    }

    if (maxMonthlyBudget != null) {
      return `${maxMonthlyBudget.toLocaleString('tr-TR')} ₺'ye kadar`;
    }

    return 'Girilmedi';
  }

  return (
    <section className="explore">
      <aside className="explore-side">
        <h1>Keşfet</h1>

        {isGuest ? (
          <GuestPanel />
        ) : (
          <div className="info-card">
            <h2>Profilin</h2>

            {profile ? (
              <dl className="kv">
                <dt>Persona</dt>
                <dd>{persona?.displayNameTr ?? profile.personaCode}</dd>

                <dt>Kira Aralığı</dt>
                <dd>
                  {formatBudgetRange(
                    profile.minMonthlyBudget,
                    profile.maxMonthlyBudget,
                  )}
                </dd>

                <dt>Yerlerin</dt>
                <dd>{profile.anchors.length} / 3</dd>
              </dl>
            ) : (
              <p className="muted">
                Profil bulunamadı.{' '}
                <Link to="/onboarding">
                  Onboarding&apos;i tamamla
                </Link>
              </p>
            )}

            <Link className="btn-secondary" to="/profile">
              Profili düzenle
            </Link>
          </div>
        )}

        <div className="info-card">
          <h2>Harita</h2>

          <p className="muted">
            Çankaya ilçe sınırı ve <strong>124 mahalle</strong> poligonu gösteriliyor.
            Mahalle üzerine gelince adı görünür.
          </p>

          <p className="muted">
            Hizmet noktaları ve konutlar haritada küme olarak çizilir; yakınlaşınca
            tek tek noktalara ayrışır. Noktaya tıklayınca bilgi penceresi açılır.
          </p>
        </div>

        <PoiLayerPanel
          categories={poiCategories}
          selectedCategories={selectedCategories}
          onToggleCategory={toggleCategory}
          propertiesVisible={propertiesVisible}
          onToggleProperties={() => setPropertiesVisible((v) => !v)}
        />

        <p className="data-badge">Konut verisi sentetiktir</p>
      </aside>

      <div className="explore-map">
        <CankayaMap
          markers={markers}
          focus={mapFocus}
          pois={pois}
          properties={propertiesVisible ? properties : []}
          poiCategoryNames={poiCategoryNames}
          onBoundsChange={handleBoundsChange}
        />

        {authenticated && (
          <LocationSearch
            onSelect={focusLocation}
            onClear={() => setMapFocus(null)}
          />
        )}
      </div>
    </section>
  );
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
    <div className="info-card guest-card">
      <h2>Misafir olarak geziyorsun</h2>

      <p className="muted">
        Haritayı ve kiralık konutların temel bilgilerini serbestçe
        inceleyebilirsin.
      </p>

      <ul className="locked-list">
        <li>
          <span className="lock">🔒</span>{' '}
          Kişiselleştirilmiş <strong>0–100 skor</strong> ve skorun gerekçe tablosu
        </li>

        <li>
          <span className="lock">🔒</span>{' '}
          <strong>Persona seçimi</strong> ve aylık kira aralığı
        </li>

        <li>
          <span className="lock">🔒</span>{' '}
          <strong>Düzenli gittiğin yerleri</strong> ekleme ve önem sırasına dizme
        </li>
      </ul>

      <button
        className="btn-primary"
        type="button"
        onClick={() => goAuth('/auth/register')}
      >
        Ücretsiz hesap oluştur
      </button>

      <button
        className="btn-secondary"
        type="button"
        onClick={() => goAuth('/auth/login')}
      >
        Zaten hesabım var
      </button>
    </div>
  );
}