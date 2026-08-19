import { setupWorker } from 'msw/browser';
import { handlers } from '@/mocks/handlers';

export const worker = setupWorker(...handlers);

/**
 * MSW'yi başlatır. Yalnızca geliştirmede ve `USE_MOCKS` açıkken çağrılır.
 *
 * `onUnhandledRequest: 'bypass'` — tanımsız istekler gerçek ağa gider.
 * Böylece backend bir endpoint'i yayınladığında handler'ı silmek yeterli,
 * başka bir şey değiştirmeye gerek kalmaz.
 */
export async function startMockWorker(): Promise<void> {
  await worker.start({
    onUnhandledRequest: 'bypass',
    quiet: false,
  });
}
