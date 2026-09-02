import type { Poi, PoiCategory } from '@vivido/shared';
import { poiCategoryColor } from '@/shared/map/poiColors';
import { poiIconPathWhite } from '@/shared/map/poiIcons';
import {
  areaPoiName,
  formatAreaDistance,
  shortCategoryLabel,
  type AreaPoi,
} from './areaPoi';
import type { AreaPoiState } from './useAreaPois';
import './AreaPoiPanel.css';

/**
 * Analiz alanı içindeki hizmet noktaları (mobildeki `AreaPoiPanel`'in web
 * karşılığı).
 *
 * ⚠️ ÇEMBER BİR ŞEY ANLATMIYORDU
 *
 * Kullanıcı yürüme süresini seçiyor, haritada bir nokta işaretliyor ve
 * sarı bir daire çıkıyordu — o kadar. "Bu alanda ne var?" sorusunun
 * cevabı hiçbir yerde yoktu; kullanıcı çemberin içindeki renkli noktaları
 * tek tek dürtmek zorundaydı.
 *
 * ⚠️ ÇEKMECENİN İÇİNDE, HARİTANIN ÜSTÜNDE DEĞİL
 *
 * Önce mobildeki gibi haritanın üstünde yüzen bir panel olarak yazıldı ve
 * iki şeyi birden bozuyordu: (1) analizin ANLATTIĞI şeyin — çemberin ve
 * içindeki noktaların — üstünü kapatıyordu, (2) ayarlar (analiz mesafesi,
 * yürüme süresi) solda, cevapları haritanın ortasında kalıyordu; tek bir
 * iş iki yüzeye bölünmüştü. Artık "Analiz" sekmesinde, ayarların hemen
 * ALTINDA: kontrol, etkilediği şeyin yanında.
 *
 * Mobildeki dikey kategori şeridi burada 4'lü ızgara: şerit, geniş ve
 * kısa bir panelde mantıklıydı; 22rem'lik dar ve uzun bir sütunda ise
 * listeye ayrılan genişliği yiyor ("Atatürk Hastanesi Çukurambar Semt
 * Polikliniği" zaten üç noktaya düşüyor).
 */
interface AreaPoiPanelProps {
  /** Çemberin kaç dakikalık yürüme alanı olduğu — özette yazıyor. */
  walkingMinutes: number;
  /** Sunucudan gelen aktif POI kategorileri. */
  categories: PoiCategory[];
  selectedCategory: string | null;
  onSelectCategory: (code: string) => void;
  state: AreaPoiState;
  /** Listeden bir noktaya tıklanınca harita oraya uçuyor. */
  onPoiSelect: (poi: Poi) => void;
}

export function AreaPoiPanel({
  walkingMinutes,
  categories,
  selectedCategory,
  onSelectCategory,
  state,
  onPoiSelect,
}: AreaPoiPanelProps) {
  const { items, isLoading, errorMessage } = state;

  return (
    <section className="drawer-section area-section">
      <h2>Alandaki hizmet noktaları</h2>

      <p className="muted area-summary" aria-live="polite">
        {isLoading
          ? 'Aranıyor…'
          : errorMessage
            ? 'Yüklenemedi'
            : selectedCategory === null
              ? 'Bir kategori seç.'
              : items.length === 0
                ? `${walkingMinutes} dk yürüme alanında bu kategoriden nokta yok.`
                : `${walkingMinutes} dk yürüme alanında ${items.length} nokta.`}
      </p>

      <div className="area-grid" role="group" aria-label="Hizmet kategorisi">
        {categories.map((category) => (
          <CategoryButton
            key={category.code}
            category={category}
            selected={category.code === selectedCategory}
            onSelect={onSelectCategory}
          />
        ))}
      </div>

      <ResultList
        state={state}
        selectedCategory={selectedCategory}
        onPoiSelect={onPoiSelect}
      />
    </section>
  );
}

function CategoryButton({
  category,
  selected,
  onSelect,
}: {
  category: PoiCategory;
  selected: boolean;
  onSelect: (code: string) => void;
}) {
  const colour = poiCategoryColor(category.code);

  return (
    <button
      type="button"
      className={`area-cell${selected ? ' is-selected' : ''}`}
      aria-pressed={selected}
      // Kısaltılmış etiket ("Market / süpermarket" → "Market") ızgaraya
      // sığsın diye; tam adı hem ipucu hem erişilebilir ad olarak duruyor.
      title={category.displayNameTr}
      aria-label={category.displayNameTr}
      onClick={() => onSelect(category.code)}
      style={{ '--category-colour': colour } as React.CSSProperties}
    >
      {/* Seçili değilken işaret SOLUYOR, kaybolmuyor: hangi rengin hangi
          kategori olduğu bilgisi hep gerekli — harita da aynı renkleri
          kullanıyor. */}
      <span className="area-cell-dot" aria-hidden="true">
        <img src={poiIconPathWhite(category.code, category.displayNameTr)} alt="" />
      </span>
      <span className="area-cell-label" aria-hidden="true">
        {shortCategoryLabel(category.displayNameTr)}
      </span>
    </button>
  );
}

function ResultList({
  state,
  selectedCategory,
  onPoiSelect,
}: {
  state: AreaPoiState;
  selectedCategory: string | null;
  onPoiSelect: (poi: Poi) => void;
}) {
  const { items, isLoading, errorMessage, retry } = state;

  if (errorMessage) {
    return (
      <p className="area-empty">
        {errorMessage}
        <button type="button" className="btn-chip area-retry" onClick={retry}>
          Tekrar dene
        </button>
      </p>
    );
  }

  if (selectedCategory === null) return null;

  // Yükleniyor göstergesi yalnızca liste BOŞKEN: aynı kategoriyi tazelerken
  // dolu bir listeyi iskelete çevirmek, duran bir şeyi kıpırdatmak olurdu.
  if (isLoading && items.length === 0) {
    return (
      <p className="area-empty">
        <span className="area-spinner" aria-hidden="true" />
        Aranıyor…
      </p>
    );
  }

  // Boş durumun metni yukarıdaki özette zaten yazıyor; burada ikinci kez
  // söylemek aynı cümleyi üst üste iki kez göstermek olurdu.
  if (items.length === 0) return null;

  return (
    <ul className="area-list">
      {items.map((item) => (
        <ResultRow key={item.poi.id} item={item} onSelect={onPoiSelect} />
      ))}
    </ul>
  );
}

function ResultRow({ item, onSelect }: { item: AreaPoi; onSelect: (poi: Poi) => void }) {
  const name = areaPoiName(item.poi);

  return (
    <li>
      <button type="button" className="area-row" onClick={() => onSelect(item.poi)}>
        <span className={`area-row-name${name ? '' : ' is-unnamed'}`}>
          {name ?? 'İsimsiz nokta'}
        </span>

        {/* Mesafe ve süre alt alta, sabit genişlikli rakamla: liste
            boyunca sayılar hizalı kalıyor. */}
        <span className="area-row-metrics">
          <span className="area-row-distance">{formatAreaDistance(item.distanceM)}</span>
          <span className="area-row-minutes">~{item.walkingMinutes} dk</span>
        </span>

        <span className="area-row-chevron" aria-hidden="true">
          <svg viewBox="0 0 16 16" fill="none" width="14" height="14">
            <path
              d="M6.25 4.5 9.75 8l-3.5 3.5"
              stroke="currentColor"
              strokeWidth="1.7"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </span>
      </button>
    </li>
  );
}
