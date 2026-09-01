/**
 * Persona görselleri — ikon eşlemesi.
 *
 * Bu tablo ÜÇ ayrı dosyada kopyalanmıştı: `LifestyleSelection` (sihirbaz
 * 2. adımı), `OnboardingPage` (profil düzenleme) ve ikisinin de kendi
 * yerel `PERSONA_UI_DATA`/`personas` sabitleri. Kopyalar birbirinden
 * ayrışmaya başlamıştı bile — biri `student` için `/kep.svg`, öteki
 * ayrıca alt ikon listesi taşıyordu; profil sayfasında ise persona'nın
 * hiç ikonu yoktu çünkü üçüncü bir kopya yazılmamıştı.
 *
 * Metinler (başlık, açıklama) BURADA DEĞİL: onlar `GET /personas` ile
 * veritabanından geliyor ve tek doğru kaynak orası. Burada yalnızca
 * kodun bilebileceği şey var — hangi persona hangi görsele karşılık
 * geliyor.
 */

export interface PersonaVisual {
  /** Persona'yı temsil eden ana ikon. */
  mainIcon: string;
  /** Persona'nın önemsediği kategorileri anlatan üç küçük ikon. */
  subIcons: string[];
}

const FALLBACK: PersonaVisual = {
  mainIcon: '/poi_generic_white.svg',
  subIcons: [],
};

const PERSONA_VISUALS: Record<string, PersonaVisual> = {
  student: {
    mainIcon: '/kep.svg',
    subIcons: ['/bus.svg', '/school.svg', '/cafe.svg'],
  },
  remote_worker: {
    mainIcon: '/pc.svg',
    subIcons: ['/cafe.svg', '/sport_kahve.svg', '/park.svg'],
  },
  family_kids: {
    mainIcon: '/family.svg',
    subIcons: ['/school.svg', '/avm.svg', '/park.svg'],
  },
  elderly: {
    mainIcon: '/glasses.svg',
    subIcons: ['/hastane.svg', '/avm.svg', '/park.svg'],
  },
};

/**
 * Bilinmeyen bir persona kodu için genel bir ikon döner — `undefined`
 * DEĞİL. Veritabanına yeni bir persona eklenirse arayüz kırık bir görsel
 * yerine nötr bir ikon gösterir; ekran çalışmaya devam eder.
 */
export function personaVisual(code: string | null | undefined): PersonaVisual {
  if (!code) return FALLBACK;
  return PERSONA_VISUALS[code] ?? FALLBACK;
}

/** POI kategorilerinin Türkçe adları ve ikonları — profil özetinde kullanılır. */
export const CATEGORY_VISUALS: Record<string, { label: string; icon: string }> = {
  transit: { label: 'Toplu taşıma', icon: '/bus.svg' },
  food: { label: 'Kafe & restoran', icon: '/cafe.svg' },
  market: { label: 'Market', icon: '/avm.svg' },
  gym: { label: 'Spor salonu', icon: '/sport_kahve.svg' },
  park: { label: 'Park & yeşil alan', icon: '/park.svg' },
  pharmacy: { label: 'Eczane', icon: '/hastane.svg' },
  health: { label: 'Sağlık', icon: '/hastane.svg' },
  school: { label: 'Okul', icon: '/school.svg' },
};
