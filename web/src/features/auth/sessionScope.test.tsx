import { act, render, screen, waitFor } from '@testing-library/react';
import type { AuthResponse } from '@vivido/shared';
import { AppProviders } from '@/app/providers';
import { useAuthStore, SESSION_ANONYMOUS } from '@/features/auth/authStore';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { api } from '@/shared/api/client';

/**
 * Oturum kimliği ↔ sunucu önbelleği regresyon testleri.
 *
 * Kapatılan hata: A hesabıyla eklenen pinler çıkış yapıldıktan sonra
 * misafir ekranında ve B hesabıyla girildiğinde görünmeye devam ediyordu.
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
    user: { id: userId, email, displayName: null, emailVerified: true },
    tokens: { accessToken: `access-${userId}`, refreshToken: `refresh-${userId}`, expiresIn: 900 },
  };
}

function girisYap(userId: string, email: string) {
  act(() => useAuthStore.getState().setSession(oturum(userId, email)));
}

beforeEach(() => {
  apiGet.mockReset();
  localStorage.clear();
  sessionStorage.clear();
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
