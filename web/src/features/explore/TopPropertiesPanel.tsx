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
  /**
   * Liste boşken NEDEN boş olduğu — ikisi çok farklı düzeltmeler ister:
   *   · 'budget'      → bütçeye uyan hiç ev yok, kira aralığını genişletmeli.
   *   · 'anchor-area' → bütçeye uyan evler VAR ama hiçbiri özel yerlerin
   *                      çevresindeki alana düşmüyor — "Tüm evleri göster"i
   *                      açmalı ya da özel yerlerini gözden geçirmeli.
   *   · null          → liste zaten dolu.
   */
  emptyReason: 'budget' | 'anchor-area' | null;
  onShowAllProperties: () => void;
  /** Anchor alanında hiç ev yoksa sunucunun önerdiği "alana en yakın" ev. */
  nearestFallback: PropertySummary | null;
  onSelectFallback: (property: PropertySummary) => void;
}

export function TopPropertiesPanel({
  open,
  items,
  isLoading,
  selectedId,
  onSelect,
  onClose,
  emptyReason,
  onShowAllProperties,
  nearestFallback,
  onSelectFallback,
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

        {!isLoading && emptyReason === 'budget' && (
          <p className="muted top-panel-note">
            Bütçe aralığına uyan konut bulunamadı. Profilinden kira aralığını genişletmeyi dene.
          </p>
        )}

        {!isLoading && emptyReason === 'anchor-area' && (
          <>
            <p className="muted top-panel-note">
              Bütçene uyan konutlar var ama hiçbiri özel yerlerinin çevresindeki
              alana düşmüyor.{' '}
              <button type="button" className="top-panel-note-action" onClick={onShowAllProperties}>
                Tüm evleri göster
              </button>{' '}
              ile bakabilir ya da özel yerlerini gözden geçirebilirsin.
            </p>

            {nearestFallback && (
              <>
                <p className="muted top-panel-note top-panel-note--fallback-label">
                  Alanına en yakın uygun ev:
                </p>
                <ol className="top-list">
                  <TopPropertyCard
                    property={nearestFallback}
                    rank="≈"
                    selected={nearestFallback.id === selectedId}
                    onSelect={onSelectFallback}
                  />
                </ol>
              </>
            )}
          </>
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
  /** Normalde 1'den başlayan sıra numarası; "en yakın" önerisinde "≈". */
  rank: number | string;
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
