import { describe, expect, it } from 'vitest';
import { circleAround } from '@vivido/shared';

/**
 * circleAround — R-106 buffer geometrisi testleri.
 *
 * Çember halkası [lon, lat] olarak döner; GeoJSON `Polygon.coordinates[0]`'a
 * olduğu gibi verilebilmesi için KAPALIDIR (ilk nokta = son nokta).
 */

const MERKEZ = { lat: 39.87, lon: 32.85 };

const EARTH_RADIUS_KM = 6371;

function haversineKm(
  a: { lat: number; lon: number },
  b: { lat: number; lon: number },
): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(h));
}

describe('circleAround', () => {
  it('varsayılan 64 nokta + kapanış noktası üretir', () => {
    const halka = circleAround(MERKEZ, 2);
    expect(halka).toHaveLength(65);
    expect(halka[0]).toEqual(halka[64]);
  });

  it('halkadaki tüm noktalar merkeze ~yarıçap kadar uzaklıktadır', () => {
    const halka = circleAround(MERKEZ, 2);
    for (const [lon, lat] of halka.slice(0, -1)) {
      expect(haversineKm(MERKEZ, { lat, lon })).toBeCloseTo(2, 0);
    }
  });

  it('yarıçap büyüdükçe çember gerçekten büyür', () => {
    const kucuk = circleAround(MERKEZ, 1);
    const buyuk = circleAround(MERKEZ, 2);
    // Doğu-batı açıklığı yarıçapla orantılı olmalı.
    const doguBati = (halka: [number, number][]) => {
      const lonlar = halka.map(([lon]) => lon);
      return Math.max(...lonlar) - Math.min(...lonlar);
    };
    expect(doguBati(buyuk)).toBeCloseTo(doguBati(kucuk) * 2, 1);
  });
});
