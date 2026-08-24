import { createBrowserRouter } from 'react-router-dom';
import { RootLayout } from '@/app/layout/RootLayout';
import { ProtectedRoute } from '@/app/ProtectedRoute';
import { LandingPage } from '@/features/landing/LandingPage';
import { LoginPage } from '@/features/auth/LoginPage';
import { RegisterPage } from '@/features/auth/RegisterPage';
import { VerifyEmailPage } from '@/features/auth/VerifyEmailPage';
import { ForgotPasswordPage } from '@/features/auth/ForgotPasswordPage';
import { OnboardingPage } from '@/features/onboarding/OnboardingPage';
import { ExplorePage } from '@/features/explore/ExplorePage';
import { ProfilePage } from '@/features/profile/ProfilePage';
import { NotFoundPage } from '@/features/NotFoundPage';
import { PropertiesMapView } from '@/features/properties/PropertiesMapView'; 
/**
 * Route tanımları — SAHİBİ: Kişi 1
 *
 * Yeni bir sayfa eklerken bu dosyaya satır eklemen gerekiyorsa
 * Kişi 1'e söyle. Dört kişi aynı anda buraya yazarsa çakışır.
 *
 * Hafta 2-3'te eklenecekler: /property/:id · /route/new · /routes
 *
 * ⭐ `allowGuest` (K-09 / W0): "misafir olarak devam et" diyen ziyaretçi
 * yalnızca `/explore`'a girebilir. Persona seçimi (`/onboarding`), profil
 * ve anchor yönetimi kayıt ister — bu sayfalar misafiri giriş ekranına atar.
 */
export const router = createBrowserRouter([
  {
    path: '/',
    element: <RootLayout />,
    children: [
      { index: true, element: <LandingPage /> },

      { path: 'auth/login', element: <LoginPage /> },
      { path: 'auth/register', element: <RegisterPage /> },
      { path: 'auth/verify-email', element: <VerifyEmailPage /> },
      { path: 'auth/forgot-password', element: <ForgotPasswordPage /> },

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
          <ProtectedRoute allowGuest>
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
      {
  path: 'properties',
  element: (
    <ProtectedRoute>
      <PropertiesMapView />
    </ProtectedRoute>
  ),
},
      { path: '*', element: <NotFoundPage /> },
    ],
  },
]);
