import { useState, type FormEvent } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import type { MessageResponse } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { describeAuthError } from '@/features/auth/authFlow';
import { CodeInput } from '@/features/auth/ui/CodeInput';
import { useResendCooldown } from '@/features/auth/ui/useResendCooldown';

/**
 * Şifre sıfırlama — K-09.
 *
 * Tek sayfa, iki adım:
 *   1. e-posta gir  →  POST /auth/forgot-password  →  koda geç
 *   2. kod + yeni şifre  →  POST /auth/reset-password  →  girişe dön
 *
 * İki ayrı route yerine tek sayfa: 1. adımdan sonra kullanıcı e-postasını
 * açmak için sekme değiştiriyor; ayrı route olsaydı geri döndüğünde
 * hangi adresi yazdığını uygulama unutmuş olurdu.
 *
 * ⚠️ 1. adım hesap var olmasa bile başarılı görünür. Sunucu bilerek öyle
 * davranıyor — farklı yanıt vermek, bu formu "hangi e-postalar kayıtlı?"
 * sorusunu cevaplayan bir araca çevirirdi.
 */
export function ForgotPasswordPage() {
  const navigate = useNavigate();
  const location = useLocation();

  const [step, setStep] = useState<'email' | 'code'>('email');
  const [email, setEmail] = useState(
    (location.state as { email?: string } | null)?.email ?? '',
  );
  const [code, setCode] = useState('');
  const [password, setPassword] = useState('');
  const [passwordAgain, setPasswordAgain] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const { secondsLeft, start: startCooldown } = useResendCooldown();

  const mismatch = passwordAgain.length > 0 && password !== passwordAgain;

  async function requestCode(event?: FormEvent) {
    event?.preventDefault();
    setError(null);
    setInfo(null);

    if (email.trim() === '') {
      setError('E-posta adresinizi girin.');
      return;
    }

    setBusy(true);
    try {
      const result = await api.post<MessageResponse>(
        '/auth/forgot-password',
        { email: email.trim() },
        { skipAuth: true },
      );
      setInfo(result.message);
      setStep('code');
      startCooldown();
    } catch (err) {
      setError(describeAuthError(err));
    } finally {
      setBusy(false);
    }
  }

  async function submitNewPassword(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setInfo(null);

    if (code.length !== 6) {
      setError('Kod 6 haneli olmalı.');
      return;
    }
    if (password.length < 8) {
      setError('Yeni parola en az 8 karakter olmalı.');
      return;
    }
    if (password !== passwordAgain) {
      setError('Parolalar birbiriyle uyuşmuyor. İki alanı da kontrol edin.');
      return;
    }

    setBusy(true);
    try {
      await api.post<MessageResponse>(
        '/auth/reset-password',
        { email: email.trim(), code, newPassword: password },
        { skipAuth: true },
      );

      // Sunucu sıfırlamada TÜM refresh token'ları iptal ediyor; otomatik
      // oturum açmak yerine girişe yönlendirmek bu davranışla tutarlı.
      navigate('/auth/login', {
        replace: true,
        state: { notice: 'Şifreniz güncellendi. Yeni şifrenizle giriş yapabilirsiniz.' },
      });
    } catch (err) {
      setError(describeAuthError(err));
      setCode('');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="page auth-page">
      <h1>Şifremi unuttum</h1>

      {step === 'email' ? (
        <>
          <p className="muted">
            Hesabının e-posta adresini gir; 6 haneli bir sıfırlama kodu gönderelim.
          </p>

          <form className="form-card" onSubmit={requestCode} noValidate>
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

            <button className="btn-primary" type="submit" disabled={busy}>
              {busy ? 'Gönderiliyor…' : 'Sıfırlama kodu gönder'}
            </button>
          </form>
        </>
      ) : (
        <>
          <p className="muted">
            <strong>{email}</strong> adresine gelen kodu ve yeni parolanı gir.
          </p>

          <form className="form-card" onSubmit={submitNewPassword} noValidate>
            {error && <p className="form-error" role="alert">{error}</p>}
            {info && <p className="notice" role="status">{info}</p>}

            <CodeInput value={code} onChange={setCode} label="Sıfırlama kodu" />

            <label className="field">
              <span>Yeni parola <span className="muted">(en az 8 karakter)</span></span>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                autoComplete="new-password"
                required
              />
            </label>

            <label className="field">
              <span>Yeni parola (tekrar)</span>
              <input
                type="password"
                value={passwordAgain}
                onChange={(e) => setPasswordAgain(e.target.value)}
                autoComplete="new-password"
                required
                aria-invalid={mismatch}
              />
              {mismatch && (
                <span className="field-error" role="alert">Parolalar uyuşmuyor.</span>
              )}
              {!mismatch && passwordAgain.length > 0 && (
                <span className="field-ok">Parolalar eşleşiyor.</span>
              )}
            </label>

            <button className="btn-primary" type="submit" disabled={busy || mismatch}>
              {busy ? 'Kaydediliyor…' : 'Şifreyi güncelle'}
            </button>

            <button
              className="btn-secondary"
              type="button"
              onClick={() => requestCode()}
              disabled={busy || secondsLeft > 0}
            >
              {secondsLeft > 0 ? `Kodu tekrar gönder (${secondsLeft} sn)` : 'Kodu tekrar gönder'}
            </button>
          </form>
        </>
      )}

      <p className="muted">
        <Link to="/auth/login">Giriş ekranına dön</Link>
      </p>
    </section>
  );
}
