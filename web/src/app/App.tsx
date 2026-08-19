import { useEffect } from 'react';
import { RouterProvider } from 'react-router-dom';
import { AppProviders } from '@/app/providers';
import { router } from '@/app/router';
import { useAuthStore } from '@/features/auth/authStore';
import { setSessionExpiredHandler } from '@/shared/api/client';

export function App() {
  const clearSession = useAuthStore((s) => s.clearSession);

  // API istemcisi React'i tanımaz; oturum düştüğünde haber verebilmesi
  // için buradan bir geri çağırma bağlıyoruz.
  useEffect(() => {
    setSessionExpiredHandler(clearSession);
    return () => setSessionExpiredHandler(null);
  }, [clearSession]);

  return (
    <AppProviders>
      <RouterProvider router={router} />
    </AppProviders>
  );
}
