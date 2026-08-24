import { useEffect, useState, type FormEvent } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import type { AuthResponse, MessageResponse } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';
import { describeAuthError, routeAfterAuth } from '@/features/auth/authFlow';
import { CodeInput } from '@/features/auth/ui/CodeInput';
import { useResendCooldown } from '@/features/auth/ui/useResendCooldown';

/**
 * E-posta doğrulama — K-09.
 *
 * Buraya iki yoldan gelinir:
 *   · kayıt 202 döndüğünde (RegisterPage `state.email` ile yönlendirir)
 *   · doğrulanmamış hesapla giriş denendiğinde (403 EMAIL_NOT_VERIFIED)
 *
 * Kod doğrulanınca sunucu token DÖNER — kullanıcı ayrıca giriş yapmaz.
 */
export function VerifyEmailPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const setSession = useAuthStore((s) => s.setSession);

  const passedEmail = (location.state as { email?: string } | null)?.email ?? '';

  const [email, setEmail] = useState(passedEmail);
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const { secondsLeft, start: startCooldown } = useResendCooldown();

  // Kayıttan yeni geldiyse ilk mesajı biz veriyoruz; kullanıcı boş bir
  // ekranda "şimdi ne olacak?" diye kalmasın.
  useEffect(() => {
    if (passedEmail) {
      setInfo(`${passedEmail} adresine 6 haneli bir kod gönderdik. Kod 15 dakika geçerli.`);
      startCooldown();
    }
  }, [passedEmail, startCooldown]);

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setInfo(null);

    if (code.length !== 6) {
      setError('Kod 6 haneli olmalı.');
      return;
    }

    setBusy(true);
    try {
      const auth = await api.post<AuthResponse>(
        '/auth/verify-email',
        { email: email.trim(), code },
        { skipAuth: true },
      );
      setSession(auth);
      // Yeni doğrulanmış kullanıcının profili yok → onboarding'e düşer.
      await routeAfterAuth(navigate);
    } catch (err) {
      setError(describeAuthError(err));
      setCode('');
    } finally {
      setBusy(false);
    }
  }

  async function handleResend() {
    setError(null);
    setInfo(null);
    setBusy(true);
    try {
      const result = await api.post<MessageResponse>(
        '/auth/resend-verification',
        { email: email.trim() },
        { skipAuth: true },
      );
      setInfo(result.message);
      startCooldown();
    } catch (err) {
      setError(describeAuthError(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="page auth-page">
      <h1>E-postanı doğrula</h1>
      <p className="muted">
        Adresine gönderdiğimiz 6 haneli kodu gir. Kod gelmediyse spam
        klasörüne de bak.
      </p>

      <form className="form-card" onSubmit={handleSubmit} noValidate>
        {error && <p className="form-error" role="alert">{error}</p>}
        {info && <p className="notice" role="status">{info}</p>}

        <label className="field">
          <span>E-posta</span>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
            required
            // Kayıttan gelen adres doğru olan; değiştirilmesi neredeyse her
            // zaman hatadır ama tamamen kilitlemek yazım hatasını çaresiz
            // bırakır. Salt okunur değil, sadece vurgusuz.
          />
        </label>

        <CodeInput value={code} onChange={setCode} label="Doğrulama kodu" />

        <button className="btn-primary" type="submit" disabled={busy || code.length !== 6}>
          {busy ? 'Doğrulanıyor…' : 'Doğrula ve devam et'}
        </button>

        <button
          className="btn-secondary"
          type="button"
          onClick={handleResend}
          disabled={busy || secondsLeft > 0 || email.trim() === ''}
        >
          {secondsLeft > 0 ? `Kodu tekrar gönder (${secondsLeft} sn)` : 'Kodu tekrar gönder'}
        </button>
      </form>

      <p className="muted">
        Yanlış adres mi girdin? <Link to="/auth/register">Baştan kayıt ol</Link>
        {' · '}
        <Link to="/auth/login">Giriş yap</Link>
      </p>
    </section>
  );
}
