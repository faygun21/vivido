import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import type { LocationSearchResult, UserProfile, Persona } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { CankayaMap, type MapFocus, type MapMarker } from '@/shared/map/CankayaMap';
import { LocationSearch } from './LocationSearch';

/**
 * Ana ekran — Çankaya haritası.
 *
 * Bu tur kapsamı: harita görünür ve gezilebilir, profil özeti yanda.
 * Skorlanmış ev listesi + filtreler Hafta 2'nin backend işleri
 * (`GET /properties`) bitince buraya eklenecek — harita bileşeni aynı kalır,
 * üzerine nokta katmanı serilir.
 */
export function ExplorePage() {
  const [mapFocus, setMapFocus] = useState<MapFocus | null>(null);
  const { data: profile } = useQuery({
    queryKey: ['profile'],
    queryFn: () => api.get<UserProfile>('/profile'),
    retry: false,
  });

  const { data: personas = [] } = useQuery({
    queryKey: ['personas'],
    queryFn: () => api.get<Persona[]>('/personas'),
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
  }

  return (
    <section className="explore">
      <aside className="explore-side">
        <h1>Keşfet</h1>

        <div className="info-card">
          <h2>Profilin</h2>
          {profile ? (
            <dl className="kv">
              <dt>Persona</dt>
              <dd>{persona?.displayNameTr ?? profile.personaCode}</dd>
              <dt>Bütçe</dt>
              <dd>
                {profile.monthlyBudget != null
                  ? `${profile.monthlyBudget.toLocaleString('tr-TR')} ₺`
                  : 'Girilmedi'}
              </dd>
              <dt>Yerlerin</dt>
              <dd>{profile.anchors.length} / 3</dd>
            </dl>
          ) : (
            <p className="muted">
              Profil bulunamadı. <Link to="/onboarding">Onboarding'i tamamla</Link>
            </p>
          )}
          <Link className="btn-secondary" to="/profile">
            Profili düzenle
          </Link>
        </div>

        <div className="info-card">
          <h2>Harita</h2>
          <p className="muted">
            Çankaya ilçe sınırı ve <strong>124 mahalle</strong> poligonu gösteriliyor.
            Mahalle üzerine gelince adı görünür.
          </p>
          <p className="muted">
            Skorlanmış kiralık ev noktaları, filtreler ve gerekçe tablosu
            Hafta 2'nin kalan işleri.
          </p>
        </div>

        <p className="data-badge">Konut verisi sentetiktir</p>
      </aside>

      <div className="explore-map">
        <CankayaMap markers={markers} focus={mapFocus} />
        <LocationSearch onSelect={focusLocation} onClear={() => setMapFocus(null)} />
      </div>
    </section>
  );
}
