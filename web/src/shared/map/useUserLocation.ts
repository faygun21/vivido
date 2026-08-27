import { useCallback, useEffect, useRef, useState } from 'react';

/**
 * Kullanıcının canlı konumu — haritadaki mavi nokta ve rota başlangıcı için
 * TEK kaynak.
 *
 * ⭐ NEDEN AYRI BİR KANCA
 *
 * Konum iki yerde birden lazım: haritadaki "buradasın" işaretçisi ve rota
 * oluşturucunun başlangıç noktası. İkisi ayrı ayrı `getCurrentPosition`
 * çağırsaydı tarayıcı iki kez izin sorar, iki farklı koordinat elde edilir
 * ve "haritada gördüğüm nokta ile rotamın başladığı nokta neden farklı?"
 * sorusu doğardı.
 *
 * ⭐ DÜZELTİLEN HATA — konum hiç görünmüyordu
 *
 * Önceki kod `CankayaMap` içinde şöyleydi:
 *
 *     useEffect(() => {
 *       navigator.geolocation.getCurrentPosition((pos) => {
 *         const map = mapRef.current;
 *         if (!map) return;          // ← sessizce vazgeçiyordu
 *         …
 *       });
 *     }, []);                        // ← yalnızca mount'ta, bir kez
 *
 * Harita ASENKRON kuruluyor (iki GeoJSON `fetch`'i bekleniyor), dolayısıyla
 * mount anında `mapRef.current` hâlâ `null`. İzin daha önce verilmişse
 * tarayıcı hiç sormaz ve geri çağrı ANINDA döner — harita henüz hazır
 * değildir, `if (!map) return` devreye girer ve işaretçi bir daha
 * DENENMEDEN düşer. Kullanıcı ne izin penceresi görür ne de konumunu:
 * bildirilen belirti tam olarak buydu.
 *
 * Buradaki çözüm sorumluluğu ayırmak: bu kanca yalnızca koordinatı üretir
 * ve durumu saklar; haritaya çizme işi `status`'u bekleyen ayrı bir efektin
 * işi. Konum önce gelirse state'te durur, harita hazır olunca çizilir.
 */

export type UserLocationStatus =
  /** Henüz istenmedi. */
  | 'idle'
  /** İzin/konum bekleniyor. */
  | 'locating'
  /** Koordinat elinde. */
  | 'ready'
  /** Kullanıcı reddetti ya da tarayıcı engelledi. */
  | 'denied'
  /** Cihaz konum veremedi (sinyal yok, zaman aşımı). */
  | 'unavailable'
  /** Tarayıcı Geolocation API'sini hiç sunmuyor. */
  | 'unsupported'
  /** HTTP üzerinden açılmış — tarayıcılar güvensiz kaynakta konumu kapatır. */
  | 'insecure';

export interface UserLocation {
  lat: number;
  lon: number;
  /** Yatay doğruluk (metre). Tarayıcı vermezse null. */
  accuracyM: number | null;
}

export interface UseUserLocationResult {
  status: UserLocationStatus;
  location: UserLocation | null;
  /** Kullanıcıya gösterilecek Türkçe açıklama; sorun yoksa null. */
  message: string | null;
  /** Yeniden dene. Reddedilmiş izni KOD ile geri açamayız — bkz. `message`. */
  request: () => void;
}

const OPTIONS: PositionOptions = {
  // Rota başlangıcı için sokak hassasiyeti yeterli; yüksek hassasiyet
  // telefonda GPS'i uyandırıp ilk sonucu onlarca saniye geciktirebiliyor.
  enableHighAccuracy: false,
  // Varsayılan sonsuz: izin diyaloğu kapatılmadan bırakılırsa arayüz
  // "Konum alınıyor…" durumunda sonsuza kadar asılı kalırdı.
  timeout: 12_000,
  // 5 dakikalık taze bir okuma varsa yeniden ölçme.
  maximumAge: 5 * 60_000,
};

function describe(status: UserLocationStatus): string | null {
  switch (status) {
    case 'denied':
      return 'Konum izni verilmedi. Tarayıcının adres çubuğundaki kilit simgesinden Konum iznini açıp tekrar deneyebilirsin.';
    case 'unavailable':
      return 'Konumun şu anda alınamadı. Sinyal zayıf olabilir; tekrar dene ya da başlangıç adresini yaz.';
    case 'unsupported':
      return 'Tarayıcın konum servisini desteklemiyor. Başlangıç adresini yazarak devam edebilirsin.';
    case 'insecure':
      return 'Konum yalnızca güvenli bağlantıda (HTTPS) çalışır. Başlangıç adresini yazarak devam edebilirsin.';
    default:
      return null;
  }
}

export function useUserLocation(): UseUserLocationResult {
  const [status, setStatus] = useState<UserLocationStatus>('idle');
  const [location, setLocation] = useState<UserLocation | null>(null);
  // Aynı anda iki istek uçmasın: kullanıcı "tekrar dene"ye üst üste basarsa
  // tarayıcı sıraya alır ve durum yanıp söner.
  const inFlightRef = useRef(false);

  const request = useCallback(() => {
    if (inFlightRef.current) return;

    // `isSecureContext` false iken Chrome/Firefox geolocation'ı sessizce
    // reddediyor. Bunu ÖNCEDEN yakalamak, kullanıcıya "izin vermedin"
    // demek yerine gerçek sebebi söylememizi sağlıyor.
    if (typeof window !== 'undefined' && window.isSecureContext === false) {
      setStatus('insecure');
      return;
    }

    if (typeof navigator === 'undefined' || !navigator.geolocation) {
      setStatus('unsupported');
      return;
    }

    inFlightRef.current = true;
    setStatus('locating');

    navigator.geolocation.getCurrentPosition(
      (position) => {
        inFlightRef.current = false;
        setLocation({
          lat: position.coords.latitude,
          lon: position.coords.longitude,
          accuracyM: Number.isFinite(position.coords.accuracy)
            ? position.coords.accuracy
            : null,
        });
        setStatus('ready');
      },
      (error) => {
        inFlightRef.current = false;
        setStatus(error.code === error.PERMISSION_DENIED ? 'denied' : 'unavailable');
      },
      OPTIONS,
    );
  }, []);

  // Açılışta bir kez sor — haritadaki mavi noktanın kullanıcı hiçbir şeye
  // basmadan görünmesi için. İzin daha önce verilmişse pencere çıkmaz.
  useEffect(() => {
    request();
  }, [request]);

  return { status, location, message: describe(status), request };
}
