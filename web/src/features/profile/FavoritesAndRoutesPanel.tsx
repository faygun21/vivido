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
export function FavoritesPanel() {
  const { data: favorites, isLoading } = useSessionQuery({
    queryKey: ['favorites'],
    queryFn: () => api.get<FavoriteResponse[]>('/profile/favorites'),
  });

  return (
    <div className="info-card">
      <h2>Favori Konutlarım</h2>
      {isLoading ? (
        /*
          Düz "Favoriler yükleniyor…" metni yerine kart iskeleti.

          Metin, gelecek içeriğin ŞEKLİ hakkında hiçbir şey söylemez;
          liste dolunca sayfa aniden zıplar. İskelet, gelecek satırların
          yerini şimdiden ayırır — yükleme bitince yerleşim oynamaz ve
          bekleme daha kısa hissedilir.
        */
        <ul className="favorite-list" aria-busy="true" aria-label="Favoriler yükleniyor">
          {[0, 1, 2].map((row) => (
            <li key={row} className="favorite-card favorite-card--skeleton" aria-hidden="true">
              <span className="skeleton favorite-skeleton-score" />
              <span className="favorite-skeleton-body">
                <span className="skeleton favorite-skeleton-line" />
                <span className="skeleton favorite-skeleton-line favorite-skeleton-line--short" />
                <span className="skeleton favorite-skeleton-line favorite-skeleton-line--tiny" />
              </span>
            </li>
          ))}
        </ul>
      ) : favorites?.length ? (
        <ul className="favorite-list anim-stagger">
          {favorites.map((favorite) => (
            <FavoriteCard key={favorite.propertyId} favorite={favorite} />
          ))}
        </ul>
      ) : (
        /* Boş durum bir HATA DEĞİL: ne olduğunu, neden olduğunu ve
           çıkış yolunu birlikte söylüyor. Düz gri bir cümle "burada
           bir şey ters gitti" gibi okunuyordu. */
        <div className="empty-state">
          <span className="empty-state-icon" aria-hidden="true">♡</span>
          <p className="empty-state-title">Henüz favori konut yok</p>
          <p className="empty-state-text">
            <Link to="/explore">Keşfet</Link> ekranındaki <strong>En uygun evler</strong>{' '}
            listesinden kalp simgesine basarak eklemeye başlayabilirsin.
          </p>
        </div>
      )}
    </div>
  );
}

export function RoutesPanel() {
  const navigate = useNavigate();
  const setActiveRoute = useRouteStore((s) => s.setActiveRoute);
  const activeRoute = useRouteStore((s) => s.activeRoute);
  const [loadingRouteId, setLoadingRouteId] = useState<string | null>(null);
  const [openError, setOpenError] = useState<string | null>(null);
  // Silme iki adımlı: hangi rotanın onayı bekliyor + hangisi siliniyor.
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);
  const [deletingRouteId, setDeletingRouteId] = useState<string | null>(null);
  const queryClient = useQueryClient();

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
    <article className="pcard">
      <header className="pcard-head">
        <span className="pcard-icon" aria-hidden="true">🗺</span>
        <div className="pcard-head-text">
          <h2>Kayıtlı Rotalarım</h2>
          <p>Bir rotaya tıklayınca haritada çizgi, numaralı duraklar ve metrikler açılır.</p>
        </div>

        {routes && routes.length > 0 && (
          <span className="pcard-count">{routes.length}</span>
        )}
      </header>

      <div className="pcard-body">
        {isRoutesLoading ? (
          <ul className="item-list" aria-busy="true" aria-label="Rotalar yükleniyor">
            {[0, 1].map((row) => (
              <li key={row} className="saved-route-item" aria-hidden="true">
                <span className="skeleton favorite-skeleton-line" />
              </li>
            ))}
          </ul>
        ) : routes?.length ? (
          <ul className="item-list anim-stagger">
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
          <div className="empty-state">
            <span className="empty-state-icon" aria-hidden="true">🗺</span>
            <p className="empty-state-title">Henüz oluşturulmuş bir rota yok</p>
            <p className="empty-state-text">
              <Link to="/explore">Keşfet</Link> ekranından 2–8 ev seçip{' '}
              <strong>Rota Oluştur</strong> ile en kısa ziyaret sıranı planlayabilirsin.
            </p>
          </div>
        )}

        {openError && (
          <p className="route-error" role="alert">
            {openError}
          </p>
        )}
      </div>
    </article>
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
