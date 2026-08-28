import { useMemo, useState } from 'react';
import type { PropertySummary } from '@vivido/shared';
import { formatRent, splitAddress } from './propertyFormat';
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
type SortOption = 'skor' | 'kira-azalan' | 'kira-artan' | 'm2-azalan' | 'm2-artan';

const SORT_LABELS: Record<SortOption, string> = {
  skor: 'Öneri (skor)',
  'kira-azalan': 'Kira: Azalan',
  'kira-artan': 'Kira: Artan',
  'm2-azalan': 'm²: Azalan',
  'm2-artan': 'm²: Artan',
};

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
  /**
   * Rotaya eklenmiş konut id'leri — favori bayrağının (`isFavorite`) aksine
   * sunucudan gelmiyor, henüz kaydedilmemiş bir seçim; `ExplorePage`'de
   * türetiliyor (bkz. oradaki not).
   */
  routePropertyIds: Set<number>;
  /** Rota `MAX_ROUTE_STOPS`'a ulaştıysa YENİ ekleme düğmeleri devre dışı kalır — çıkarma hep açık. */
  routeAtCapacity: boolean;
  onToggleRoute: (propertyId: number) => void;
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
  routePropertyIds,
  routeAtCapacity,
  onToggleRoute,
}: TopPropertiesPanelProps) {
  // ─── Filtreler — TAMAMEN istemci tarafında (2026-08-28) ───
  //
  // `/properties/top` zaten en fazla `TOP_PROPERTY_LIMIT` (20) kaydı,
  // skora göre sıralı getiriyor; sunucuya yeni bir uç nokta/parametre
  // eklemeden bu 20 kaydı burada süzüyoruz. Sıra numarası (`rank`) süzülmüş
  // listenin değil ORİJİNAL listenin indeksinden geliyor — filtre "3."
  // sıradaki evi gizlese bile kalan evin sıra numarası "3" olarak kalır,
  // yoksa "profiline göre en uygunu bu" anlamı bozulurdu.
  //
  // Kira/m² aralığı denendi, kaldırıldı (2026-08-28) — sıralama (Kira:
  // Azalan/Artan, m²: Azalan/Artan) zaten aynı ihtiyacı karşılıyordu, ayrı
  // bir min/max girişi fazlaydı.
  const [roomCounts, setRoomCounts] = useState<Set<string>>(new Set());
  const [sortBy, setSortBy] = useState<SortOption>('skor');
  // Filtre/sıralama düğmesine basınca açılan yüzey (2026-08-28) — her zaman
  // açık bir çubuk yerine, tıklanınca beliren bir panel.
  const [filtersOpen, setFiltersOpen] = useState(false);

  const roomCountOptions = useMemo(
    () => Array.from(new Set(items.map((item) => item.roomCount))).sort(),
    [items],
  );

  const hasActiveFilter = roomCounts.size > 0;

  const rankedItems = useMemo(
    () => items.map((property, index) => ({ property, rank: index + 1 })),
    [items],
  );

  const filteredItems = useMemo(
    () =>
      rankedItems.filter(
        ({ property }) => roomCounts.size === 0 || roomCounts.has(property.roomCount),
      ),
    [rankedItems, roomCounts],
  );

  // Sıra numarası (`rank`) filtre gibi hep ORİJİNAL skor sırasını taşıyor —
  // burada sadece görüntüleme SIRASI değişiyor, "profiline göre X. en uygun"
  // anlamı bozulmuyor (bkz. yukarıdaki not).
  const sortedItems = useMemo(() => {
    if (sortBy === 'skor') return filteredItems;
    const copy = [...filteredItems];
    switch (sortBy) {
      case 'kira-azalan':
        copy.sort((a, b) => b.property.monthlyRent - a.property.monthlyRent);
        break;
      case 'kira-artan':
        copy.sort((a, b) => a.property.monthlyRent - b.property.monthlyRent);
        break;
      case 'm2-azalan':
        copy.sort((a, b) => b.property.areaM2 - a.property.areaM2);
        break;
      case 'm2-artan':
        copy.sort((a, b) => a.property.areaM2 - b.property.areaM2);
        break;
    }
    return copy;
  }, [filteredItems, sortBy]);

  function toggleRoomCount(value: string) {
    setRoomCounts((current) => {
      const next = new Set(current);
      if (next.has(value)) next.delete(value);
      else next.add(value);
      return next;
    });
  }

  function clearFilters() {
    setRoomCounts(new Set());
  }

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
              : hasActiveFilter
                ? `${filteredItems.length} / ${items.length} konut gösteriliyor`
                : `Profiline göre en yüksek skorlu ${items.length} konut`}
          </p>
        </div>
        <button className="btn-icon" type="button" onClick={onClose} aria-label="Paneli kapat">
          ✕
        </button>
      </header>

      {!isLoading && items.length > 0 && (
        <div className="top-filters-bar">
          <button
            type="button"
            className={`top-filters-toggle${filtersOpen ? ' is-open' : ''}`}
            aria-expanded={filtersOpen}
            onClick={() => setFiltersOpen((current) => !current)}
          >
            <span aria-hidden="true">⚙</span>
            Filtrele ve sırala
            {(hasActiveFilter || sortBy !== 'skor') && (
              <span className="top-filters-badge">
                {(hasActiveFilter ? 1 : 0) + (sortBy !== 'skor' ? 1 : 0)}
              </span>
            )}
          </button>

          {filtersOpen && (
            <div className="top-filters-surface" role="group" aria-label="Filtrele ve sırala">
              <div className="top-filters-section">
                <span className="top-filters-label">Sırala</span>
                <div className="top-filters-chips">
                  {(Object.keys(SORT_LABELS) as SortOption[]).map((option) => (
                    <button
                      key={option}
                      type="button"
                      className={`btn-chip${sortBy === option ? ' is-active' : ''}`}
                      aria-pressed={sortBy === option}
                      onClick={() => setSortBy(option)}
                    >
                      {SORT_LABELS[option]}
                    </button>
                  ))}
                </div>
              </div>

              {roomCountOptions.length > 1 && (
                <div className="top-filters-section">
                  <span className="top-filters-label">Oda sayısı</span>
                  <div className="top-filters-chips" role="group" aria-label="Oda sayısı">
                    {roomCountOptions.map((option) => (
                      <button
                        key={option}
                        type="button"
                        className={`btn-chip${roomCounts.has(option) ? ' is-active' : ''}`}
                        aria-pressed={roomCounts.has(option)}
                        onClick={() => toggleRoomCount(option)}
                      >
                        {option}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              <div className="top-filters-actions">
                <button
                  type="button"
                  className="top-filters-clear"
                  onClick={clearFilters}
                  disabled={!hasActiveFilter}
                >
                  Filtreleri temizle
                </button>
                <button
                  type="button"
                  className="btn-chip"
                  onClick={() => setFiltersOpen(false)}
                >
                  Kapat
                </button>
              </div>
            </div>
          )}
        </div>
      )}

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
                    inRoute={routePropertyIds.has(Number(nearestFallback.id))}
                    routeAtCapacity={routeAtCapacity}
                    onToggleRoute={onToggleRoute}
                  />
                </ol>
              </>
            )}
          </>
        )}

        {!isLoading && emptyReason === null && hasActiveFilter && sortedItems.length === 0 && (
          <p className="muted top-panel-note">
            Bu filtrelerle eşleşen konut yok.{' '}
            <button type="button" className="top-panel-note-action" onClick={clearFilters}>
              Filtreleri temizle
            </button>
          </p>
        )}

        <ol className="top-list">
          {sortedItems.map(({ property, rank }) => (
            <TopPropertyCard
              key={property.id}
              property={property}
              rank={rank}
              selected={property.id === selectedId}
              onSelect={onSelect}
              inRoute={routePropertyIds.has(Number(property.id))}
              routeAtCapacity={routeAtCapacity}
              onToggleRoute={onToggleRoute}
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
  inRoute: boolean;
  routeAtCapacity: boolean;
  onToggleRoute: (propertyId: number) => void;
}

function TopPropertyCard({
  property,
  rank,
  selected,
  onSelect,
  inRoute,
  routeAtCapacity,
  onToggleRoute,
}: TopPropertyCardProps) {
  const favorite = useFavoriteMutation();
  const address = splitAddress(property.address);
  // Rota doluyken YENİ ekleme kilitlenir, ama zaten içindeyse çıkarmak
  // her zaman açık kalmalı — favori düğmesinde böyle bir sınır yok.
  const routeDisabled = routeAtCapacity && !inRoute;

  return (
    <li className={`top-card${selected ? ' is-selected' : ''}`}>
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

        {/* 👇 Sadece puan gözüksün diye alttaki yazıyı kaldırdık 👇 */}
        <span className={`top-card-score score-badge--${property.band}`}>
          <strong>{property.totalScore.toFixed(1)}</strong>
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

      <button
        className={`top-card-route${inRoute ? ' is-active' : ''}`}
        type="button"
        onClick={() => onToggleRoute(Number(property.id))}
        disabled={routeDisabled}
        aria-pressed={inRoute}
        aria-label={inRoute ? 'Rotadan çıkar' : 'Rotaya ekle'}
        title={
          routeDisabled
            ? 'Rota dolu — önce bir durak çıkar'
            : inRoute
              ? 'Rotadan çıkar'
              : 'Rotaya ekle'
        }
      >
        {/* Bayrak: dolu = rotada, çerçeveli = değil — kalp ♥/♡ ile aynı
            aktif/pasif deseni ama karışmasın diye ayrı bir sembol
            (2026-08-28: eski "+" işareti favoriden ayrışmıyordu). */}
        {inRoute ? '⚑' : '⚐'}
      </button>
    </li>
  );
}
