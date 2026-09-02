import { describe, expect, it } from 'vitest';
import type { Poi } from '@vivido/shared';
import { walkingRadiusMetres } from '@/shared/map/walkingAccessibility';
import {
  areaPoiName,
  formatAreaDistance,
  rankPoisByDistance,
  shortCategoryLabel,
} from './areaPoi';

/**
 * Analiz çemberinin içindeki hizmet noktaları.
 *
 * Çember eskiden yalnızca çiziliyordu; "bu alanda ne var?" sorusunun
 * cevabı web'de hiçbir yerde yoktu (mobildeki `area_poi_test.dart`'ın
 * karşılığı).
 */
const center = { lat: 39.9, lon: 32.85 };

function poi(id: number, lat: number, lon: number, name: string | null = `POI ${id}`): Poi {
  return { id, name, categoryCode: 'market', latitude: lat, longitude: lon };
}

describe('mesafeye göre sıralama', () => {
  it('merkeze yakından uzağa sıralar', () => {
    const ranked = rankPoisByDistance({
      center,
      radiusM: 5000,
      pois: [poi(3, 39.92, 32.85), poi(1, 39.901, 32.85), poi(2, 39.91, 32.85)],
    });

    expect(ranked.map((item) => item.poi.id)).toEqual([1, 2, 3]);
  });

  it('yarıçapın DIŞINDA kalanları eler', () => {
    // Sunucu yarıçapı bbox/PostGIS ile uyguluyor ve kenar durumlarda
    // birkaç metre taşan sonuçlar dönebiliyor. Listede "yürüme alanı
    // içinde" diyorsak gerçekten içinde olmalı.
    const ranked = rankPoisByDistance({
      center,
      radiusM: 400,
      pois: [poi(1, 39.9018, 32.85), poi(2, 39.93, 32.85)],
    });

    expect(ranked.map((item) => item.poi.id)).toEqual([1]);
  });

  it('yürüme süresi çemberle aynı hızı kullanıyor', () => {
    // Çember `walkingRadiusMetres` ile 80 m/dk üzerinden çiziliyor.
    // Farklı bir sabit kullanılsaydı çemberin KENARINDAKİ bir nokta
    // çemberin süresinden farklı bir süre gösterirdi.
    const radius = walkingRadiusMetres(10); // 800 m
    const ranked = rankPoisByDistance({
      center,
      radiusM: radius,
      pois: [poi(1, 39.9 + 800 / 111_320, 32.85)],
    });

    expect(ranked).toHaveLength(1);
    expect(ranked[0].walkingMinutes).toBeCloseTo(10, 0);
  });

  it('çok yakın nokta için süre 0 değil 1 dakika', () => {
    const ranked = rankPoisByDistance({
      center,
      radiusM: 800,
      pois: [poi(1, 39.90001, 32.85001)],
    });

    expect(ranked[0].walkingMinutes).toBe(1);
  });
});

describe('liste biçimi', () => {
  it('bin metreden sonra kilometreye geçer', () => {
    expect(formatAreaDistance(376.4)).toBe('376 m');
    expect(formatAreaDistance(999)).toBe('999 m');
    expect(formatAreaDistance(1240)).toBe('1,2 km');
  });

  it('adı olmayan noktayı null döner', () => {
    expect(areaPoiName(poi(1, 39.9, 32.85, null))).toBeNull();
    expect(areaPoiName(poi(2, 39.9, 32.85, '   '))).toBeNull();
    expect(areaPoiName(poi(3, 39.9, 32.85, ' OTTO Lounge '))).toBe('OTTO Lounge');
  });

  it('kategori etiketini şeride sığdırır', () => {
    expect(shortCategoryLabel('Kafe ve restoran')).toBe('Kafe');
    expect(shortCategoryLabel('Market')).toBe('Market');
    expect(shortCategoryLabel('Sağlık/Eczane')).toBe('Sağlık');
    expect(shortCategoryLabel('Toplutaşımacılık')).toBe('Toplutaş…');
  });
});
