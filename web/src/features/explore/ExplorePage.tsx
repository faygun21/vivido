import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link, useNavigate } from 'react-router-dom';
import type { LocationSearchResult, UserProfile, Persona } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';
import { CankayaMap, type MapFocus, type MapMarker } from '@/shared/map/CankayaMap';
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
  const [selectedLocation, setSelectedLocation] = useState<WalkingLocation | null>(null);
  const [walkingMinutes, setWalkingMinutes] = useState<WalkingMinutes>(DEFAULT_WALKING_MINUTES);
  const [analysisRadiusKm, setAnalysisRadiusKm] = useState<AnalysisRadiusKm>(
    DEFAULT_ANALYSIS_RADIUS_KM,
  );
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
    setSelectedLocation({ lat: location.latitude, lon: location.longitude });
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
            Skorlanmış kiralık ev noktaları, filtreler ve gerekçe tablosu
            Hafta 2&apos;nin kalan işleri.
          </p>
        </div>

        <div className="info-card walking-access-card">
          <h2>Konum analizi</h2>
          <p className="muted">
            Haritada bir konum seç veya konum araması yap. Analiz çevresini ve
            yaklaşık yürüme erişimini birlikte gösterelim.
          </p>
          <label htmlFor="analysis-radius">Analiz mesafesi</label>
          <select
            id="analysis-radius"
            value={analysisRadiusKm}
            onChange={(event) => {
              const value = Number(event.target.value);
              if (isAnalysisRadiusKm(value)) setAnalysisRadiusKm(value);
            }}
          >
            {ANALYSIS_RADIUS_OPTIONS_KM.map((radiusKm) => (
              <option key={radiusKm} value={radiusKm}>{radiusKm} km</option>
            ))}
          </select>
          <p className="analysis-area-hint">
            <span className="area-key area-key--analysis" />
            {analysisRadiusKm} km analiz alanı
          </p>
          <label htmlFor="walking-minutes">Yürüme süresi</label>
          <select
            id="walking-minutes"
            value={walkingMinutes}
            onChange={(event) => {
              const value = Number(event.target.value);
              if (isWalkingMinutes(value)) setWalkingMinutes(value);
            }}
          >
            {WALKING_MINUTE_OPTIONS.map((minutes) => (
              <option key={minutes} value={minutes}>{minutes} dakika</option>
            ))}
          </select>
          <p className="analysis-area-hint">
            <span className="area-key area-key--walking" />
            {walkingMinutes} dakika yürüme alanı
          </p>
          <p className="walking-access-status" aria-live="polite">
            {selectedLocation
              ? walkingMinutes >= 15
                ? 'Arabayla gitmeniz tavsiye edilir.'
                : `${walkingMinutes} dakikalık yürüme alanı gösteriliyor.`
              : 'Alanı görmek için haritaya tıkla.'}
          </p>
          {selectedLocation && (
            <button className="btn-secondary" type="button" onClick={() => setSelectedLocation(null)}>
              Seçimi temizle
            </button>
          )}
        </div>

        <p className="data-badge">Konut verisi sentetiktir</p>
      </aside>

      <div className="explore-map">
        <CankayaMap
          markers={markers}
          focus={mapFocus}
          onMapClick={setSelectedLocation}
          selectedLocation={selectedLocation}
          walkingMinutes={walkingMinutes}
          analysisRadiusKm={analysisRadiusKm}
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
