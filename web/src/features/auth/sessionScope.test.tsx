import { act, render, screen, waitFor } from '@testing-library/react';
import type { AuthResponse, RouteDetail } from '@vivido/shared';
import { AppProviders } from '@/app/providers';
import { useAuthStore, SESSION_ANONYMOUS } from '@/features/auth/authStore';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { useRouteStore } from '@/shared/route/routeStore';
import { api } from '@/shared/api/client';

/**
 * Oturum kimliği ↔ oturuma ait durum regresyon testleri.
 *
 * Kapatılan hatalar:
 *   · A hesabıyla eklenen pinler çıkış yapıldıktan sonra misafir ekranında
 *     ve B hesabıyla girildiğinde görünmeye devam ediyordu (sunucu
 *     önbelleği).
 *   · A hesabında açılan kayıtlı rota, çıkış yapıp misafir olarak devam
 *     edildiğinde haritada çizili kalıyordu (istemci durumu —
 *     `useRouteStore` modül ömürlü, `queryClient.clear()` ona dokunmuyor).
 */

const { apiGet } = vi.hoisted(() => ({ apiGet: vi.fn() }));

vi.mock('@/shared/api/client', () => ({
  api: { get: apiGet },
  ApiError: class extends Error {},
  NetworkError: class extends Error {},
}));

/** Anchor listesini çizen asgari bileşen — ExplorePage'in yaptığının özü. */
function PinListesi() {
  const { data = [] } = useSessionQuery<{ label: string }[]>({
    queryKey: ['anchors'],
    queryFn: () => api.get<{ label: string }[]>('/profile/anchors'),
  });

  return (
    <ul>
      {data.map((pin) => (
        <li key={pin.label}>{pin.label}</li>
      ))}
    </ul>
  );
}

function oturum(userId: string, email: string): AuthResponse {
  return {
    user: {
  id: userId,
  email,
  displayName: null,
  emailVerified: true,
  isAdmin: false,
},
    tokens: { accessToken: `access-${userId}`, refreshToken: `refresh-${userId}`, expiresIn: 900 },
  };
}

function girisYap(userId: string, email: string) {
  act(() => useAuthStore.getState().setSession(oturum(userId, email)));
}

/** Haritaya çizilen kayıtlı rota — yalnızca kimlik alanları anlamlı. */
function rota(id: string): RouteDetail {
  return {
    id,
    name: 'Ayşe rotası',
    start: { lat: 39.92, lon: 32.85, label: 'Kızılay' },
    mode: 'car',
    totalDistanceM: 12_000,
    totalDurationS: 1_800,
    stopCount: 0,
    geometry: { type: 'LineString', coordinates: [[32.85, 39.92], [32.86, 39.93]] },
    stops: [],
    legs: [],
    scheduledAt: null,
    isSaved: true,
    createdAt: '2026-08-25T00:00:00Z',
  };
}

beforeEach(() => {
  apiGet.mockReset();
  localStorage.clear();
  sessionStorage.clear();
  useRouteStore.setState({ activeRoute: null });
  useAuthStore.setState({
    status: 'unknown',
    user: null,
    isGuest: false,
    sessionKey: SESSION_ANONYMOUS,
  });
});

test('çıkış yapınca önceki hesabın pinleri ekranda kalmaz', async () => {
  apiGet.mockResolvedValue([{ label: 'Ayşe evi' }]);
  render(<AppProviders><PinListesi /></AppProviders>);

  girisYap('kullanici-a', 'a@ornek.com');
  expect(await screen.findByText('Ayşe evi')).toBeInTheDocument();

  act(() => useAuthStore.getState().clearSession());

  await waitFor(() => expect(screen.queryByText('Ayşe evi')).not.toBeInTheDocument());
});

test('başka hesapla girince önceki hesabın pinleri görünmez', async () => {
  apiGet.mockResolvedValueOnce([{ label: 'Ayşe evi' }]);
  render(<AppProviders><PinListesi /></AppProviders>);

  girisYap('kullanici-a', 'a@ornek.com');
  expect(await screen.findByText('Ayşe evi')).toBeInTheDocument();

  act(() => useAuthStore.getState().clearSession());
  apiGet.mockResolvedValueOnce([{ label: 'Mehmet evi' }]);
  girisYap('kullanici-b', 'b@ornek.com');

  expect(await screen.findByText('Mehmet evi')).toBeInTheDocument();
  expect(screen.queryByText('Ayşe evi')).not.toBeInTheDocument();
});

