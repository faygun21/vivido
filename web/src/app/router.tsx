import { createBrowserRouter, Navigate } from 'react-router-dom';
import { RootLayout } from '@/app/layout/RootLayout';
import { ProtectedRoute } from '@/app/ProtectedRoute';
import { LoginPage } from '@/features/auth/LoginPage';
import { RegisterPage } from '@/features/auth/RegisterPage';
import { VerifyEmailPage } from '@/features/auth/VerifyEmailPage';
import { ForgotPasswordPage } from '@/features/auth/ForgotPasswordPage';
import { OnboardingPage } from '@/features/onboarding/OnboardingPage';
import LifestyleSelection from "@/features/auth/LifestyleSelection";
import PreferencesRanking from "@/features/auth/PreferencesRanking";
import BudgetSelection from "@/features/auth/BudgetSelection";
import { ExplorePage } from '@/features/explore/ExplorePage';
import { ProfilePage } from '@/features/profile/ProfilePage';
import { FavoritesPage } from '@/features/favorites/FavoritesPage';
import { NotFoundPage } from '@/features/NotFoundPage';

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
        path: 'preferences',
        element: (
          <ProtectedRoute>
            <PreferencesRanking />
          </ProtectedRoute>
        ),
      },
      {
        path: 'budget',
        element: (
          <ProtectedRoute>
            <BudgetSelection />
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
        path: 'favorites',
        element: (
          <ProtectedRoute>
            <FavoritesPage />
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
