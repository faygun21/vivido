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
 */
export const router = createBrowserRouter([
  // ─── 1. BANNER (HEADER) OLMAYAN TAM EKRAN SAYFALAR ───
  { path: 'auth/login', element: <LoginPage /> },
  { path: 'auth/register', element: <RegisterPage /> },
  { path: 'auth/verify-email', element: <VerifyEmailPage /> },
  { path: 'auth/forgot-password', element: <ForgotPasswordPage /> },

  // ─── 2. BANNER (HEADER) OLAN İÇ SAYFALAR (RootLayout İçinde) ───
  {
    path: '/',
    element: <RootLayout />,
    children: [
      { index: true, element: <LandingPage /> },
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
<<<<<<< Updated upstream
      {
  path: 'properties',
  element: (
    <ProtectedRoute>
      <PropertiesMapView />
    </ProtectedRoute>
  ),
},
=======
>>>>>>> Stashed changes
      { path: '*', element: <NotFoundPage /> },
    ],
  },
]);