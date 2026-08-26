import { describe, expect, it } from 'vitest';
import {
  CANKAYA_BOUNDS,
  isWithinCankaya,
  startFromAddress,
  startFromLiveLocation,
} from './routeStart';

describe('isWithinCankaya', () => {
  it('Çankaya merkezindeki bir noktayı içeride sayar', () => {
    // Kızılay — ilçenin göbeği.
    expect(isWithinCankaya({ lat: 39.9208, lon: 32.8541 })).toBe(true);
  });

  it('başka bir şehri dışarıda sayar', () => {
    // İstanbul (Taksim). Rota ağı yalnızca Çankaya kesitinden üretildiği için
    // buradan başlayan bir rota, en yakın Çankaya yoluna yapışır ve mesafe
    // anlamsız büyür — kullanıcıya adres seçtirmemizin sebebi bu.
    expect(isWithinCankaya({ lat: 41.0369, lon: 28.985 })).toBe(false);
  });

  it('aynı enlemde ama çok batıdaki bir noktayı dışarıda sayar', () => {
    // Yalnızca enlemi kontrol eden bir hata bunu içeride sayardı.
    expect(isWithinCankaya({ lat: 39.92, lon: 30.0 })).toBe(false);
  });

  it('aynı boylamda ama çok kuzeydeki bir noktayı dışarıda sayar', () => {
    // Yalnızca boylamı kontrol eden bir hata bunu içeride sayardı.
    expect(isWithinCankaya({ lat: 41.5, lon: 32.85 })).toBe(false);
  });

  it('sınırın tam üstündeki noktayı içeride sayar', () => {
    expect(
      isWithinCankaya({ lat: CANKAYA_BOUNDS.north, lon: CANKAYA_BOUNDS.east }),
    ).toBe(true);
  });

  it('sınırın hemen dışını dışarıda sayar', () => {
    expect(
      isWithinCankaya({ lat: CANKAYA_BOUNDS.north + 0.001, lon: CANKAYA_BOUNDS.east }),
    ).toBe(false);
  });
});

describe('başlangıç kaynakları', () => {
  it('canlı konumu `live` kaynağıyla etiketler', () => {
    const start = startFromLiveLocation({ lat: 39.9, lon: 32.86, accuracyM: 20 });

    expect(start).toEqual({
      lat: 39.9,
      lon: 32.86,
      label: 'Mevcut konumum',
      source: 'live',
    });
  });

  it('adres sonucunu `address` kaynağıyla ve kendi etiketiyle taşır', () => {
    // Etiket kullanıcıya AYNEN gösteriliyor: rota nereden başlıyor sorusunun
    // cevabı panelde okunabilir olmalı.
    const start = startFromAddress({
      id: 'n-42',
      label: 'Kurtuluş, Çankaya',
      kind: 'neighborhood',
      latitude: 39.93,
      longitude: 32.87,
      bounds: null,
      neighborhood: 'Kurtuluş',
      source: 'local',
    });

    expect(start.source).toBe('address');
    expect(start.label).toBe('Kurtuluş, Çankaya');
    expect(start.lat).toBe(39.93);
    expect(start.lon).toBe(32.87);
  });
});
