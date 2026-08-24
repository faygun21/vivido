import { useState, type FormEvent } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import type { AuthResponse } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';
import { describeAuthError, hasErrorCode, routeAfterAuth } from '@/features/auth/authFlow';

/**
 * Giriş sayfası — W1
 */
export function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const setSession = useAuthStore((s) => s.setSession);
  const clearSession = useAuthStore((s) => s.clearSession);
  const enterGuest = useAuthStore((s) => s.enterGuest);

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const state = location.state as
    | { from?: { pathname?: string }; notice?: string }
    | null;

  const from = state?.from?.pathname;
  const notice = state?.notice;

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setBusy(true);

    try {
      const auth = await api.post<AuthResponse>(
        '/auth/login',
        { email: email.trim(), password },
        { skipAuth: true },
      );
      setSession(auth);
      await routeAfterAuth(navigate, from);
    } catch (err) {
      if (hasErrorCode(err, 'EMAIL_NOT_VERIFIED')) {
        navigate('/auth/verify-email', { state: { email: email.trim() } });
        return;
      }
      setError(describeAuthError(err));
    } finally {
      setBusy(false);
    }
  }

  // Misafir olarak devam etme fonksiyonu
  function handleGuestContinue() {
    clearSession?.(); // Varsa önceki oturum kalıntılarını temizler
    navigate('/explore');
  }

  return (
    <div className="login-page-wrapper">
      {/* Sol Taraf: Video Alanı */}
      <div className="login-left">
        <div className="login-video-box">
          <video autoPlay loop muted playsInline>
            <source src="/video/vivido_giris_video.mp4" type="video/mp4" />
          </video>
        </div>
      </div>

      {/* Sağ Taraf: Giriş Formu */}
      <div className="login-right">
        <div className="login-form-container">
          {/* Logo */}
          <img
            src="/images/logo.svg"
            alt="Vivido Logo"
            className="login-logo"
          />

          <p className="login-slogan">hayalinizdeki eve giden yol</p>
          <div className="login-divider"></div>

          <h1 className="login-title">Giriş Yap</h1>

          <form className="login-form" onSubmit={handleSubmit} noValidate>
            {notice && <p className="notice" role="status">{notice}</p>}
            {error && <p className="form-error" role="alert">{error}</p>}

            {/* E-posta Input */}
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

            {/* Şifre Input */}
            <div className="login-input-group">
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Şifre"
                autoComplete="current-password"
                required
                className="login-input"
              />
              <span className="login-icon">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </span>
            </div>

            <Link to="/auth/forgot-password" state={{ email: email.trim() }} className="login-forgot">
              Şifremi unuttum
            </Link>

            <button type="submit" disabled={busy} className="login-submit">
              {busy ? 'Giriş yapılıyor…' : 'Giriş Yap'}
            </button>
          </form>

          <div className="login-or">
            <span>veya</span>
          </div>

          {/* Misafir Olarak Devam Et Butonu */}
{/* Misafir Olarak Devam Et Butonu */}
<button
  type="button"
  onClick={() => {
    enterGuest(); // 1. Korumalı rotaya "ben misafirim" diyoruz
    navigate('/explore'); // 2. İçeri giriyoruz
  }}
  className="login-guest-btn"
>
  Misafir olarak devam et
</button>

          <p className="login-register-text">
            Hesabın yok mu? <Link to="/auth/register">Kayıt ol</Link>
          </p>
        </div>
      </div>
    </div>
  );
}