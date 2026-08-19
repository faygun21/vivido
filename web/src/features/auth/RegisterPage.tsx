/**
 * Kayıt sayfası — SAHİBİ: Kişi 1 · Hafta 1 Gün 2
 *
 * YAPILACAK:
 *   · e-posta + şifre (+ ad) formu
 *   · api.post<AuthResponse>('/auth/register', …)  → 201
 *   · başarılı → setSession → /onboarding
 *   · 409 + code === 'EMAIL_ALREADY_EXISTS' → "Bu e-posta zaten kayıtlı"
 *   · 400 → problem.errors içindeki alan hatalarını forma bas
 *
 * Sözleşme: vivido-api-sozlesmesi.md §4
 */
export function RegisterPage() {
  return (
    <section className="page">
      <h1>Kayıt ol</h1>
      <p className="muted">Bu ekran Hafta 1 Gün 2'de tamamlanacak.</p>
    </section>
  );
}
