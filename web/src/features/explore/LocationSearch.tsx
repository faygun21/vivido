import { useState, type FormEvent } from 'react';
import type { LocationSearchResponse, LocationSearchResult } from '@vivido/shared';
import { api, ApiError, NetworkError } from '@/shared/api/client';
import './LocationSearch.css';

interface LocationSearchProps {
  onSelect: (location: LocationSearchResult) => void;
  onClear?: () => void;
}

const kindLabels = {
  neighborhood: 'Mahalle',
  address: 'Adres',
  place: 'Konum',
} as const;

export function LocationSearch({ onSelect, onClear }: LocationSearchProps) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<LocationSearchResult[]>([]);
  const [attribution, setAttribution] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalizedQuery = query.trim();
    if (normalizedQuery.length < 2 || loading) return;

    setLoading(true);
    setError(null);
    setSearched(false);
    setResults([]);
    setSelectedId(null);
    setAttribution('');
    onClear?.();
    try {
      const response = await api.get<LocationSearchResponse>(
        `/locations/search?q=${encodeURIComponent(normalizedQuery)}&limit=5`,
      );
      setResults(response.items);
      setAttribution(response.attribution);
      setSearched(true);
    } catch (cause) {
      setResults([]);
      setError(toSearchError(cause));
    } finally {
      setLoading(false);
    }
  }

  function clear() {
    setQuery('');
    setResults([]);
    setAttribution('');
    setSelectedId(null);
    setSearched(false);
    setError(null);
    onClear?.();
  }

  function select(result: LocationSearchResult) {
    setSelectedId(result.id);
    onSelect(result);
  }

  return (
    <div className="location-search" onKeyDown={(event) => event.key === 'Escape' && clear()}>
      <form className="location-search-form" role="search" onSubmit={submit}>
        <label className="sr-only" htmlFor="location-query">
          Mahalle, adres veya konum ara
        </label>
        <span className="location-search-icon" aria-hidden="true">⌕</span>
        <input
          id="location-query"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Mahalle, adres veya konum ara"
          autoComplete="off"
          maxLength={200}
        />
        {query && (
          <button className="location-search-clear" type="button" onClick={clear} aria-label="Aramayı temizle">
            ×
          </button>
        )}
        <button className="location-search-submit" type="submit" disabled={query.trim().length < 2 || loading}>
          {loading ? 'Aranıyor…' : 'Ara'}
        </button>
      </form>

      <div className="location-search-feedback" aria-live="polite">
        {error && <p className="location-search-error">{error}</p>}
        {!error && searched && results.length === 0 && (
          <p className="location-search-empty">Çankaya sınırları içinde sonuç bulunamadı.</p>
        )}
      </div>

      {results.length > 0 && (
        <div className="location-search-results">
          <ul aria-label="Konum arama sonuçları">
            {results.map((result) => (
              <li key={result.id}>
                <button
                  type="button"
                  className={selectedId === result.id ? 'is-selected' : ''}
                  onClick={() => select(result)}
                  aria-pressed={selectedId === result.id}
                >
                  <span>{result.label}</span>
                  <small>{kindLabels[result.kind]}</small>
                </button>
              </li>
            ))}
          </ul>
          {attribution && (
            <p className="location-search-attribution">
              <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">
                {attribution}
              </a>
            </p>
          )}
        </div>
      )}
    </div>
  );
}

function toSearchError(cause: unknown): string {
  if (cause instanceof NetworkError) return 'Sunucuya ulaşılamadı. Bağlantını kontrol et.';
  if (cause instanceof ApiError && cause.problem.code === 'LOCATION_SEARCH_UNAVAILABLE') {
    return 'Adres arama servisi şu anda kullanılamıyor. Lütfen yeniden dene.';
  }
  if (cause instanceof ApiError) return cause.problem.title;
  return 'Konum aranırken beklenmeyen bir hata oluştu.';
}
