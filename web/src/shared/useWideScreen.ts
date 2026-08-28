import { useEffect, useState } from 'react';

/**
 * Explore çekmecesinin masaüstü/mobil eşiği — `index.css`'teki
 * `@media (max-width: 899px)` ile birebir aynı sınır (900px eşiğin altı
 * dar sayılıyor). Panellerin masaüstünde yan panel mi, mobilde alttan
 * açılan sayfa mı davranacağını JS tarafında bilmek gerektiğinde kullanılır
 * (ör. konut detay panelinin sürüklenebilir olması sadece mobilde anlamlı).
 */
export const WIDE_SCREEN = '(min-width: 900px)';

export function matchesWide(): boolean {
  return typeof window !== 'undefined' && window.matchMedia(WIDE_SCREEN).matches;
}

export function useWideScreen(): boolean {
  const [wide, setWide] = useState(matchesWide);

  useEffect(() => {
    const query = window.matchMedia(WIDE_SCREEN);
    const onChange = (event: MediaQueryListEvent) => setWide(event.matches);
    query.addEventListener('change', onChange);
    return () => query.removeEventListener('change', onChange);
  }, []);

  return wide;
}
