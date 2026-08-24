import { useState } from 'react';
import type { Anchor } from '@vivido/shared';
import { MAX_ANCHORS } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { CankayaMap, type MapPoint } from '@/shared/map/CankayaMap';
import { AnchorEditor } from './AnchorEditor';

/**
 * Anchor paneli — gömülü haritalı sürüm (profil sayfası + onboarding 3. adım).
 *
 * Akış: haritaya tıkla → nokta seçilir → etiket + mod gir → kaydet.
 * Sıralama sürükle-bırakla değişir, bırakıldığı an sunucuya yazılır.
 *
 * Liste, form ve mutasyonlar `AnchorEditor` içinde; burada yalnızca 320px'lik
 * seçim haritası var. Explore ekranı aynı editörü kendi TAM EKRAN haritasıyla
 * besliyor — mantık tek yerde duruyor.
 *
 * ⚠️ `priority` GÖNDERİLMEZ — sunucu atar (K-G).
 *
 * Sözleşme: vivido-api-sozlesmesi.md §4 · Kabul kriteri: 00-KAPSAM.md → W4
 */
export function AnchorPanel() {
  const [pending, setPending] = useState<MapPoint | null>(null);

  // İşaretçiler için liste burada da lazım. Aynı sorgu anahtarı olduğu için
  // ek istek gitmez — `AnchorEditor` ile ortak önbellekten okunur.
  const { data: anchors = [] } = useSessionQuery({
    queryKey: ['anchors'],
    queryFn: () => api.get<Anchor[]>('/profile/anchors'),
    retry: false,
  });

  const full = anchors.length >= MAX_ANCHORS;

  return (
    <div className="anchor-panel">
      <h2>Düzenli gittiğin yerler</h2>
      <p className="muted">
        En fazla {MAX_ANCHORS} yer ekleyebilirsin. Önem sırasına dizdiğinde
        skorlar bu sıraya göre yeniden hesaplanır — en önemli yer,
        diğerlerinin toplamı kadar ağırlık taşır.
      </p>

      <div className="anchor-map">
        <CankayaMap
          height="320px"
          onMapClick={full ? undefined : setPending}
          markers={[
            ...anchors.map((a) => ({
              id: a.id,
              lat: a.lat,
              lon: a.lon,
              label: a.label,
              priority: a.priority,
            })),
            ...(pending
              ? [{ id: '__yeni', lat: pending.lat, lon: pending.lon, label: 'Yeni yer' }]
              : []),
          ]}
        />
      </div>

      <p className="muted map-hint">
        {full
          ? `${MAX_ANCHORS} yer eklendi. Yeni eklemek için önce birini sil.`
          : 'Haritaya tıklayarak yer seç.'}
      </p>

      <AnchorEditor pending={pending} onPendingChange={setPending} />
    </div>
  );
}
