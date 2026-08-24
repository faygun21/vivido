import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import type { AuthResponse } from '@vivido/shared';
import { ApiError, apiFetch } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';
import { describeAuthError, routeAfterAuth } from '@/features/auth/authFlow';

/**
 * Kayıt sayfası — W1
 *
 * İki olası sonuç var (K-09):
 *   · 202  →  e-posta doğrulama zorunlu. Token GELMEZ; kullanıcı
 *             /auth/verify-email ekranına gider ve 6 haneli kodu girer.
 *   · 201  →  doğrulama kapalı (Auth:RequireEmailVerification=false).
 *             Eski davranış: token gelir, doğrudan onboarding'e gidilir.
 *
 * Sözleşme: vivido-api-sozlesmesi.md §4
 */
export function RegisterPage() {
  const navigate = useNavigate();
  const setSession = useAuthStore((s) => s.setSession);

  const [displayName, setDisplayName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [passwordAgain, setPasswordAgain] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // Kullanıcı ikinci alana yazmaya BAŞLADIKTAN sonra uyarıyoruz. İlk
  // karakterde "şifreler uyuşmuyor" basmak, henüz yazarken hata gösterip
  // formu suçlayıcı yapıyor.
  const mismatch = passwordAgain.length > 0 && password !== passwordAgain;

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);

    // Sunucu da doğruluyor (400 + errors), ama kullanıcıyı ağ turuna
    // sokmadan söylemek daha hızlı.
    if (password.length < 8) {
      setError('Parola en az 8 karakter olmalı.');
      return;
    }
    if (password !== passwordAgain) {
      setError('Parolalar birbiriyle uyuşmuyor. İki alanı da kontrol edin.');
      return;
    }

    setBusy(true);
    try {
      // `apiFetch` doğrudan çağrılıyor (api.post değil): 201 ile 202'yi
      // ayırmak için durum koduna ihtiyacımız var.
      const { status, data } = await apiFetch<AuthResponse>(
        '/auth/register',
        {
          method: 'POST',
          body: {
            email: email.trim(),
            password,
            displayName: displayName.trim() === '' ? undefined : displayName.trim(),
          },
          skipAuth: true,
        },
        { withStatus: true },
      );

      if (status === 202) {
        // Doğrulama bekleniyor — e-postayı bir sonraki ekrana taşı ki
        // kullanıcı adresini ikinci kez yazmak zorunda kalmasın.
        navigate('/auth/verify-email', {
          replace: true,
          state: { email: email.trim() },
        });
        return;
      }

      setSession(data);
      await routeAfterAuth(navigate);
    } catch (err) {
      // Zaten kayıtlı ama doğrulanmamış bir hesap 409 DEĞİL 202 döner,
      // yani buraya düşen 409 gerçekten "bu hesap aktif" demektir.
      if (err instanceof ApiError && err.problem.code === 'EMAIL_ALREADY_EXISTS') {
        setError('Bu e-posta zaten kayıtlı. Giriş yapın ya da şifrenizi sıfırlayın.');
      } else {
        setError(describeAuthError(err));
      }
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
          <span className="field-hint">
            Doğrulama kodu bu adrese gönderilecek — erişebildiğiniz bir adres girin.
          </span>
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

        <label className="field">
          <span>Parola (tekrar)</span>
          <input
            type="password"
            value={passwordAgain}
            onChange={(e) => setPasswordAgain(e.target.value)}
            autoComplete="new-password"
            required
            aria-invalid={mismatch}
            aria-describedby={mismatch ? 'parola-uyusmazlik' : undefined}
          />
          {mismatch && (
            <span className="field-error" id="parola-uyusmazlik" role="alert">
              Parolalar uyuşmuyor.
            </span>
          )}
          {!mismatch && passwordAgain.length > 0 && (
            <span className="field-ok">Parolalar eşleşiyor.</span>
          )}
        </label>

        <button className="btn-primary" type="submit" disabled={busy || mismatch}>
          {busy ? 'Kaydediliyor…' : 'Kayıt ol'}
        </button>
      </form>

      <p className="muted">
        Zaten hesabın var mı? <Link to="/auth/login">Giriş yap</Link>
      </p>
    </section>
  );
}
