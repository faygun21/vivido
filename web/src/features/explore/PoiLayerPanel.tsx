import type { PoiCategory } from '@vivido/shared';
import { poiCategoryColor } from '@/shared/map/poiColors';
import './PoiLayers.css';

interface PoiLayerPanelProps {
  categories: PoiCategory[];
  selectedCategories: string[];
  onToggleCategory: (code: string) => void;
  propertiesVisible: boolean;
  onToggleProperties: () => void;
}

/**
 * R-108 — POI katmanları ve filtreleme paneli.
 *
 * 8 kategori ayrı ayrı açılıp kapatılır (çoklu seçim); konut katmanı da
 * ayrı bir anahtar olarak burada durur. Seçim, ExplorePage'teki API
 * sorgusunu besler — harita yalnızca seçilen kategorileri çizer.
 */
export function PoiLayerPanel({
  categories,
  selectedCategories,
  onToggleCategory,
  propertiesVisible,
  onToggleProperties,
}: PoiLayerPanelProps) {
  // Ne `drawer-section` ne de kendi `h2`'si var: bu panel çekmecedeki
  // "Harita katmanları" bölümünün İÇİNDE duruyor. İkisi de olunca aynı
  // başlık iki kez yazılıyor ve iç içe iki bölüm ayracı çiziliyordu.
  return (
    <div className="poi-layer-panel">
      <label className="poi-layer-row">
        <input
          type="checkbox"
          checked={propertiesVisible}
          onChange={onToggleProperties}
        />
        <span className="poi-layer-dot" style={{ background: '#c2410c' }} />
        Konutlar
      </label>

      <div className="poi-layer-divider" />

      {categories.map((category) => {
        const checked = selectedCategories.includes(category.code);
        return (
          <label key={category.code} className="poi-layer-row">
            <input
              type="checkbox"
              checked={checked}
              onChange={() => onToggleCategory(category.code)}
            />
            <span
              className="poi-layer-dot"
              style={{ background: poiCategoryColor(category.code) }}
            />
            {category.displayNameTr}
          </label>
        );
      })}
    </div>
  );
}
