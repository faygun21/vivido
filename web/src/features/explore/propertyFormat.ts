import type { PropertyAddress, ScoreBand } from '@vivido/shared';

/**
 * Konut kartlarının paylaştığı biçimlendirme yardımcıları.
 *
 * Ayrı dosyada çünkü hem detay paneli hem "en uygun evler" listesi hem de
 * profildeki favori kartları aynı biçimi kullanıyor — üç yerde kopyalanırsa
 * biri güncellendiğinde aynı ev iki farklı yerde farklı görünür.
 */

/** `23750` → `23.750 ₺` */
export function formatRent(monthlyRent: number): string {
  return `${monthlyRent.toLocaleString('tr-TR', { maximumFractionDigits: 0 })} ₺`;
}

/** Dakika değerini okunur hâle getirir: `4.9` → `4,9 dk` */
export function formatMinutes(minutes: number): string {
  return `${minutes.toLocaleString('tr-TR', { maximumFractionDigits: 1 })} dk`;
}

/**
 * Adresi iki satıra böler: sokak üstte, mahalle/ilçe altta.
 *
 * `formatted` alanı sunucudan tek satır olarak geliyor ama kartta sokak adı
 * başlık gibi öne çıkmalı. Sokak yoksa (streets yüklenmemiş ya da yakında
 * adlı sokak yok) mahalle üst satıra terfi eder — kart boş görünmesin.
 */
export function splitAddress(address: PropertyAddress): { primary: string; secondary: string } {
  const region = `${address.districtName} / ${address.cityName}`;

  if (address.streetName) {
    return {
      primary: address.streetName,
      secondary: [address.neighborhoodName, region].filter(Boolean).join(', '),
    };
  }

  if (address.neighborhoodName) {
    return { primary: address.neighborhoodName, secondary: region };
  }

  return { primary: region, secondary: '' };
}

/** Bant → kullanıcıya gösterilecek Türkçe etiket. */
export const BAND_LABEL: Record<ScoreBand, string> = {
  excellent: 'Çok uygun',
  good: 'Uygun',
  fair: 'Orta',
  poor: 'Zayıf',
};
