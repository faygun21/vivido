import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link, useNavigate } from 'react-router-dom';
import type { UserProfile, Persona } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';
import {
  ANALYSIS_AREA_DEFAULT_KM,
  ANALYSIS_AREA_MAX_KM,
  ANALYSIS_AREA_MIN_KM,
  AnalysisAreaPanel,
} from '@/features/analysis/AnalysisAreaPanel';
import { CankayaMap, type AnalysisArea, type MapMarker, type MapPoint } from '@/shared/map/CankayaMap';

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

  // ─── R-106: analiz alanı (buffer) durumu ───
  const [analysisArea, setAnalysisArea] = useState<AnalysisArea | null>(null);
  const [pickingCenter, setPickingCenter] = useState(false);

  function handleMapClick(point: MapPoint) {
    setAnalysisArea((prev) => ({
      center: point,
      // İlk seçimde varsayılan 2 km; merkez değiştirilirken yarıçap korunur.
      radiusKm: prev?.radiusKm ?? ANALYSIS_AREA_DEFAULT_KM,
    }));
    setPickingCenter(false);
  }

  function handleRadiusChange(radiusKm: number) {
    setAnalysisArea((prev) =>
      prev
        ? {
            ...prev,
            // Savunmacı sınır: kaydırıcı/çip dışı değerler de kırpılır.
            radiusKm: Math.min(
              ANALYSIS_AREA_MAX_KM,
              Math.max(ANALYSIS_AREA_MIN_KM, radiusKm),
            ),
          }
        : prev,
    );
  }

  const markers: MapMarker[] = (profile?.anchors ?? []).map((a) => ({
    id: a.id,
    lat: a.lat,
    lon: a.lon,
    label: a.label,
    priority: a.priority,
  }));

  return (
    <section className="explore">
      <aside className="explore-side">
        <h1>Keşfet</h1>

        {isGuest ? <GuestPanel /> : (
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
        )}

        <AnalysisAreaPanel
          area={analysisArea}
          picking={pickingCenter}
          onStartPick={() => setPickingCenter(true)}
          onCancelPick={() => setPickingCenter(false)}
          onRadiusChange={handleRadiusChange}
          onClear={() => {
            setAnalysisArea(null);
            setPickingCenter(false);
          }}
        />

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
        <CankayaMap
          markers={markers}
          onMapClick={pickingCenter ? handleMapClick : undefined}
          analysisArea={analysisArea}
        />
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
          <span className="lock">🔒</span> Kişiselleştirilmiş <strong>0–100 skor</strong> ve
          skorun gerekçe tablosu
        </li>
        <li>
          <span className="lock">🔒</span> <strong>Persona seçimi</strong> ve aylık kira bütçesi
        </li>
        <li>
          <span className="lock">🔒</span> <strong>Düzenli gittiğin yerleri</strong> ekleme ve
          önem sırasına dizme
        </li>
      </ul>

      <button className="btn-primary" type="button" onClick={() => goAuth('/auth/register')}>
        Ücretsiz hesap oluştur
      </button>
      <button className="btn-secondary" type="button" onClick={() => goAuth('/auth/login')}>
        Zaten hesabım var
      </button>
    </div>
  );
}
