import { describe, expect, it } from 'vitest';
import {
  formatRouteDistance,
  formatRouteDuration,
  routeNameForToday,
  travelModeLabel,
} from './routeFormat';

describe('formatRouteDistance', () => {
  it('kısa mesafeleri metre olarak gösterir', () => {
    expect(formatRouteDistance(0)).toBe('0 m');
    expect(formatRouteDistance(850)).toBe('850 m');
  });

  it('uzun mesafeleri tr-TR ondalıkla km gösterir', () => {
    expect(formatRouteDistance(1_000)).toBe('1 km');
    expect(formatRouteDistance(12_300)).toBe('12,3 km');
    expect(formatRouteDistance(145_670)).toBe('145,7 km');
  });
});

describe('formatRouteDuration', () => {
  it('dakikayı düz gösterir', () => {
    expect(formatRouteDuration(0)).toBe('0 dk');
    expect(formatRouteDuration(1_500)).toBe('25 dk'); // 25 dakika
    expect(formatRouteDuration(3_570)).toBe('1 sa'); // 59.5 → 60 dk → 1 sa
  });

  it('saat + dakika gösterir', () => {
    expect(formatRouteDuration(4_320)).toBe('1 sa 12 dk'); // 72 dk
    expect(formatRouteDuration(7_200)).toBe('2 sa'); // 120 dk
  });

  it('negatif süreyi 0 dk olarak yumuşatır', () => {
    expect(formatRouteDuration(-10)).toBe('0 dk');
  });
});

describe('routeNameForToday', () => {
  it('tr-TR kısa tarihle ad üretir', () => {
    expect(routeNameForToday(new Date(2026, 7, 25))).toBe('Ziyaret rotası · 25 Ağu');
  });
});

describe('travelModeLabel', () => {
  it('mod etiketini Türkçe döndürür', () => {
    expect(travelModeLabel('car')).toBe('Araç');
    expect(travelModeLabel('foot')).toBe('Yürüyerek');
  });
});
