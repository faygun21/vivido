/**
 * Giriş sayfası — SAHİBİ: Kişi 1 · Hafta 1 Gün 2
 *
 * YAPILACAK:
 *   · e-posta + şifre formu, alan doğrulama
 *   · api.post<AuthResponse>('/auth/login', { email, password })
 *   · başarılı → useAuthStore.setSession(auth)
 *   · 401 + code === 'INVALID_CREDENTIALS' → "E-posta veya şifre hatalı"
 *   · giriş sonrası: GET /profile → 404 ise /onboarding, 200 ise /explore
 *   · location.state.from varsa oraya dön
 *
 * Sözleşme: vivido-api-sozlesmesi.md §4
 * Kabul kriteri: docs/00-KAPSAM.md → W1
 */
export function LoginPage() {
  return (
    <section className="page">
      <h1>Giriş yap</h1>
      <p className="muted">Bu ekran Hafta 1 Gün 2'de tamamlanacak.</p>
    </section>
  );
}
