import { Link } from 'react-router-dom';

export function NotFoundPage() {
  return (
    <section className="page">
      <h1>Sayfa bulunamadı</h1>
      <Link to="/">Ana sayfaya dön</Link>
    </section>
  );
}
