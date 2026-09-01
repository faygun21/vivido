import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import type { LocationSearchResponse } from '@vivido/shared';
import { LocationSearch } from './LocationSearch';

const { apiGet } = vi.hoisted(() => ({ apiGet: vi.fn() }));

vi.mock('@/shared/api/client', () => ({
  api: { get: apiGet },
  ApiError: class extends Error {},
  NetworkError: class extends Error {},
}));

const response: LocationSearchResponse = {
  attribution: '© OpenStreetMap contributors',
  items: [{
    id: 'neighborhood:1',
    label: 'Kavaklıdere Mahallesi, Çankaya, Ankara',
    kind: 'neighborhood',
    latitude: 39.91,
    longitude: 32.86,
    bounds: { south: 39.9, west: 32.85, north: 39.92, east: 32.87 },
    neighborhood: 'Kavaklıdere',
    source: 'local',
  }],
};

test('arama sonucunu backendden alır ve seçilen konumu bildirir', async () => {
  apiGet.mockResolvedValueOnce(response);
  const onSelect = vi.fn();
  render(<LocationSearch onSelect={onSelect} />);

  fireEvent.change(screen.getByLabelText('Mahalle, adres veya konum ara'), {
    target: { value: 'Kavaklıdere' },
  });
  fireEvent.click(screen.getByRole('button', { name: 'Ara' }));

  const result = await screen.findByRole('button', {
    name: /Kavaklıdere Mahallesi, Çankaya, Ankara/,
  });
  expect(apiGet).toHaveBeenCalledWith('/locations/search?q=Kavakl%C4%B1dere&limit=5');
  fireEvent.click(result);
  await waitFor(() => expect(onSelect).toHaveBeenCalledWith(response.items[0]));
});

/**
 * Gömülü sürüm (profil sayfasındaki anchor haritası) listeyi haritanın
 * ÜSTÜNE açıyor — seçimden sonra açık kalırsa kullanıcı noktanın nereye
 * düştüğünü göremez. Explore'daki yüzen sürümde liste bilerek açık kalır.
 */
test('gömülü sürümde sonuç seçilince liste kapanır, yüzen sürümde açık kalır', async () => {
  apiGet.mockResolvedValue(response);

  const { unmount } = render(<LocationSearch variant="inline" onSelect={vi.fn()} />);
  fireEvent.change(screen.getByLabelText(/Mahalle, adres veya konum ara/), {
    target: { value: 'Kavaklıdere' },
  });
  fireEvent.click(screen.getByRole('button', { name: 'Ara' }));

  fireEvent.click(await screen.findByRole('button', { name: /Kavaklıdere Mahallesi/ }));
  await waitFor(() =>
    expect(screen.queryByRole('button', { name: /Kavaklıdere Mahallesi/ })).toBeNull(),
  );
  unmount();

  render(<LocationSearch onSelect={vi.fn()} />);
  fireEvent.change(screen.getByLabelText(/Mahalle, adres veya konum ara/), {
    target: { value: 'Kavaklıdere' },
  });
  fireEvent.click(screen.getByRole('button', { name: 'Ara' }));

  const overlayResult = await screen.findByRole('button', { name: /Kavaklıdere Mahallesi/ });
  fireEvent.click(overlayResult);
  expect(screen.getByRole('button', { name: /Kavaklıdere Mahallesi/ })).toBeTruthy();
});
