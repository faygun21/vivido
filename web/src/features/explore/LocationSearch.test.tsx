import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import type { LocationSearchResponse } from '@vivido/shared';
import { LocationSearch } from './LocationSearch';

const { apiGet } = vi.hoisted(() => ({ apiGet: vi.fn() }));

vi.mock('@/shared/api/client', () => ({
  api: { get: apiGet },
  ApiError: class extends Error {},
  NetworkError: class extends Error {},
}));

test('arama sonucunu backendden alır ve seçilen konumu bildirir', async () => {
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
