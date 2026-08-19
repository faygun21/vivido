import { AnchorPanel } from '@/features/anchors/AnchorPanel';

/**
 * Profil yönetimi — persona, bütçe, anchor'lar.
 *
 * Onboarding'den farkı: burada adım adım akış yok, hepsi tek sayfada
 * düzenlenebilir. Anchor kısmı yine Kişi 3'ün bileşeni.
 */
export function ProfilePage() {
  return (
    <section className="page">
      <h1>Profil</h1>
      <p className="muted">Persona ve bütçe düzenleme Hafta 1'de gelecek.</p>

      <AnchorPanel />
    </section>
  );
}
