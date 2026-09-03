import { useEffect, useId, useRef, useState } from 'react';
import type { LocationSearchResponse, LocationSearchResult } from '@vivido/shared';
import { apiFetch, ApiError, NetworkError } from '@/shared/api/client';
import type { UserLocationStatus } from '@/shared/map/useUserLocation';
import { startFromAddress, type RouteStart } from '@/shared/route/routeStart';

/**
 * Rota başlangıcı için TEK bir konum kutusu (combobox).
 *
 * ⭐ NEDEN TEK KUTU
 *
 * Önceki hâlde iki ayrı denetim vardı: "Konumumu kullan" düğmesi ve altında
 * ayrı bir adres arama kutusu. Kullanıcı için bu iki farklı mekanizma gibi
 * görünüyordu; oysa ikisi de tek bir soruyu cevaplıyor — "nereden
 * başlıyorsun?". Google Maps'in yaptığı gibi tek bir alan: üstüne basınca
 * açılır, en üstte canlı konum, altında yazdıkça gelen adresler.
 *
 * ⭐ YAZDIKÇA ARAMA
 *
 * `LocationSearch` (harita üstündeki kutu) form gönderimiyle çalışıyor —
 * kullanıcı Enter'a ya da "Ara"ya basmalı. Burada beklenen davranış farklı:
 * harf ekledikçe seçenekler düşmeli. Bu yüzden ayrı bir bileşen; ortak
 * kullanılsaydı iki farklı etkileşim modelini tek bileşene sıkıştırmak
 * gerekirdi.
 *
 * İstek her tuşta atılmıyor: 300 ms sessizlik bekleniyor ve her yeni arama
 * öncekini `AbortController` ile iptal ediyor. Aksi halde "Kurtuluş" yazmak
 * 8 istek atar ve yanıtlar sırasız dönerse liste yanlış sonuçta donardı.
 */

interface RouteStartComboboxProps {
  value: RouteStart | null;
  onChange: (start: RouteStart) => void;
  /** Canlı konum seçildiğinde çağrılır — koordinat yoksa yeniden istenir. */
  onUseLiveLocation: () => void;
  locationStatus: UserLocationStatus;
  /** Konum sorunluysa açılır listede gösterilecek açıklama. */
  locationMessage: string | null;
  /** Seçili başlangıç Çankaya dışındaysa kutu uyarı rengine döner. */
  invalid?: boolean;
}

/** Yazmayı bıraktıktan sonra istek atmadan önce beklenen süre. */
const DEBOUNCE_MS = 300;

/** Sunucu 2 karakterden kısa sorguyu zaten reddediyor. */
const MIN_QUERY = 2;

