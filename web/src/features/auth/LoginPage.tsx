import { useState, type FormEvent } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import type { AuthResponse } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';
import { describeAuthError, routeAfterAuth } from '@/features/auth/authFlow';

/**
 * Giriş sayfası — W1
 *
 * Giriş sonrası yönlendirme K-C'ye dayanır:
 *   GET /profile → 404  →  /onboarding   (persona henüz seçilmemiş)
 *                 → 200  →  /explore
 *
 * Sözleşme: vivido-api-sozlesmesi.md §4
 */
export function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const setSession = useAuthStore((s) => s.setSession);

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // ProtectedRoute nereden geldiğimizi state'e koyuyor; giriş sonrası
  // kullanıcıyı gitmek istediği yere geri gönderelim.
  const from = (location.state as { from?: { pathname?: string } } | null)?.from?.pathname;

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setBusy(true);

    try {
      // skipAuth: /auth/login'den gelen 401 "şifre yanlış" demektir,
      // "token eskidi" değil — yenileme akışı tetiklenmemeli.
      const auth = await api.post<AuthResponse>(
        '/auth/login',
        { email, password },
        { skipAuth: true },
      );
      setSession(auth);
      await routeAfterAuth(navigate, from);
    } catch (err) {
      setError(describeAuthError(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="page auth-page">
      <h1>Giriş yap</h1>

      <form className="form-card" onSubmit={handleSubmit} noValidate>
        {error && <p className="form-error" role="alert">{error}</p>}

        <label className="field">
          <span>E-posta</span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
            required
          />
        </label>

        <label className="field">
          <span>Parola</span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
          />
        </label>

        <button className="btn-primary" type="submit" disabled={busy}>
          {busy ? 'Giriş yapılıyor…' : 'Giriş yap'}
        </button>
      </form>

      <p className="muted">
        Hesabın yok mu? <Link to="/auth/register">Kayıt ol</Link>
      </p>
    </section>
  );
}
