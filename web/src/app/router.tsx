import { createBrowserRouter, Navigate } from 'react-router-dom';
import { RootLayout } from '@/app/layout/RootLayout';
import { ProtectedRoute } from '@/app/ProtectedRoute';
import { LoginPage } from '@/features/auth/LoginPage';
import { RegisterPage } from '@/features/auth/RegisterPage';
import { VerifyEmailPage } from '@/features/auth/VerifyEmailPage';
import { ForgotPasswordPage } from '@/features/auth/ForgotPasswordPage';
import { OnboardingPage } from '@/features/onboarding/OnboardingPage';
import LifestyleSelection from "@/features/auth/LifestyleSelection";
import { ExplorePage } from '@/features/explore/ExplorePage';
import { ProfilePage } from '@/features/profile/ProfilePage';
import { NotFoundPage } from '@/features/NotFoundPage';
/**
 * Route tanımları — SAHİBİ: Kişi 1
 */
export const router = createBrowserRouter([
  // BANNER OLMAYAN TAM EKRAN SAYFALAR 
  { path: 'auth/login', element: <LoginPage /> },
  { path: 'auth/register', element: <RegisterPage /> },
  { path: 'auth/verify-email', element: <VerifyEmailPage /> },
  { path: 'auth/forgot-password', element: <ForgotPasswordPage /> },

  // BANNER OLAN İÇ SAYFALAR 
  {
    path: '/',
    element: <RootLayout />,
    children: [
      // Ana kök dizine gelenleri doğrudan giriş sayfasına yönlendiriyoruz
      { index: true, element: <Navigate to="/auth/login" replace /> },
      
      {
        path: 'lifestyle',
        element: (
          <ProtectedRoute>
            <LifestyleSelection />
          </ProtectedRoute>
        ),
      },
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
=======
      {
        path: 'properties',
        element: (
          <ProtectedRoute>
            <PropertiesMapView />
          </ProtectedRoute>
        ),
      },
>>>>>>> Stashed changes
      { path: '*', element: <NotFoundPage /> },
    ],
  },
]);