export function RouteStartCombobox({
  value,
  onChange,
  onUseLiveLocation,
  locationStatus,
  locationMessage,
  invalid = false,
}: RouteStartComboboxProps) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<LocationSearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [searched, setSearched] = useState(false);

  const rootRef = useRef<HTMLDivElement | null>(null);
  const inputRef = useRef<HTMLInputElement | null>(null);
  const listId = useId();

  // ─── Yazdıkça arama (debounce + iptal) ───
  useEffect(() => {
    const trimmed = query.trim();
    if (trimmed.length < MIN_QUERY) {
      setResults([]);
      setSearched(false);
      setError(null);
      return;
    }

    const controller = new AbortController();
    const timer = setTimeout(async () => {
      setLoading(true);
      setError(null);
      try {
        // `api.get` seçenek almıyor; iptal için `apiFetch` doğrudan
        // kullanılıyor (RequestInit'i geçiriyor).
        const response = await apiFetch<LocationSearchResponse>(
          `/locations/search?q=${encodeURIComponent(trimmed)}&limit=6`,
          { signal: controller.signal },
        );
        if (controller.signal.aborted) return;
        setResults(response.items);
        setSearched(true);
      } catch (cause) {
        // İptal edilen istek hata değil: kullanıcı yazmaya devam etti.
        if (controller.signal.aborted) return;
        setResults([]);
        setError(describeSearchError(cause));
      } finally {
        if (!controller.signal.aborted) setLoading(false);
      }
    }, DEBOUNCE_MS);

    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [query]);

  // ─── Dışarı tıklayınca kapan ───
  useEffect(() => {
    if (!open) return;
    function onPointerDown(event: PointerEvent) {
      if (!rootRef.current?.contains(event.target as Node)) close();
    }
    document.addEventListener('pointerdown', onPointerDown);
    return () => document.removeEventListener('pointerdown', onPointerDown);
  }, [open]);

  function close() {
    setOpen(false);
    setQuery('');
    setResults([]);
    setSearched(false);
    setError(null);
  }

  function openList() {
    setOpen(true);
    // Odak kutuya gitsin ki kullanıcı ikinci kez tıklamadan yazabilsin.
    requestAnimationFrame(() => inputRef.current?.focus());
  }

  function chooseLive() {
    onUseLiveLocation();
    close();
  }

  function chooseAddress(result: LocationSearchResult) {
    // Dönüştürme `routeStart.ts`'te tek noktada duruyor — burada elle
    // kurmak ikinci bir kopya olurdu.
    onChange(startFromAddress(result));
    close();
  }

  const summary = value
    ? { primary: value.label, secondary: value.source === 'live' ? 'Canlı konumun' : 'Seçtiğin adres' }
    : { primary: 'Başlangıç seç', secondary: 'Canlı konumun ya da bir adres' };

  return (
    <div className="route-start-combo" ref={rootRef}>
      {/* Kapalı hâl: seçili başlangıcı gösteren düğme. Kullanıcı rotanın
          nereden kurulduğunu HER ZAMAN görür — sessiz bir varsayılan,
          yanlış yerden başlayan bir rotayı fark edilmez kılardı. */}
      {!open && (
        <button
          type="button"
          className={`route-start-trigger${invalid ? ' is-invalid' : ''}`}
          onClick={openList}
          aria-haspopup="listbox"
          aria-expanded={false}
        >
          <span className="route-start-icon" aria-hidden="true">
            {value?.source === 'address' ? '⌖' : '◎'}
          </span>
          <span className="route-start-body">
            <span className="route-start-label">{summary.primary}</span>
            <span className="muted route-start-kind">{summary.secondary}</span>
          </span>
          <span className="route-start-caret" aria-hidden="true">▾</span>
        </button>
      )}

      {open && (
        <div className="route-start-panel">
          <input
            ref={inputRef}
            className="route-start-input"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            onKeyDown={(event) => event.key === 'Escape' && close()}
            placeholder="Adres, mahalle veya yer ara"
            autoComplete="off"
            maxLength={200}
            role="combobox"
            aria-expanded
            aria-controls={listId}
            aria-autocomplete="list"
          />

          <ul className="route-start-options" id={listId} role="listbox">
            {/* Canlı konum HER ZAMAN en üstte — sorgu yazılmış olsa bile.
                Kullanıcı yanlış yazıp vazgeçtiğinde geri dönebileceği yer. */}
            <li>
              <button
                type="button"
                className={`route-start-option${value?.source === 'live' ? ' is-selected' : ''}`}
                onClick={chooseLive}
                role="option"
                aria-selected={value?.source === 'live'}
              >
                <span className="route-start-option-icon" aria-hidden="true">◎</span>
                <span className="route-start-option-body">
                  <span>Canlı konumum</span>
                  <span className="muted">
                    {locationStatus === 'locating'
                      ? 'Konum alınıyor…'
                      : locationStatus === 'ready'
                        ? 'Cihazının GPS konumu'
                        : 'Konumu al'}
                  </span>
                </span>
              </button>
            </li>

            {loading && (
              <li className="route-start-note muted" aria-live="polite">
                Aranıyor…
              </li>
            )}

            {error && (
              <li className="route-start-note route-start-note--error" role="alert">
                {error}
              </li>
            )}

            {!loading && !error && searched && results.length === 0 && (
              <li className="route-start-note muted">
                Çankaya sınırları içinde sonuç bulunamadı.
              </li>
            )}

            {results.map((result) => (
              <li key={result.id}>
                <button
                  type="button"
                  className="route-start-option"
                  onClick={() => chooseAddress(result)}
                  role="option"
                  aria-selected={false}
                >
                  <span className="route-start-option-icon" aria-hidden="true">⌖</span>
                  <span className="route-start-option-body">
                    <span>{result.label}</span>
                    <span className="muted">{KIND_LABELS[result.kind]}</span>
                  </span>
                </button>
              </li>
            ))}
          </ul>

          {/* İzin reddi kod ile geri açılamaz; ayarı nasıl açacağını burada
              anlatıyoruz ve adres alternatifi hemen üstünde duruyor. */}
          {locationMessage && (
            <p className="route-start-note muted">{locationMessage}</p>
          )}
        </div>
      )}
    </div>
  );
}

const KIND_LABELS = {
  neighborhood: 'Mahalle',
  address: 'Adres',
  place: 'Konum',
} as const;

function describeSearchError(cause: unknown): string {
  if (cause instanceof NetworkError) return 'Sunucuya ulaşılamadı.';
  if (cause instanceof ApiError && cause.problem.code === 'LOCATION_SEARCH_UNAVAILABLE') {
    return 'Adres arama servisi şu anda kullanılamıyor.';
  }
  // `code` VARSA `title` bizim `ApiProblem` yardımcımızdan gelen, kasıtlı
  // Türkçe bir metin. YOKSA (ASP.NET Core'un otomatik ürettiği beklenmeyen
  // bir hata) `title` çerçevenin İngilizce varsayılanı olabilir ("Not
  // Found" gibi) — göstermiyoruz.
  if (cause instanceof ApiError && cause.problem.code) return cause.problem.title;
  return 'Arama sırasında beklenmeyen bir hata oluştu.';
}