test('misafir ne istek atar ne de önceki hesabın verisini görür', async () => {
  apiGet.mockResolvedValue([{ label: 'Ayşe evi' }]);
  render(<AppProviders><PinListesi /></AppProviders>);

  girisYap('kullanici-a', 'a@ornek.com');
  expect(await screen.findByText('Ayşe evi')).toBeInTheDocument();

  act(() => useAuthStore.getState().clearSession());
  apiGet.mockClear();
  act(() => useAuthStore.getState().enterGuest());

  await waitFor(() => expect(screen.queryByText('Ayşe evi')).not.toBeInTheDocument());
  // ⚠️ Misafirken korumalı uç noktaya istek atılırsa 401 → yenileme →
  // refresh token yok → clearSession zinciri çalışır ve misafir kendi
  // kendini kapı dışarı eder (K-10).
  expect(apiGet).not.toHaveBeenCalled();
});

/* Rota testleri sorgu katmanına DEĞİL `SessionCacheSync`e bakıyor; ekrana
   bir tüketici çizmeye gerek yok — `AppProviders` onu zaten bağlıyor. */
test('çıkış yapıp misafir olarak devam edince önceki hesabın rotası haritada kalmaz', () => {
  render(<AppProviders>{null}</AppProviders>);

  girisYap('kullanici-a', 'a@ornek.com');
  act(() => useRouteStore.getState().setActiveRoute(rota('rota-1')));
  expect(useRouteStore.getState().activeRoute?.id).toBe('rota-1');

  // Çıkış (`anon`) ve misafirlik (`guest`) AYRI iki kimlik geçişi;
  // kullanıcının bildirdiği akış ikisinden de geçiyor.
  act(() => useAuthStore.getState().clearSession());
  expect(useRouteStore.getState().activeRoute).toBeNull();

  act(() => useRouteStore.getState().setActiveRoute(rota('rota-2')));
  act(() => useAuthStore.getState().enterGuest());
  expect(useRouteStore.getState().activeRoute).toBeNull();
});

test('başka hesapla girince önceki hesabın rotası haritada kalmaz', () => {
  render(<AppProviders>{null}</AppProviders>);

  girisYap('kullanici-a', 'a@ornek.com');
  act(() => useRouteStore.getState().setActiveRoute(rota('rota-1')));

  act(() => useAuthStore.getState().clearSession());
  girisYap('kullanici-b', 'b@ornek.com');

  expect(useRouteStore.getState().activeRoute).toBeNull();
});

test('token yenilemesi aktif rotayı düşürmez', () => {
  render(<AppProviders>{null}</AppProviders>);

  girisYap('kullanici-a', 'a@ornek.com');
  act(() => useRouteStore.getState().setActiveRoute(rota('rota-1')));

  // Kimlik aynı — 15 dakikada bir yenilenen token yüzünden kullanıcının
  // haritadaki rotası kaybolmamalı.
  girisYap('kullanici-a', 'a@ornek.com');

  expect(useRouteStore.getState().activeRoute?.id).toBe('rota-1');
});

test('token yenilemesi (aynı kullanıcı) önbelleği düşürmez', async () => {
  apiGet.mockResolvedValue([{ label: 'Ayşe evi' }]);
  render(<AppProviders><PinListesi /></AppProviders>);

  girisYap('kullanici-a', 'a@ornek.com');
  expect(await screen.findByText('Ayşe evi')).toBeInTheDocument();
  expect(apiGet).toHaveBeenCalledTimes(1);

  // `bootstrapSession`/401 yenilemesi de `setSession` çağırır. Kimlik aynı
  // olduğu için önbellek BOŞUNA düşmemeli — aksi halde kullanıcı 15
  // dakikada bir boş ekran görürdü.
  girisYap('kullanici-a', 'a@ornek.com');

  await waitFor(() => expect(screen.getByText('Ayşe evi')).toBeInTheDocument());
  expect(apiGet).toHaveBeenCalledTimes(1);
});
