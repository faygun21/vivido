import { useEffect, useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import type { Poi } from '@vivido/shared';
import { ApiError, api } from '@/shared/api/client';
import type { WalkingLocation } from '@/shared/map/walkingAccessibility';
import { rankPoisByDistance, type AreaPoi } from './areaPoi';

/**
 * Analiz alanı içindeki hizmet noktalarını kategori kategori getirir.
 *
 * ⚠️ TEK KATEGORİ, İSTEK BAŞINA. Sunucu ucu (`/pois/near`) tek kategori
 * alıyor. Sekiz kategoriyi birden çekip istemcide süzmek daha az kod
 * olurdu ama sekiz paralel istek demek — kullanıcı çoğu zaman bir ya da
 * iki kategoriye bakıyor.
 *
 * Önbelleği TanStack Query yapıyor (mobildeki `AreaPoiController`'ın elle
 * yazdığı `Map` burada gereksiz): sorgu anahtarı merkez + yarıçap +
 * kategori olduğu için kategoriler arasında ileri geri gitmek yeni istek
 * atmıyor, ama merkez ya da yarıçap değişince anahtar da değişiyor —
 * eski merkeze ait bir listeyi yeni çemberde göstermek sessiz bir yalan
 * olurdu.
 */

/**
 * Analiz pini SÜRÜKLENEBİLİR ve sürükleme sırasında her karede yeni bir
 * merkez bildiriyor. Doğrudan sorguya bağlansaydı parmak hareket ettikçe
 * saniyede onlarca istek giderdi. Merkez "durduktan" sonra çekiyoruz.
 */
const CENTRE_SETTLE_MS = 300;

export interface AreaPoiState {
  items: AreaPoi[];
  isLoading: boolean;
  errorMessage: string | null;
  retry: () => void;
}

export function useAreaPois({
  center,
  radiusM,
  categoryCode,
}: {
  /** `null` ise analiz kapalı — hiç istek atılmaz. */
  center: WalkingLocation | null;
  radiusM: number;
  /** `null` ise kullanıcı henüz kategori seçmedi. */
  categoryCode: string | null;
}): AreaPoiState {
  const settledCentre = useSettledLocation(center);
  const enabled = settledCentre !== null && categoryCode !== null;

  const query = useQuery({
    // Koordinat anahtara 5 basamakla giriyor (≈1 m): sürükleme bittikten
    // sonra kalan mikro oynamalar aynı listeyi yeniden çekmesin.
    queryKey: [
      'pois',
      'near',
      'alan',
      settledCentre?.lat.toFixed(5),
      settledCentre?.lon.toFixed(5),
      Math.round(radiusM),
      categoryCode,
    ],
    queryFn: () =>
      api.get<Poi[]>(
        `/pois/near?lat=${settledCentre!.lat}&lon=${settledCentre!.lon}`
          + `&radiusM=${Math.round(radiusM)}`
          + `&category=${encodeURIComponent(categoryCode!)}`,
      ),
    enabled,
    staleTime: 60_000,
    // `placeholderData: keepPreviousData` BİLEREK yok: kategori
    // değiştirince bir önceki kategorinin satırlarını göstermek — "Kafe"
    // yazarken market listesi — kullanıcıya yalan söyler. Yükleniyor
    // göstergesi dürüst olan.
  });

  const items = useMemo(
    () =>
      settledCentre && query.data
        ? rankPoisByDistance({ center: settledCentre, pois: query.data, radiusM })
        : [],
    [query.data, settledCentre, radiusM],
  );

  return {
    items,
    isLoading: enabled && query.isFetching,
    errorMessage: query.error ? messageFor(query.error) : null,
    retry: () => void query.refetch(),
  };
}

function messageFor(error: unknown): string {
  if (error instanceof ApiError) {
    return error.problem.detail ?? error.problem.title;
  }
  return 'Çevredeki hizmet noktaları yüklenemedi.';
}

/** Merkez `CENTRE_SETTLE_MS` boyunca değişmediyse onu döndürür. */
function useSettledLocation(location: WalkingLocation | null): WalkingLocation | null {
  const [settled, setSettled] = useState(location);

  useEffect(() => {
    // Kapatma anında bekleme yok: kullanıcı analizi kapattığında liste
    // yarım saniye daha ekranda kalmamalı.
    if (location === null) {
      setSettled(null);
      return;
    }
    const timer = setTimeout(() => setSettled(location), CENTRE_SETTLE_MS);
    return () => clearTimeout(timer);
  }, [location]);

  return settled;
}
