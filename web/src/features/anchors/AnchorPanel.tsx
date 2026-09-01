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
export interface AnchorPanelProps {
  /**
   * Eklenmiş yer sayısı — kart başlığındaki kapasite göstergesi için.
   * Verilmezse gösterge çizilmez (onboarding sihirbazında başlık yok).
   */
  usedCount?: number;
}

export function AnchorPanel({ usedCount }: AnchorPanelProps = {}) {
  const [pending, setPending] = useState<MapPoint | null>(null);

  // İşaretçiler için liste burada da lazım. Aynı sorgu anahtarı olduğu için
  // ek istek gitmez — `AnchorEditor` ile ortak önbellekten okunur.
  const { data: anchors = [] } = useSessionQuery({
    queryKey: ['anchors'],
    queryFn: () => api.get<Anchor[]>('/profile/anchors'),
    retry: false,
  });

  const full = anchors.length >= MAX_ANCHORS;
  const showCapacity = usedCount != null;

  return (
    <article className={showCapacity ? 'pcard anchor-panel' : 'anchor-panel'}>
      {showCapacity && (
        <header className="pcard-head">
          <span className="pcard-icon" aria-hidden="true">📍</span>
          <div className="pcard-head-text">
            <h2>Düzenli gittiğin yerler</h2>
            <p>
              En önemli yer, diğerlerinin toplamı kadar ağırlık taşır — sırayı
              değiştirmek skorları yeniden hesaplatır.
            </p>
          </div>

          {/* Kapasite göstergesi BAŞLIKTA. "1 / 3" satırı haritanın altında,
              iki paragrafın arasında duruyordu; kullanıcı kaç yer daha
              ekleyebileceğini görmek için kaydırmak zorundaydı. Noktalar
              sayıyı okumadan da anlaşılır. */}
          <span
            className="capacity"
            aria-label={`${MAX_ANCHORS} yerden ${usedCount} tanesi eklendi`}
          >
            <span className="capacity-dots" aria-hidden="true">
              {Array.from({ length: MAX_ANCHORS }, (_, index) => (
                <span
                  key={index}
                  className={`capacity-dot${index < usedCount ? ' is-filled' : ''}`}
                />
              ))}
            </span>
            <span className="capacity-text" aria-hidden="true">
              {usedCount} / {MAX_ANCHORS}
            </span>
          </span>
        </header>
      )}

      <div className={showCapacity ? 'pcard-body' : undefined}>
        {!showCapacity && (
          <>
            <h2>Düzenli gittiğin yerler</h2>
            <p className="muted">
              En fazla {MAX_ANCHORS} yer ekleyebilirsin. Önem sırasına dizdiğinde
              skorlar bu sıraya göre yeniden hesaplanır — en önemli yer,
              diğerlerinin toplamı kadar ağırlık taşır.
            </p>
          </>
        )}

        {/* Harita, üstündeki ipucuyla TEK bir yüzey: eskiden harita kutusu
            bitiyor, ipucu ayrı bir paragraf olarak altta duruyordu ve
            haritayla ilgili olduğu belli olmuyordu. */}
        <div className={`anchor-map-frame${full ? ' is-full' : ''}`}>
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

          <p className="anchor-map-hint">
            {full ? (
              <>
                <span aria-hidden="true">✓</span> {MAX_ANCHORS} yer eklendi. Yeni
                eklemek için önce birini sil.
              </>
            ) : (
              <>
                <span aria-hidden="true">👆</span> Haritaya tıklayarak yer seç.
              </>
            )}
          </p>
        </div>

        <AnchorEditor pending={pending} onPendingChange={setPending} />
      </div>
    </article>
  );
}
