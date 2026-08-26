import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { useRouteStore } from '@/shared/route/routeStore';
import {
  formatRouteDistance,
  formatRouteDuration,
  travelModeLabel,
} from '@/shared/route/routeFormat';
import type {
  FavoriteResponse,
  PropertySummary,
  RouteDetail,
  RouteListResponse,
} from '@vivido/shared';
import { useFavoriteMutation } from '@/features/explore/useFavorite';
import { BAND_LABEL, formatRent, splitAddress } from '@/features/explore/propertyFormat';

/**
 * Profildeki favoriler ve kayıtlı rotalar.
 *
 * ⭐ Favoriler KART olarak geliyor: eskiden "Ev ID: 4213" yazıyordu çünkü
 * sunucu yalnızca `propertyId` dönüyordu. Kullanıcının hangi evi
 * favorilediğini anlamasının hiçbir yolu yoktu. `GET /profile/favorites`
 * artık kira, oda, adres ve skoru da taşıyor.
 *
 * ⭐ Kayıtlı Rotalarım (R-123): bir rotaya tıklanınca `GET /routes/{id}` ile
 * tam detay (çizgi + duraklar + bacaklar) çekilir, store'a yazılır ve
 * kullanıcı haritaya yönlendirilir. Explore tarafı
 * `useRouteStore.activeRoute`'u okuyup çizgiyi, numaralı durakları ve metrik
 * kartını zaten çizer.
 */
export function FavoritesPanel() {
  const { data: favorites, isLoading } = useSessionQuery({
    queryKey: ['favorites'],
    queryFn: () => api.get<FavoriteResponse[]>('/profile/favorites'),
  });

  return (
    <div className="info-card">
      <h2>Favori Konutlarım</h2>
      {isLoading ? (
        <p className="muted">Favoriler yükleniyor…</p>
      ) : favorites?.length ? (
        <ul className="favorite-list">
          {favorites.map((favorite) => (
            <FavoriteCard key={favorite.propertyId} favorite={favorite} />
          ))}
        </ul>
      ) : (
        <p className="muted">
          Henüz favori konut yok. <Link to="/explore">Keşfet</Link> ekranındaki{' '}
          <strong>En uygun evler</strong> listesinden kalp simgesine basarak ekleyebilirsin.
        </p>
      )}
    </div>
  );
}

export function RoutesPanel() {
  const navigate = useNavigate();
  const setActiveRoute = useRouteStore((s) => s.setActiveRoute);
  const [loadingRouteId, setLoadingRouteId] = useState<string | null>(null);
  const [openError, setOpenError] = useState<string | null>(null);

  // Rotaları Çekme İsteği
  const { data: routes, isLoading: isRoutesLoading } = useSessionQuery({
    queryKey: ['routes'],
    queryFn: () => api.get<RouteListResponse[]>('/routes'),
  });

  async function openRoute(id: string) {
    setOpenError(null);
    setLoadingRouteId(id);
    try {
      const detail = await api.get<RouteDetail>(`/routes/${id}`);
      setActiveRoute(detail);
      navigate('/explore');
    } catch {
      // Rota silinmiş ya da ağ hatası — liste yerinde kalır, kullanıcı bilgilendirilir.
      setOpenError('Rota açılamadı. Kısa süre sonra tekrar dene.');
    } finally {
      setLoadingRouteId(null);
    }
  }

  return (
    <section className="panel-container">
      <div className="info-card">
        <h2>Kayıtlı Rotalarım</h2>
        <p className="muted">
          Bir rotaya tıklayınca haritada çizgi, numaralı duraklar ve metrikler açılır.
        </p>

        {isRoutesLoading ? (
          <p className="muted">Rotalar yükleniyor…</p>
        ) : routes?.length ? (
          <ul className="item-list">
            {routes.map((route) => {
              const loading = loadingRouteId === route.id;
              return (
                <li key={route.id}>
                  <button
                    className="saved-route-row"
                    type="button"
                    onClick={() => openRoute(route.id)}
                    disabled={loadingRouteId !== null}
                  >
                    <span className="saved-route-main">
                      <strong>{route.name}</strong>
                      <span className="muted saved-route-sub">
                        {route.stopCount} durak · {formatRouteDistance(route.totalDistanceM)} ·{' '}
                        {formatRouteDuration(route.totalDurationS)}
                      </span>
                    </span>
                    <span className="route-mode-badge">{travelModeLabel(route.mode)}</span>
                    {loading && (
                      <span className="muted" role="status">
                        açılıyor…
                      </span>
                    )}
                  </button>
                </li>
              );
            })}
          </ul>
        ) : (
          <p className="muted">Henüz oluşturulmuş bir rota yok.</p>
        )}

        {openError && (
          <p className="route-error" role="alert">
            {openError}
          </p>
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
  const navigate = useNavigate();
  const address = splitAddress(property.address);

  function openOnMap() {
    navigate('/explore', {
      state: {
        favoriteFocus: {
          id: property.id,
          label: property.address.formatted,
          lat: property.latitude,
          lon: property.longitude,
        },
      },
    });
  }

  return (
    <li className="favorite-card">
      <button className="favorite-card-main" type="button" onClick={openOnMap}>
        <span className={`favorite-score score-badge--${property.band}`}>
          <strong>{property.totalScore.toFixed(1)}</strong>
          <span>{BAND_LABEL[property.band]}</span>
        </span>

        <span className="favorite-body">
          <span className="favorite-title">
            {property.roomCount} · {property.areaM2} m² · {formatRent(property.monthlyRent)}/ay
          </span>
          <span className="favorite-address">
            <strong>{address.primary}</strong>
            {address.secondary && <span className="muted"> · {address.secondary}</span>}
          </span>

          <span className="favorite-reasons">
            {property.topStrength && (
              <span className="top-card-reason--good">✓ {property.topStrength}</span>
            )}
            {property.topWeakness && (
              <span className="top-card-reason--bad">✗ {property.topWeakness}</span>
            )}
          </span>

          <span className="muted favorite-meta">
            {property.externalRef} · {new Date(addedAt).toLocaleDateString('tr-TR')} tarihinde eklendi
          </span>
        </span>
      </button>

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
