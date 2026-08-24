import { useState, type ReactNode } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ApiError } from '@/shared/api/client';
import { SessionCacheSync } from '@/app/SessionCacheSync';

/**
 * Uygulama genelindeki provider'lar — SAHİBİ: Kişi 1
 */
export function AppProviders({ children }: { children: ReactNode }) {
  // QueryClient bileşen dışında yaratılırsa testlerde örnekler arasında
  // önbellek sızar. useState ile bileşen ömrüne bağlıyoruz.
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 30_000,
            retry: (failureCount, error) => {
              // 4xx'i tekrar denemek anlamsız — istek zaten geçersiz.
              // Yalnızca sunucu/ağ hatalarında tekrar dene.
              if (error instanceof ApiError && error.status < 500) return false;
              return failureCount < 2;
            },
          },
        },
      }),
  );

  return (
    <QueryClientProvider client={queryClient}>
      {/* Oturum kimliği değişince önbelleği boşaltır — çocuklardan ÖNCE
          bağlanması şart, aksi halde ilk kimlik geçişini kaçırır. */}
      <SessionCacheSync />
      {children}
    </QueryClientProvider>
  );
}
