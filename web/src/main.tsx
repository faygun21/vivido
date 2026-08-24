import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from '@/app/App'
import { bootstrapSession } from '@/shared/api/client'
import { useAuthStore } from '@/features/auth/authStore'
import './index.css'

async function main() {
  // MSW ilk çağrıdan ÖNCE ayakta olmalı — aksi halde açılıştaki
  // /auth/refresh isteği gerçek ağa gider ve backend yokken hata verir.
  //
  // Koşul BİLEREK satır içi: `import.meta.env.DEV` burada doğrudan yazılınca
  // Vite üretim derlemesinde `false` ile değiştirip tüm dalı eler; MSW'nin
  // ~420 kB'lık parçası çıktıya hiç girmez. Bunu ayrı bir modülden okunan
  // sabite bağlarsak eleme çalışmıyor.
  if (import.meta.env.DEV && import.meta.env.VITE_USE_MOCKS !== 'false') {
    const { startMockWorker } = await import('@/mocks/browser')
    await startMockWorker()
  } else if (import.meta.env.DEV && 'serviceWorker' in navigator) {
    // Daha önce MSW ile çalıştırılmış tarayıcılarda kalan worker gerçek API
    // isteklerini yakalamaya devam edebilir. Mock kapalıyken yalnızca MSW
    // worker'ını kaldır; uygulamaya ait başka worker'lara dokunma.
    const registrations = await navigator.serviceWorker.getRegistrations()
    await Promise.all(
      registrations
        .filter(({ active, installing, waiting }) =>
          [active, installing, waiting].some((worker) =>
            worker?.scriptURL.endsWith('/mockServiceWorker.js'),
          ),
        )
        .map((registration) => registration.unregister()),
    )
  }

  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <App />
    </StrictMode>,
  )

  // Oturumu ARKA PLANDA geri yükle — ilk boyamayı bekletme.
  // Bu sırada authStore.status === 'unknown', ProtectedRoute bekletir.
  void bootstrapSession().then((auth) => {
    const store = useAuthStore.getState()
    if (auth) store.setSession(auth)
    else store.markAnonymous()
  })
}

void main()
