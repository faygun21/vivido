import { useState } from 'react';
import type { Anchor, LocationSearchResult } from '@vivido/shared';
import { MAX_ANCHORS } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { CankayaMap, type MapFocus, type MapPoint } from '@/shared/map/CankayaMap';
import { LocationSearch } from '@/shared/location/LocationSearch';
import { AnchorEditor } from './AnchorEditor';

/**
 * Anchor paneli — gömülü haritalı sürüm (profil sayfası + onboarding 3. adım).
 *
 * Akış: haritaya tıkla **ya da adres ara** → nokta seçilir → etiket + mod
 * gir → kaydet. Sıralama sürükle-bırakla değişir, bırakıldığı an sunucuya
 * yazılır.
 *
 * Adres arama explore ekranındakiyle AYNI bileşen (`@/shared/location`) —
 * "üniversitenin adını biliyorum ama haritada nerede olduğunu bilmiyorum"
 * durumunda 320px'lik haritada elle nokta bulmak neredeyse imkânsızdı.
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
  // Aramadan gelen nokta: `focus` haritayı oraya uçurur, `searchLabel`
  // etiket alanını hazır doldurur. İkisi de haritaya tıklanınca temizlenir.
  const [focus, setFocus] = useState<MapFocus | null>(null);
  const [searchLabel, setSearchLabel] = useState<string | null>(null);
  // Arama kutusunun iç durumunu (sorgu + açık sonuç listesi) dışarıdan
  // sıfırlamanın React'teki yolu yeniden bağlamak: sayaç artınca `key`
  // değişir. Kaydettikten sonra sonuç listesi haritanın üstünde açık
  // kalırsa yeni eklenen pini örter.
  const [searchKey, setSearchKey] = useState(0);

  // İşaretçiler için liste burada da lazım. Aynı sorgu anahtarı olduğu için
  // ek istek gitmez — `AnchorEditor` ile ortak önbellekten okunur.
  const { data: anchors = [] } = useSessionQuery({
    queryKey: ['anchors'],
    queryFn: () => api.get<Anchor[]>('/profile/anchors'),
    retry: false,
  });

  const full = anchors.length >= MAX_ANCHORS;
  const showCapacity = usedCount != null;

  /** Haritaya tıklayarak seçim — aramadan kalan uçuş hedefi/etiket düşer. */
  function pickFromMap(point: MapPoint) {
    setPending(point);
    setFocus(null);
    setSearchLabel(null);
  }

  function pickFromSearch(result: LocationSearchResult) {
    if (full) return;
    setPending({ lat: result.latitude, lon: result.longitude });
    // `result.bounds` BİLEREK gönderilmiyor: explore'da amaç bir mahalleyi
    // çerçevelemek, burada ise tek bir noktayı işaretlemek. Sınırlara
    // oturtmak kullanıcıyı, pini elle düzeltemeyeceği kadar uzağa alırdı.
    setFocus({ id: result.id, label: result.label, lat: result.latitude, lon: result.longitude });
    setSearchLabel(shortLabel(result.label));
  }

  /**
   * Kaydet/vazgeç sonrası `AnchorEditor` burayı `null` ile çağırır — arama
   * durumu da onunla birlikte sıfırlanmalı, yoksa kaydedilen anchor'ın
   * numaralı pininin yanında aramanın ⌖ pini asılı kalır.
   */
  function changePending(point: MapPoint | null) {
    setPending(point);
    if (point === null) {
      setFocus(null);
      setSearchLabel(null);
      setSearchKey((key) => key + 1);
    }
  }

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
          {/* Kapasite doluyken arama da kapalı: bulunan yer bir noktaya
              dönüşemeyeceği için sonuç listesi boşuna umut verirdi
              (haritaya tıklama da aynı sebeple kapalı). */}
          {!full && (
            <LocationSearch
              key={searchKey}
              variant="inline"
              placeholder="Adres veya yer ara (ör. Hacettepe Beytepe)"
              onSelect={pickFromSearch}
              onClear={() => setFocus(null)}
            />
          )}

          <div className="anchor-map">
            <CankayaMap
              height="320px"
              onMapClick={full ? undefined : pickFromMap}
              focus={focus}
              markers={[
                ...anchors.map((a) => ({
                  id: a.id,
                  lat: a.lat,
                  lon: a.lon,
                  label: a.label,
                  priority: a.priority,
                })),
                // Aramadan gelen nokta zaten `focus`un ⌖ piniyle işaretli;
                // ikinci bir "Yeni yer" pinini aynı koordinata bindirmek
                // üst üste iki işaretçi demek olurdu.
                ...(pending && !focus
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
                <span aria-hidden="true">👆</span> Yukarıdan adres ara ya da
                haritaya tıklayarak yer seç.
              </>
            )}
          </p>
        </div>

        <AnchorEditor
          pending={pending}
          onPendingChange={changePending}
          suggestedLabel={searchLabel}
        />
      </div>
    </article>
  );
}

/**
 * Arama sonucu etiketini anchor etiketine indirger.
 *
 * Sunucu etiketi virgülle birleştirilmiş tam adres döndürüyor (bkz.
 * `PhotonGeocodingProvider.BuildLabel`): "Hacettepe Üniversitesi, Beytepe,
 * Çankaya, Ankara, Türkiye". Anchor listesinde tek satırda görünen bir
 * etiket için ilk parça yeterli — kullanıcı zaten üstüne yazabiliyor.
 *
 * Dışa AÇILMIYOR: bileşen dosyasından bileşen olmayan bir şey dışa
 * aktarılınca Vite'ın fast-refresh'i bu dosya için devre dışı kalıyor
 * (aynı not `AnchorEditor`da da var).
 */
function shortLabel(label: string): string {
  const first = label.split(',')[0]?.trim() ?? '';
  return first || label.trim();
}
