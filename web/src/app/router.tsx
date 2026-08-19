import { createBrowserRouter } from 'react-router-dom';
import { RootLayout } from '@/app/layout/RootLayout';
import { ProtectedRoute } from '@/app/ProtectedRoute';
import { LandingPage } from '@/features/landing/LandingPage';
import { LoginPage } from '@/features/auth/LoginPage';
import { RegisterPage } from '@/features/auth/RegisterPage';
import { OnboardingPage } from '@/features/onboarding/OnboardingPage';
import { ExplorePage } from '@/features/explore/ExplorePage';
import { ProfilePage } from '@/features/profile/ProfilePage';
import { NotFoundPage } from '@/features/NotFoundPage';

/**
 * Route tanımları — SAHİBİ: Kişi 1
 *
 * Yeni bir sayfa eklerken bu dosyaya satır eklemen gerekiyorsa
 * Kişi 1'e söyle. Dört kişi aynı anda buraya yazarsa çakışır.
 *
 * Hafta 2-3'te eklenecekler: /property/:id · /route/new · /routes
 */
export const router = createBrowserRouter([
  {
    path: '/',
    element: <RootLayout />,
    children: [
      { index: true, element: <LandingPage /> },

      { path: 'auth/login', element: <LoginPage /> },
      { path: 'auth/register', element: <RegisterPage /> },

      {
        path: 'onboarding',
        element: (
          <ProtectedRoute>
            <OnboardingPage />
          </ProtectedRoute>
        ),
      },
      {
        path: 'explore',
        element: (
          <ProtectedRoute>
            <ExplorePage />
          </ProtectedRoute>
        ),
      },
      {
        path: 'profile',
        element: (
          <ProtectedRoute>
            <ProfilePage />
          </ProtectedRoute>
        ),
      },

      { path: '*', element: <NotFoundPage /> },
    ],
  },
]);
