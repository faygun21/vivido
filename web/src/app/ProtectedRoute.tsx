import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuthStore } from '@/features/auth/authStore';

/**
 * Giriş gerektiren route'ları sarar.
 *
 * `status === 'unknown'` iken YÖNLENDİRME YAPMAZ — o sırada açılışta
 * refresh token'la oturum geri yükleniyor olabilir. Beklemeden login'e
 * atarsak, giriş yapmış kullanıcı her F5'te bir an login ekranı görür.
 */
export function ProtectedRoute({ children }: { children: ReactNode }) {
  const status = useAuthStore((s) => s.status);
  const location = useLocation();

  if (status === 'unknown') {
    return <div className="page-center">Yükleniyor…</div>;
  }

  if (status === 'anonymous') {
    // Nereye gitmek istediğini sakla — giriş sonrası oraya dönsün.
    return <Navigate to="/auth/login" replace state={{ from: location }} />;
  }

  return <>{children}</>;
}
