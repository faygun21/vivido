import { Link } from 'react-router-dom';
import { api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import type { FavoriteResponse, RouteListResponse, PropertySummary } from '@vivido/shared';
import { useFavoriteMutation } from '@/features/explore/useFavorite';
import { BAND_LABEL, formatRent, splitAddress } from '@/features/explore/propertyFormat';

/**
 * Profildeki favoriler ve kayıtlı rotalar.
 *
 * ⭐ Favoriler artık KART: eskiden "Ev ID: 4213" yazıyordu çünkü sunucu
 * yalnızca `propertyId` dönüyordu. Kullanıcının hangi evi favorilediğini
 * anlamasının hiçbir yolu yoktu. `GET /profile/favorites` artık kira, oda,
 * adres ve skoru da taşıyor.
 */
export function FavoritesAndRoutesPanel() {
  // Favorileri Çekme İsteği
  const { data: favorites, isLoading: isFavoritesLoading } = useSessionQuery({
    queryKey: ['favorites'],
    queryFn: () => api.get<FavoriteResponse[]>('/profile/favorites'),
  });

  // Rotaları Çekme İsteği
  const { data: routes, isLoading: isRoutesLoading } = useSessionQuery({
    queryKey: ['routes'],
    queryFn: () => api.get<RouteListResponse[]>('/routes'),
  });

  return (
    <section className="panel-container">
      <div className="info-card">
        <h2>Favori Konutlarım</h2>
        {isFavoritesLoading ? (
          <p className="muted">Favoriler yükleniyor…</p>
        ) : favorites?.length ? (
          <ul className="favorite-list">
            {favorites.map((fav) => (
              <FavoriteCard key={fav.propertyId} favorite={fav} />
            ))}
          </ul>
        ) : (
          <p className="muted">
            Henüz favori konut yok. <Link to="/explore">Keşfet</Link> ekranında bir konuta
            tıklayıp <strong>Favorilere ekle</strong> ile buraya kaydedebilirsin.
          </p>
        )}
      </div>

      <div className="info-card mt-4">
        <h2>Kayıtlı Rotalarım</h2>
        {isRoutesLoading ? (
          <p className="muted">Rotalar yükleniyor…</p>
        ) : routes?.length ? (
          <ul className="item-list">
            {routes.map((route) => (
              <li key={route.id}>
                <strong>{route.name}</strong> - {route.stopCount} Durak
                ({Math.round(route.totalDistanceM / 1000)} km)
              </li>
            ))}
          </ul>
        ) : (
          <p className="muted">Henüz oluşturulmuş bir rota yok.</p>
        )}
      </div>
    </section>
  );
}

function FavoriteCard({ favorite }: { favorite: FavoriteResponse }) {
  const property = favorite.property;

  // Konut silinmişse (ya da okuma sırasındaki bir yarış durumunda) özet
  // gelmez. Satırı tamamen gizlemek yerine ne olduğunu söylüyoruz —
  // sessizce kaybolan bir favori kullanıcıya hata gibi görünür.
  if (!property) {
    return (
      <li className="favorite-card favorite-card--missing">
        <span className="muted">Bu konut artık listede değil (#{favorite.propertyId}).</span>
      </li>
    );
  }

  return <FavoriteCardBody property={property} addedAt={favorite.createdAt} />;
}

function FavoriteCardBody({ property, addedAt }: { property: PropertySummary; addedAt: string }) {
  const favorite = useFavoriteMutation();
  const address = splitAddress(property.address);

  return (
    <li className="favorite-card">
      <span className={`favorite-score score-badge--${property.band}`}>
        <strong>{Math.round(property.totalScore)}</strong>
        <span>{BAND_LABEL[property.band]}</span>
      </span>

      <div className="favorite-body">
        <p className="favorite-title">
          {property.roomCount} · {property.areaM2} m² · {formatRent(property.monthlyRent)}/ay
        </p>
        <p className="favorite-address">
          <strong>{address.primary}</strong>
          {address.secondary && <span className="muted"> · {address.secondary}</span>}
        </p>

        <p className="favorite-reasons">
          {property.topStrength && (
            <span className="top-card-reason--good">✓ {property.topStrength}</span>
          )}
          {property.topWeakness && (
            <span className="top-card-reason--bad">✗ {property.topWeakness}</span>
          )}
        </p>

        <p className="muted favorite-meta">
          {property.externalRef} · {new Date(addedAt).toLocaleDateString('tr-TR')} tarihinde eklendi
        </p>
      </div>

      <button
        className="btn-chip favorite-remove"
        type="button"
        onClick={() => favorite.mutate({ propertyId: property.id, isFavorite: true })}
        disabled={favorite.isPending}
      >
        Çıkar
      </button>
    </li>
  );
}
