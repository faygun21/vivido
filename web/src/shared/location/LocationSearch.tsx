import { useEffect, useId, useRef, useState, type FormEvent } from 'react';
import type { LocationSearchResponse, LocationSearchResult } from '@vivido/shared';
import { api, ApiError, NetworkError } from '@/shared/api/client';
import './LocationSearch.css';

interface LocationSearchProps {
  onSelect: (location: LocationSearchResult) => void;
  onClear?: () => void;
  /**
   * `overlay` (varsayılan): explore'daki TAM EKRAN haritanın üstünde yüzen
   * kutu — mutlak konumlu, kendi gölgesini taşır.
   *
   * `inline`: bir kartın içine gömülü haritanın (profil/onboarding'deki
   * 320px'lik anchor haritası) ÜST ŞERİDİ — kendi satırını kaplar, sonuç
   * listesi haritanın üstüne açılır.
   */
  variant?: 'overlay' | 'inline';
  /** Bağlama göre değişebilsin diye dışarıdan verilebilir. */
  placeholder?: string;
}

const kindLabels = {
  neighborhood: 'Mahalle',
  address: 'Adres',
  place: 'Konum',
} as const;

/**
 * Yazmayı bırakınca kaç ms sonra otomatik arama tetiklenecek.
 *
 * İlk sürümde 2000ms'ydi — canlı testte "hâlâ göstermiyor" diye
 * bildirildi (2026-08-28): aslında çalışıyordu ama 2 saniyelik sessiz
 * bekleme kullanıcıya bozuk gibi hissettiriyordu. Normal bir
 * otomatik-tamamlama gecikmesine indirildi.
 */
const SEARCH_DEBOUNCE_MS = 400;

export function LocationSearch({
  onSelect,
  onClear,
  variant = 'overlay',
  placeholder = 'Mahalle, adres veya konum ara',
}: LocationSearchProps) {
  // Sayfada birden fazla arama kutusu olabilir (explore çekmecesi + gömülü
  // harita). Sabit bir `id` yazılırsa `label`/`input` eşleşmesi ikisinde de
  // aynı kimliğe bağlanır ve ekran okuyucu yanlış alana odaklanır.
  const inputId = useId();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<LocationSearchResult[]>([]);
  const [attribution, setAttribution] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const debounceTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  async function runSearch(rawQuery: string) {
    const normalizedQuery = rawQuery.trim();
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

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (debounceTimer.current) clearTimeout(debounceTimer.current);
    void runSearch(query);
  }

  // `runSearch` her render'da yeniden kuruluyor (kapattığı `loading`/`onClear`
  // güncel kalsın diye) — zamanlayıcı efekti bunu bağımlılığa koymadan hep
  // GÜNCEL halini çağırabilsin diye bir ref'te tutuyoruz. Yoksa ya efekt her
  // render'da gereksiz yere yeniden kurulur ya da 2sn sonra çalışan
  // zamanlayıcı bayat bir `loading` değeriyle çalışırdı.
  const runSearchRef = useRef(runSearch);
  runSearchRef.current = runSearch;

  /**
   * Yazarken otomatik arama — 2sn boyunca yeni tuşa basılmazsa sorgu
   * kendiliğinden çalışır, "Ara"ya basmaya gerek kalmaz (2026-08-28).
   * Her tuş vuruşu önceki zamanlayıcıyı iptal eder (bkz. `ExplorePage`'deki
   * `boundsTimer` ile aynı desen).
   */
  useEffect(() => {
    if (debounceTimer.current) clearTimeout(debounceTimer.current);

    if (query.trim().length < 2) {
      // Kısa/boş sorguda eski sonuçları ekranda bırakmanın anlamı yok.
      setResults([]);
      setSearched(false);
      return;
    }

    debounceTimer.current = setTimeout(() => {
      void runSearchRef.current(query);
    }, SEARCH_DEBOUNCE_MS);

    return () => {
      if (debounceTimer.current) clearTimeout(debounceTimer.current);
    };
  }, [query]);

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

    // Gömülü sürümde liste haritanın ÜSTÜNE açılıyor: açık kalırsa
    // kullanıcı az önce seçtiği noktanın haritada nereye düştüğünü
    // göremez. Explore'da liste çekmecenin üstünde duruyor ve harita
    // yanında görünmeye devam ediyor — orada açık kalması, sonuçlar
    // arasında gezinmeyi kolaylaştırdığı için isteniyor.
    // Sorgu metni SİLİNMİYOR; kullanıcı ne aradığını görmeye devam etsin.
    if (variant === 'inline') {
      setResults([]);
      setSearched(false);
    }
  }

  return (
    <div
      className={`location-search location-search--${variant}`}
      onKeyDown={(event) => event.key === 'Escape' && clear()}
    >
      <form className="location-search-form" role="search" onSubmit={submit}>
        <label className="sr-only" htmlFor={inputId}>
          {placeholder}
        </label>
        <span className="location-search-icon" aria-hidden="true">⌕</span>
        <input
          id={inputId}
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder={placeholder}
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
