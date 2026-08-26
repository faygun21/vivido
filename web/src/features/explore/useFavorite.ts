import { useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { useSessionKey } from '@/shared/api/sessionQuery';

/**
 * Favoriye ekle / çıkar.
 *
 * ⚠️ Önbellek anahtarlarına oturum kimliği EKLENMİYOR — `useSessionQuery`
 * kimliği anahtarın SONUNA koyuyor ve TanStack Query önek eşleştiriyor,
 * yani `['favorites']` ile invalidate etmek `['favorites', 'user:42']`
 * girdisini de düşürüyor (K-14). Kimliği burada taşımak gereksiz olurdu.
 *
 * Üç ayrı yeri tazeliyoruz çünkü favori bayrağı üç yerde birden görünüyor:
 * profil sayfasındaki liste, "en uygun evler" panelindeki kalpler ve açık
 * detay panelinin kalbi. Biri atlanırsa kullanıcı favoriden çıkardığı evi
 * hâlâ dolu kalple görür.
 */
export function useFavoriteMutation() {
  const queryClient = useQueryClient();
  // Kimlik değişimini mutasyonun da görmesi için okunuyor: çıkış yapılıp
  // başka hesapla girildiğinde React yeni bir mutasyon örneği kurar.
  const sessionKey = useSessionKey();

  return useMutation({
    mutationKey: ['favorite', sessionKey],
    mutationFn: async ({ propertyId, isFavorite }: { propertyId: string; isFavorite: boolean }) => {
      if (isFavorite) {
        await api.delete(`/profile/favorites/${propertyId}`);
      } else {
        await api.post('/profile/favorites', { propertyId: Number(propertyId) });
      }
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['favorites'] });
      void queryClient.invalidateQueries({ queryKey: ['properties', 'top'] });
      void queryClient.invalidateQueries({ queryKey: ['properties', 'detail'] });
    },
  });
}
