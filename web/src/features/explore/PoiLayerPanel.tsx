import type { PoiCategory } from '@vivido/shared';
import { poiIconPath } from '@/shared/map/poiIcons';
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
              src={poiIconPath(category.code, category.displayNameTr)}
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