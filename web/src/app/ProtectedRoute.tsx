import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuthStore } from '@/features/auth/authStore';

export function ProtectedRoute({
  children,
  allowGuest = false,
}: {
  children: ReactNode;
  allowGuest?: boolean;
}) {
  const status = useAuthStore((s) => s.status);
  const isGuest = useAuthStore((s) => s.isGuest);
  const location = useLocation();

  if (status === 'unknown') {
    return <div className="page-center">Yükleniyor…</div>;
  }

  if (status === 'anonymous') {
    if (allowGuest && isGuest) return <>{children}</>;

    return <Navigate to="/auth/login" replace state={{ from: location }} />;
  }

  return <>{children}</>;
}