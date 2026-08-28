import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuthStore } from '@/features/auth/authStore';

export function AdminRoute({ children }: { children: ReactNode }) {
  const status = useAuthStore((s) => s.status);
  const user = useAuthStore((s) => s.user);
  const location = useLocation();

  if (status === 'unknown') {
    return <div className="page-center">Yükleniyor…</div>;
  }

  if (status !== 'authenticated') {
    return <Navigate to="/auth/login" replace state={{ from: location }} />;
  }

  if (!user?.isAdmin) {
    return <Navigate to="/explore" replace />;
  }

  return <>{children}</>;
}