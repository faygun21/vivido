/**
 * POI kategorisi → ikon dosyası.
 *
 * ⚠️ AYNI ZİNCİR ÜÇ YERDEYDİ. Kategori kodunu/adını tarayan bu koşul
 * dizisi hem `PoiLayerPanel` (renkli ikonlar) hem `CankayaMap` (beyaz
 * ikonlar) içinde ayrı ayrı yazılıydı; alan içi hizmet noktaları paneli
 * (`AreaPoiPanel`) üçüncü kopyayı gerektirecekti. Artık kod bir KEZ
 * sınıflandırılıyor, dosya adı istenen varyanta göre seçiliyor.
 *
 * İki varyantın ayrımı bilinçli:
 *   • `poiIconPath`      — açık zemin üstünde çıplak duran ikon (sol menü)
 *   • `poiIconPathWhite` — kategori renginde DOLU bir dairenin üstüne
 *     binen ikon (harita işaretçisi, panel şeridi). İkonu da renkli
 *     yapmak daireyle ikonu birbirine karıştırırdı.
 */

type PoiIconKind =
  | 'cafe'
  | 'bus'
  | 'health'
  | 'park'
  | 'school'
  | 'sport'
  | 'market'
  | 'generic';

const ICON_FILES: Record<PoiIconKind, { colour: string; white: string }> = {
  cafe: { colour: '/cafe.svg', white: '/cafe_white.svg' },
  bus: { colour: '/bus.svg', white: '/bus_white.svg' },
  health: { colour: '/hastane.svg', white: '/hastane_white.svg' },
  park: { colour: '/park.svg', white: '/park_white.svg' },
  school: { colour: '/kep_kahve.svg', white: '/kep_kahve_white.svg' },
  sport: { colour: '/sport_kahve.svg', white: '/sport_kahve_white.svg' },
  market: { colour: '/avm.svg', white: '/avm_white.svg' },
  // Bilinen sekiz kategorinin dışında bir kod gelirse (ör. sunucuya yeni
  // bir kategori eklenip burası unutulursa) buraya düşülür — fiilen
  // erişilemez ama sessiz bir savunma hattı.
  //
  // ⚠️ Renkli varyantın karşılığı `/icons.svg`: Vite şablonundan kalma,
  // POI'yle ilgisi olmayan bir sprite. Nötr, RENKLİ bir genel ikon
  // varlığı repoda yok; buraya uydurma bir yol yazmak yerine mevcut
  // davranış korundu (beyaz varyantın gerçek bir karşılığı var).
  generic: { colour: '/icons.svg', white: '/poi_generic_white.svg' },
};

/** Harita motoruna önceden kaydedilmesi gereken beyaz ikonların tamamı. */
export const POI_WHITE_ICON_PATHS = Object.values(ICON_FILES).map(
  (files) => files.white,
);

function classify(code: string, displayNameTr?: string): PoiIconKind {
  const lowerCode = (code || '').toLowerCase();
  const lowerName = (displayNameTr || '').toLowerCase();
  const has = (...needles: string[]) =>
    needles.some((needle) => lowerCode.includes(needle));
  const named = (...needles: string[]) =>
    needles.some((needle) => lowerName.includes(needle));

  if (
    has('cafe', 'kafe', 'restaurant', 'restoran', 'coffee', 'food', 'dining')
    || named('kafe', 'restoran')
  ) {
    return 'cafe';
  }
  if (has('bus', 'durak', 'transport', 'transit', 'ulasim')) return 'bus';
  if (
    has(
      'hastane', 'hospital', 'saglik', 'health', 'asm',
      'eczane', 'pharmacy', 'drugstore',
    )
    || named('eczane', 'hastane')
  ) {
    return 'health';
  }
  if (has('park', 'yesil', 'green')) return 'park';
  if (has('school', 'okul', 'education', 'egitim')) return 'school';
  if (has('sport', 'spor', 'gym')) return 'sport';
  if (has('market', 'avm', 'supermarket', 'alisveris')) return 'market';
  return 'generic';
}

/** Açık zemin üstünde tek başına duran, renkli ikon. */
export function poiIconPath(code: string, displayNameTr?: string): string {
  return ICON_FILES[classify(code, displayNameTr)].colour;
}

/** Kategori renginde dolu bir dairenin üstüne binen beyaz ikon. */
export function poiIconPathWhite(code: string, displayNameTr?: string): string {
  return ICON_FILES[classify(code, displayNameTr)].white;
}
