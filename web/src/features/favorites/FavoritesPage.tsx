import { FavoritesPanel } from '@/features/profile/FavoritesAndRoutesPanel';

export function FavoritesPage() {
  return (
    <section className="page favorites-page">
      <h1>Favorilerim</h1>
      <p className="muted favorites-page-intro">
        Beğendiğin konutları burada karşılaştırabilir, haritada açabilir veya favorilerinden
        çıkarabilirsin.
      </p>
      <FavoritesPanel />
    </section>
  );
}
