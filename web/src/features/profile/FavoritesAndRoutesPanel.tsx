import { api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import type { FavoriteResponse, RouteListResponse } from '@vivido/shared';

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
          <ul className="item-list">
            {favorites.map((fav) => (
              <li key={fav.propertyId}>Ev ID: {fav.propertyId}</li>
            ))}
          </ul>
        ) : (
          <p className="muted">Henüz favori konut bulunmuyor.</p>
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