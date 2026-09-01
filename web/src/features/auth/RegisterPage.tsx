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
    /*
      Marka paneli SOLDA, form SAĞDA — giriş ekranıyla AYNI yerleşim.

      Önceden ters çevrilmişti: `.login-right` DOM'da önce geldiği için
      kayıt sayfasında form sola, video sağa düşüyordu. "Kayıt ol"a
      basan kullanıcı, ekranın iki yarısının yer değiştirdiğini
      görüyordu — aynı akışın iki adımı arasında mekânsal bağ kopuyor,
      geçiş "başka bir siteye gittim" gibi okunuyordu.
    */
    <div className="login-page-wrapper">
      <div className="login-left">
        <div className="login-video-box">
          <video autoPlay loop muted playsInline>
            <source src="/video/vivido_giris_video.mp4" type="video/mp4" />
          </video>
        </div>
      </div>

      <div className="login-right">
        {/* `--compact`: kayıt formunda dört alan var, girişte iki. Aynı
            dikey ritim kullanılırsa 700px'lik bir dizüstünde "Kayıt Ol"
            düğmesi ekranın altında kalıyor. Ölçüler satır içi `style`
            ile tek tek ezilmek yerine tek bir değiştirici sınıfta. */}
        <div className="login-form-container login-form-container--compact">
          {/* Marka kilidi — giriş ekranıyla birebir aynı; `alt=""` gerekçesi
              için bkz. `LoginPage`. */}
          <img src="/images/logo.svg" alt="" className="login-logo" />

          <p className="login-wordmark">Vivido</p>
          <p className="login-slogan">hayalinizdeki eve giden yol</p>
          <div className="login-divider" />

          <h1 className="login-title">Kayıt Ol</h1>

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
                className={`login-input${mismatch ? ' is-invalid' : ''}`}
                aria-invalid={mismatch}
                aria-describedby={mismatch ? 'password-mismatch' : undefined}
              />
              <span className="login-icon">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </span>
            </div>
            
            {/* `role="alert"` DEĞİL: bu satır kullanıcı yazarken her
                tuşta yeniden değerlendiriliyor; `alert` ekran
                okuyucuyu her seferinde sözünü keserek uyarır.
                `aria-live="polite"` yazmayı bitirince okur. */}
            {mismatch && (
              <span
                id="password-mismatch"
                className="login-field-error"
                aria-live="polite"
              >
                Parolalar uyuşmuyor.
              </span>
            )}

            <button type="submit" disabled={busy || mismatch} className="login-submit">
              {busy ? 'Kaydediliyor…' : 'Kayıt Ol'}
            </button>
          </form>

          <div className="login-or">
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

          <p className="login-register-text">
            Hesabın var mı? <Link to="/auth/login">Giriş Yap</Link>
          </p>
        </div>
      </div>
    </div>
  );
}