/**
 * Vivido — web ve mobil arasında paylaşılan sözleşme.
 *
 * ┌───────────────────────────────────────────────────────────────┐
 * │  BU DOSYA YALNIZCA RE-EXPORT İÇERİR.                          │
 * │                                                               │
 * │  Tip tanımı EKLEMEYİN — ilgili modüle ekleyin. Dört kişi aynı │
 * │  anda çalışıyor; tek dosyada toplanırsa her PR'da çakışır.    │
 * └───────────────────────────────────────────────────────────────┘
 *
 * Modül sahipleri (bkz. vivido-calisma-duzeni.md):
 *
 *   common.ts    ortak temel tipler
 *   errors.ts    hata sözleşmesi — ortak
 *   auth.ts      Kişi 1
 *   persona.ts   Kişi 2
 *   profile.ts   Kişi 3   (anchor dahil)
 *   poi.ts       R-108    POI ve harita konutu sözleşmeleri
 *   property.ts  Hafta 2
 *   score.ts     Hafta 2
 *   route.ts     Hafta 3
 *   utils.ts     paylaşılan saf fonksiyonlar
 *
 * API istemcisi ELLE YAZILMAZ: `api/openapi.yaml` hazır olunca
 * `pnpm gen:api` ile `src/api/` altına üretilir.
 */

export * from './common';
export * from './errors';
export * from './auth';
export * from './persona';
export * from './profile';
export * from './location';
export * from './poi';
export * from './property';
export * from './score';
export * from './route';
export * from './utils';
export * from './favoritesAndRoutes';
