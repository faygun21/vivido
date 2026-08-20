import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import type { AuthResponse } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';
import { describeAuthError, routeAfterAuth } from '@/features/auth/authFlow';

/**
 * Kayıt sayfası — W1
 *
 * K-B: register doğrudan token döner, kullanıcı ayrıca login olmaz.
 * Yeni kullanıcının profili yoktur → routeAfterAuth onu /onboarding'e atar.
 *
 * Sözleşme: vivido-api-sozlesmesi.md §4
 */
export function RegisterPage() {
  const navigate = useNavigate();
  const setSession = useAuthStore((s) => s.setSession);

  const [displayName, setDisplayName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);

    // Sunucu da doğruluyor (400 + errors), ama kullanıcıyı ağ turuna
    // sokmadan söylemek daha hızlı.
    if (password.length < 8) {
      setError('Parola en az 8 karakter olmalı.');
      return;
    }

    setBusy(true);
    try {
      const auth = await api.post<AuthResponse>(
        '/auth/register',
        {
          email,
          password,
          displayName: displayName.trim() === '' ? undefined : displayName.trim(),
        },
        { skipAuth: true },
      );
      setSession(auth);
      await routeAfterAuth(navigate);
    } catch (err) {
      setError(describeAuthError(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="page auth-page">
      <h1>Kayıt ol</h1>

      <form className="form-card" onSubmit={handleSubmit} noValidate>
        {error && <p className="form-error" role="alert">{error}</p>}

        <label className="field">
          <span>Ad <span className="muted">(isteğe bağlı)</span></span>
          <input
            type="text"
            value={displayName}
            onChange={(e) => setDisplayName(e.target.value)}
            autoComplete="name"
          />
        </label>

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
          <span>Parola <span className="muted">(en az 8 karakter)</span></span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="new-password"
            required
          />
        </label>

        <button className="btn-primary" type="submit" disabled={busy}>
          {busy ? 'Kaydediliyor…' : 'Kayıt ol'}
        </button>
      </form>

      <p className="muted">
        Zaten hesabın var mı? <Link to="/auth/login">Giriş yap</Link>
      </p>
    </section>
  );
}
