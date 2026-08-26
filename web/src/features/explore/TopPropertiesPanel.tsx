import type { PropertySummary } from '@vivido/shared';
import { BAND_LABEL, formatRent, splitAddress } from './propertyFormat';
import { useFavoriteMutation } from './useFavorite';

/**
 * "En uygun evler" — sağdan açılan sıralı liste paneli.
 *
 * ⭐ TASARIM
 * Soldaki ☰ çekmecesinin simetriği: haritanın ÜSTÜNDE yüzer, yana itmez,
 * böylece panel açıkken de harita tam genişlikte kalır. Farkı tetikleyicisi:
 * soldaki ikonken buradaki ADI YAZAN bir düğme — "En uygun evler". İkinci
 * bir hamburger ikonu iki paneli birbirinden ayırt edilemez kılardı;
 * kullanıcı hangisinin ne açtığını tıklamadan bilemezdi.
 *
 * Kartlar tıklanabilir: bir karta basmak haritayı o eve uçurur ve detay
 * panelini açar — liste ile harita aynı seçimi paylaşır.
 */
interface TopPropertiesPanelProps {
  open: boolean;
  items: PropertySummary[];
  isLoading: boolean;
  selectedId: string | null;
  onSelect: (property: PropertySummary) => void;
  onClose: () => void;
}

export function TopPropertiesPanel({
  open,
  items,
  isLoading,
  selectedId,
  onSelect,
  onClose,
}: TopPropertiesPanelProps) {
  return (
    <aside
      id="top-properties-panel"
      className="top-panel"
      aria-hidden={!open}
      // `inert` odak sırasını da kapatır: kapalı panelde Tab ile görünmeyen
      // kartlara gitmek erişilebilirlik hatasıdır (soldaki çekmecede de aynı).
      inert={!open}
      aria-label="En uygun evler"
    >
      <header className="top-panel-head">
        <div>
          <h2>En uygun evler</h2>
          <p className="muted">
            {isLoading
              ? 'Hesaplanıyor…'
              : `Profiline göre en yüksek skorlu ${items.length} konut`}
          </p>
        </div>
        <button className="btn-icon" type="button" onClick={onClose} aria-label="Paneli kapat">
          ✕
        </button>
      </header>

      <div className="top-panel-body">
        {isLoading && <p className="muted top-panel-note">Konutlar skorlanıyor…</p>}

        {!isLoading && items.length === 0 && (
          <p className="muted top-panel-note">
            Bütçe aralığına uyan konut bulunamadı. Profilinden kira aralığını genişletmeyi dene.
          </p>
        )}

        <ol className="top-list">
          {items.map((property, index) => (
            <TopPropertyCard
              key={property.id}
              property={property}
              rank={index + 1}
              selected={property.id === selectedId}
              onSelect={onSelect}
            />
          ))}
        </ol>

        {items.length > 0 && <p className="data-badge top-panel-badge">Konut verisi sentetiktir</p>}
      </div>
    </aside>
  );
}

interface TopPropertyCardProps {
  property: PropertySummary;
  rank: number;
  selected: boolean;
  onSelect: (property: PropertySummary) => void;
}

function TopPropertyCard({ property, rank, selected, onSelect }: TopPropertyCardProps) {
  const favorite = useFavoriteMutation();
  const address = splitAddress(property.address);

  return (
    <li className={`top-card${selected ? ' is-selected' : ''}`}>
      {/* Kartın TAMAMI değil, içindeki düğme tıklanabilir: kalp düğmesi
          kartın içinde duruyor ve iç içe iki tıklanabilir öge (button
          içinde button) geçersiz HTML'dir. */}
      <button className="top-card-main" type="button" onClick={() => onSelect(property)}>
        <span className="top-card-rank">{rank}</span>

        <span className="top-card-body">
          <span className="top-card-title">
            {property.roomCount} · {property.areaM2} m²
          </span>
          <span className="top-card-address">{address.primary}</span>
          <span className="muted top-card-region">{address.secondary}</span>

          <span className="top-card-meta">
            <strong>{formatRent(property.monthlyRent)}</strong>
            <span className="muted">/ ay</span>
          </span>

          {property.topStrength && (
            <span className="top-card-reason top-card-reason--good">✓ {property.topStrength}</span>
          )}
          {property.topWeakness && (
            <span className="top-card-reason top-card-reason--bad">✗ {property.topWeakness}</span>
          )}
        </span>

        <span className={`top-card-score score-badge--${property.band}`}>
          <strong>{property.totalScore.toFixed(1)}</strong>
          <span>{BAND_LABEL[property.band]}</span>
        </span>
      </button>

      <button
        className={`top-card-fav${property.isFavorite ? ' is-active' : ''}`}
        type="button"
        onClick={() => favorite.mutate({ propertyId: property.id, isFavorite: property.isFavorite })}
        disabled={favorite.isPending}
        aria-pressed={property.isFavorite}
        aria-label={property.isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle'}
      >
        {property.isFavorite ? '♥' : '♡'}
      </button>
    </li>
  );
}
