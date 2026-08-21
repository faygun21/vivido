import { useCallback, useEffect, useRef, useState } from 'react';

/**
 * "Kodu tekrar gönder" düğmesinin geri sayımı.
 *
 * Sunucu da soğuma süresini zorluyor (429 `RESEND_TOO_SOON`); buradaki
 * sayaç sadece kullanıcıya ne kadar beklemesi gerektiğini gösteriyor.
 * İstemci tarafı doğrulama güvenlik değil, nezakettir.
 */
const DEFAULT_COOLDOWN_SECONDS = 60;

export function useResendCooldown(seconds: number = DEFAULT_COOLDOWN_SECONDS) {
  const [secondsLeft, setSecondsLeft] = useState(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const stop = useCallback(() => {
    if (timerRef.current !== null) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  const start = useCallback(() => {
    stop();
    setSecondsLeft(seconds);
    timerRef.current = setInterval(() => {
      setSecondsLeft((left) => {
        if (left <= 1) {
          stop();
          return 0;
        }
        return left - 1;
      });
    }, 1000);
  }, [seconds, stop]);

  // Bileşen kaldırıldığında interval'i bırakmazsak React her saniye
  // ölü bir bileşene setState çağırmayı dener.
  useEffect(() => stop, [stop]);

  return { secondsLeft, start };
}
