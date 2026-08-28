import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import type { AuthResponse } from '@vivido/shared';
import { ApiError, apiFetch } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';
import { describeAuthError } from '@/features/auth/authFlow';

export function RegisterPage() {
  const navigate = useNavigate();
  const setSession = useAuthStore((s) => s.setSession);
  const enterGuest = useAuthStore((s) => s.enterGuest);

  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [passwordAgain, setPasswordAgain] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const mismatch = passwordAgain.length > 0 && password !== passwordAgain;

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);

    // Sunucu da doğruluyor (400 + errors), ama kullanıcıyı ağ turuna
    // sokmadan söylemek daha hızlı.
 const hasUppercase = /[A-Z]/.test(password);
const hasLowercase = /[a-z]/.test(password);
const hasNumber = /\d/.test(password);
const hasSpecialCharacter = /[^A-Za-z0-9]/.test(password);

if (
  password.length < 8 ||
  !hasUppercase ||
  !hasLowercase ||
  !hasNumber ||
  !hasSpecialCharacter
) {
  setError(
    'Parola en az 8 karakter olmalı; büyük harf, küçük harf, rakam ve özel karakter içermeli.',
  );
  return;
}
    if (password !== passwordAgain) {
      setError('Parolalar birbiriyle uyuşmuyor.');
      return;
    }

    setBusy(true);
    try {
      const combinedName = `${firstName.trim()} ${lastName.trim()}`.trim();
      
      const { status, data } = await apiFetch<AuthResponse>(
        '/auth/register',
        {
          method: 'POST',
          body: {
            email: email.trim(),
            password,
            displayName: combinedName === '' ? undefined : combinedName,
          },
          skipAuth: true,
        },
        { withStatus: true },
      );

      if (status === 202) {
        navigate('/auth/verify-email', {
          replace: true,
          state: { email: email.trim() },
        });
        return;
      }

      setSession(data);
      // Kayıt başarılı olunca doğrudan yaşam tarzı seçimine yönlendiriyoruz
      navigate('/lifestyle', { replace: true });
    } catch (err) {
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
    <div className="login-page-wrapper">
      <div className="login-right">
        <div className="login-form-container">
          <img
            src="/images/logo.svg"
            alt="Vivido Logo"
            className="login-logo"
            style={{ height: '4.5rem', marginBottom: '0.25rem' }} 
          />

          <p className="login-slogan" style={{ margin: '0 0 0.5rem 0' }}>
            hayalinizdeki eve giden yol
          </p>
          <div className="login-divider" style={{ marginBottom: '1rem' }}></div>

          <h1 className="login-title" style={{ marginTop: '0', marginBottom: '1rem' }}>
            Kayıt Ol
          </h1>

          <form className="login-form" onSubmit={handleSubmit} noValidate>
            {error && <p className="form-error" role="alert">{error}</p>}

            <div className="login-name-row">
              <div className="login-input-group">
                <input
                  type="text"
                  value={firstName}
                  onChange={(e) => setFirstName(e.target.value)}
                  placeholder="Ad"
                  autoComplete="given-name"
                  className="login-input"
                />
              </div>
              <div className="login-input-group">
                <input
                  type="text"
                  value={lastName}
                  onChange={(e) => setLastName(e.target.value)}
                  placeholder="Soyad"
                  autoComplete="family-name"
                  className="login-input"
                />
              </div>
            </div>

            <div className="login-input-group">
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="E-posta adresi"
                autoComplete="email"
                required
                className="login-input"
              />
              <span className="login-icon">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
              </span>
            </div>

            <div className="login-input-group">
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Şifre"
                autoComplete="new-password"
                required
                className="login-input"
              />
              <span className="login-icon">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </span>
            </div>

            <div className="login-input-group">
              <input
                type="password"
                value={passwordAgain}
                onChange={(e) => setPasswordAgain(e.target.value)}
                placeholder="Şifre Tekrar"
                autoComplete="new-password"
                required
                className="login-input"
                style={mismatch ? { borderColor: '#b3261e' } : {}}
              />
              <span className="login-icon">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </span>
            </div>
            
            {mismatch && (
              <span style={{ color: '#b3261e', fontSize: '0.85rem', marginTop: '-0.5rem', fontWeight: 600 }}>
                Parolalar uyuşmuyor.
              </span>
            )}

            <button type="submit" disabled={busy || mismatch} className="login-submit">
              {busy ? 'Kaydediliyor…' : 'Kayıt Ol'}
            </button>
          </form>

          <div className="login-or" style={{ margin: '1rem 0' }}>
            <span>veya</span>
          </div>

          <button
            type="button"
            onClick={() => {
              enterGuest();
              navigate('/explore');
            }}
            className="login-guest-btn"
          >
            Misafir olarak devam et
          </button>

          <p className="login-register-text" style={{ marginTop: '1.25rem', marginBottom: '0' }}>
            Hesabın var mı? <Link to="/auth/login">Giriş Yap</Link>
          </p>
        </div>
      </div>

      <div className="login-left">
        <div className="login-video-box" style={{ backgroundColor: '#E27250' }}>
          <video autoPlay loop muted playsInline>
            <source src="/video/vivido_giris_video.mp4" type="video/mp4" />
          </video>
        </div>
      </div>
    </div>
  );
}