import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useQueryClient } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { formatScheduledAt } from '@/features/explore/RouteBuilderPanel';
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
export function FavoritesAndRoutesPanel() {
  const navigate = useNavigate();
  const setActiveRoute = useRouteStore((s) => s.setActiveRoute);
  const activeRoute = useRouteStore((s) => s.activeRoute);
  const [loadingRouteId, setLoadingRouteId] = useState<string | null>(null);
  const [openError, setOpenError] = useState<string | null>(null);
  // Silme iki adımlı: hangi rotanın onayı bekliyor + hangisi siliniyor.
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);
  const [deletingRouteId, setDeletingRouteId] = useState<string | null>(null);
  const queryClient = useQueryClient();

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

  async function removeRoute(id: string) {
    setOpenError(null);
    setDeletingRouteId(id);
    try {
      await api.delete(`/routes/${id}`);
      // Açık olan rota silindiyse haritadaki çizgi de kalkmalı; aksi halde
      // artık var olmayan bir rotayı gösterirdik.
      if (activeRoute?.id === id) setActiveRoute(null);
      void queryClient.invalidateQueries({ queryKey: ['routes'] });
      setConfirmDeleteId(null);
    } catch {
      setOpenError('Rota silinemedi. Kısa süre sonra tekrar dene.');
    } finally {
      setDeletingRouteId(null);
    }
  }

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
        <p className="muted">
          Bir rotaya tıklayınca haritada çizgi, numaralı duraklar ve metrikler açılır.
        </p>

        {isRoutesLoading ? (
          <p className="muted">Rotalar yükleniyor…</p>
        ) : routes?.length ? (
          <ul className="item-list">
            {routes.map((route) => {
              const loading = loadingRouteId === route.id;
              const deleting = deletingRouteId === route.id;
              return (
                <li key={route.id} className="saved-route-item">
                  {/* Satırın TAMAMI değil, içindeki düğme tıklanabilir:
                      silme düğmesi de bir <button> ve iç içe iki tıklanabilir
                      öge geçersiz HTML'dir. */}
                  <button
                    className="saved-route-row"
                    type="button"
                    onClick={() => openRoute(route.id)}
                    disabled={loadingRouteId !== null || deleting}
                  >
                    <span className="saved-route-main">
                      <strong>{route.name}</strong>
                      <span className="muted saved-route-sub">
                        {route.stopCount} durak · {formatRouteDistance(route.totalDistanceM)} ·{' '}
                        {formatRouteDuration(route.totalDurationS)}
                      </span>
                      {route.scheduledAt && (
                        <span className="saved-route-schedule">
                          🗓 {formatScheduledAt(route.scheduledAt)}
                        </span>
                      )}
                    </span>
                    <span className="route-mode-badge">{travelModeLabel(route.mode)}</span>
                    {loading && (
                      <span className="muted" role="status">
                        açılıyor…
                      </span>
                    )}
                  </button>

                  {/* Silme geri alınamaz, o yüzden iki adımlı: ilk tıklama
                      onay ister. Tek tıkla silmek, listeye göz atarken
                      yanlışlıkla rota kaybettirirdi. */}
                  {confirmDeleteId === route.id ? (
                    <span className="saved-route-confirm">
                      <button
                        className="btn-chip is-danger"
                        type="button"
                        onClick={() => removeRoute(route.id)}
                        disabled={deleting}
                      >
                        {deleting ? 'Siliniyor…' : 'Sil'}
                      </button>
                      <button
                        className="btn-chip"
                        type="button"
                        onClick={() => setConfirmDeleteId(null)}
                        disabled={deleting}
                      >
                        Vazgeç
                      </button>
                    </span>
                  ) : (
                    <button
                      className="btn-icon saved-route-delete"
                      type="button"
                      onClick={() => setConfirmDeleteId(route.id)}
                      aria-label={`${route.name} rotasını sil`}
                      title="Rotayı sil"
                    >
                      🗑
                    </button>
                  )}
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
  const address = splitAddress(property.address);

  return (
    <li className="favorite-card">
      <span className={`favorite-score score-badge--${property.band}`}>
        <strong>{property.totalScore.toFixed(1)}</strong>
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
