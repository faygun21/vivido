import type { PoiCategory } from '@vivido/shared';
import './PoiLayers.css';

interface PoiLayerPanelProps {
  categories: PoiCategory[];
  selectedCategories: string[];
  onToggleCategory: (code: string) => void;
  propertiesVisible: boolean;
  onToggleProperties: () => void;
  /** Kullanıcının anchor'ı (özel yeri) var mı — yoksa gösterilecek bir alan da yok. */
  hasAnchorArea: boolean;
  /** Kapalıyken sadece anchor alanındaki evler, açıkken hepsi gösterilir. */
  showAllProperties: boolean;
  onToggleShowAllProperties: () => void;
  /**
   * Favori katmanı — misafir kullanıcının favorisi olamaz, o yüzden
   * satır hiç çizilmez (anchor satırındaki `hasAnchorArea` deseniyle
   * aynı: işlevi olmayan bir tik göstermek kullanıcıyı yanıltır).
   */
  canUseFavorites: boolean;
  favoritesVisible: boolean;
  onToggleFavorites: () => void;
  /** Kaç favori var — kullanıcı tiki açmadan önce ne bekleyeceğini bilsin. */
  favoriteCount: number;
}

/**
 * Kategori koduna veya görünen adına göre public klasöründeki uygun SVG dosyasının yolunu döndürür.
 */
function getCategoryIconPath(code: string, displayNameTr?: string): string {
  const lowerCode = (code || '').toLowerCase();
  const lowerName = (displayNameTr || '').toLowerCase();

  // Buradaki `console.log` KALDIRILDI: geliştirme sırasında bırakılmış bir
  // hata ayıklama satırıydı ve her render'da her kategori için tetikleniyordu
  // (8 kategori × her panel çizimi). Üretimde de çalışıyordu, konsolu
  // doldurup gerçek uyarıları görünmez yapıyordu.

  // Kafe / Restoran / Yeme-İçme varyasyonları (food, cafe, kafe vb.)
  if (
    lowerCode.includes('cafe') || 
    lowerCode.includes('kafe') || 
    lowerCode.includes('restaurant') || 
    lowerCode.includes('restoran') ||
    lowerCode.includes('coffee') ||
    lowerCode.includes('food') ||
    lowerCode.includes('dining') ||
    lowerName.includes('kafe') ||
    lowerName.includes('restoran')
  ) {
    return '/cafe.svg';
  }

  // Toplu Taşıma / Durak
  if (
    lowerCode.includes('bus') || 
    lowerCode.includes('durak') || 
    lowerCode.includes('transport') || 
    lowerCode.includes('transit') || 
    lowerCode.includes('ulasim')
  ) {
    return '/bus.svg';
  }

  // Hastane / Sağlık / ASM / Eczane varyasyonları
  if (
    lowerCode.includes('hastane') || 
    lowerCode.includes('hospital') || 
    lowerCode.includes('saglik') || 
    lowerCode.includes('health') || 
    lowerCode.includes('asm') || 
    lowerCode.includes('eczane') ||
    lowerCode.includes('pharmacy') ||
    lowerCode.includes('drugstore') ||
    lowerName.includes('eczane') ||
    lowerName.includes('hastane')
  ) {
    return '/hastane.svg';
  }

  // Park / Yeşil Alan
  if (
    lowerCode.includes('park') || 
    lowerCode.includes('yesil') || 
    lowerCode.includes('green')
  ) {
    return '/park.svg';
  }

  // Okul / Eğitim
  if (
    lowerCode.includes('school') || 
    lowerCode.includes('okul') || 
    lowerCode.includes('education') || 
    lowerCode.includes('egitim')
  ) {
    return '/kep_kahve.svg';
  }

  // Spor Salonu
  if (
    lowerCode.includes('sport') || 
    lowerCode.includes('spor') || 
    lowerCode.includes('gym')
  ) {
    return '/sport_kahve.svg';
  }

  // Market / AVM
  if (
    lowerCode.includes('market') || 
    lowerCode.includes('avm') || 
    lowerCode.includes('supermarket') || 
    lowerCode.includes('alisveris')
  ) {
    return '/avm.svg';
  }

  return '/icons.svg';
}

export function PoiLayerPanel({
  categories,
  selectedCategories,
  onToggleCategory,
  propertiesVisible,
  onToggleProperties,
  hasAnchorArea,
  showAllProperties,
  onToggleShowAllProperties,
  canUseFavorites,
  favoritesVisible,
  onToggleFavorites,
  favoriteCount,
}: PoiLayerPanelProps) {
  return (
    <div className="poi-layer-panel">
      {/* Konutlar Katmanı */}
      <label className="poi-layer-row">
        <input
          type="checkbox"
          checked={propertiesVisible}
          onChange={onToggleProperties}
        />
        <img
          src="/home_kahve.svg"
          alt="Konutlar"
          className="poi-layer-icon"
          style={{ width: '1.1rem', height: '1.1rem', objectFit: 'contain' }}
        />
        Konutlar
      </label>

      {/* Favoriler — konut katmanının hemen altında çünkü aynı şeyin
          (ev) bir alt kümesi; POI kategorilerinden ayrıldığı yer bu. */}
      {canUseFavorites && (
        <label className="poi-layer-row">
          <input
            type="checkbox"
            checked={favoritesVisible}
            onChange={onToggleFavorites}
          />
          <img
            src="/star_kahve.svg"
            alt=""
            className="poi-layer-icon"
            style={{ width: '1.1rem', height: '1.1rem', objectFit: 'contain' }}
          />
          Favorilerim
          {/* Sayı, tiki açmadan önce ne bekleyeceğini söyler: boş bir
              katmanı açıp "çalışmıyor mu?" diye düşünmesin. */}
          <span className="poi-layer-count">{favoriteCount}</span>
        </label>
      )}

      {/* Anchor (özel yer) yoksa filtrelenecek bir alan da yok — anlamsız
          bir tik göstermek yerine satır hiç çizilmiyor. */}
      {hasAnchorArea && (
        <label className="poi-layer-row">
          <input
            type="checkbox"
            checked={showAllProperties}
            onChange={onToggleShowAllProperties}
          />
          <span className="poi-layer-dot" style={{ background: '#7c3aed' }} />
          Tüm evleri göster
        </label>
      )}

      <div className="poi-layer-divider" />

      {/* POI Kategorileri */}
      {categories.map((category) => {
        const checked = selectedCategories.includes(category.code);
        return (
          <label key={category.code} className="poi-layer-row">
            <input
              type="checkbox"
              checked={checked}
              onChange={() => onToggleCategory(category.code)}
            />
            <img
              src={getCategoryIconPath(category.code, category.displayNameTr)}
              alt={category.displayNameTr}
              className="poi-layer-icon"
              style={{ width: '1.1rem', height: '1.1rem', objectFit: 'contain' }}
            />
            {category.displayNameTr}
          </label>
        );
      })}
    </div>
  );
}