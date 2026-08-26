import { Link } from 'react-router-dom';
import type { Persona, UserProfile } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { AnchorPanel } from '@/features/anchors/AnchorPanel';
import { RoutesPanel } from './FavoritesAndRoutesPanel';

/**
 * Profil yönetimi — persona/kira aralığı özeti + anchor paneli.
 *
 * Anchor paneli hem burada hem onboarding'in 3. adımında kullanılıyor;
 * bileşen kendi kendine yettiği için iki yerde de aynı kod çalışıyor.
 */
export function ProfilePage() {
  const { data: profile, isLoading } = useSessionQuery({
    queryKey: ['profile'],
    queryFn: () => api.get<UserProfile>('/profile'),
    retry: false,
  });

  const { data: personas = [] } = useSessionQuery({
    queryKey: ['personas'],
    queryFn: () => api.get<Persona[]>('/personas'),
  });

  const persona = personas.find((p) => p.code === profile?.personaCode);

  function formatBudgetRange(
    minMonthlyBudget: number | null,
    maxMonthlyBudget: number | null,
  ) {
    if (minMonthlyBudget != null && maxMonthlyBudget != null) {
      return `${minMonthlyBudget.toLocaleString('tr-TR')} ₺ - ${maxMonthlyBudget.toLocaleString('tr-TR')} ₺`;
    }

    if (minMonthlyBudget != null) {
      return `${minMonthlyBudget.toLocaleString('tr-TR')} ₺ ve üzeri`;
    }

    if (maxMonthlyBudget != null) {
      return `${maxMonthlyBudget.toLocaleString('tr-TR')} ₺'ye kadar`;
    }

    return 'Girilmedi';
  }

  return (
    <section className="page">
      <h1>Profil</h1>

      <div className="info-card">
        <h2>Persona ve kira aralığı</h2>

        {isLoading ? (
          <p className="muted">Yükleniyor…</p>
        ) : profile ? (
          <>
            <dl className="kv">
              <dt>Persona</dt>
              <dd>{persona?.displayNameTr ?? profile.personaCode}</dd>

              <dt>Aylık kira aralığı</dt>
              <dd>
                {formatBudgetRange(
                  profile.minMonthlyBudget,
                  profile.maxMonthlyBudget,
                )}
              </dd>
            </dl>

            {persona && (
              <p className="muted">{persona.descriptionTr}</p>
            )}
          </>
        ) : (
          <p className="muted">
            Profil bulunamadı.{' '}
            <Link to="/onboarding">
              Onboarding&apos;i tamamla
            </Link>
          </p>
        )}

        <Link className="btn-secondary" to="/onboarding">
          Persona / kira aralığı değiştir
        </Link>
      </div>

      <AnchorPanel />

      {/* R-97 gereksinimi için yazdığımız favoriler ve rotalar paneli */}
      <div style={{ marginTop: '2rem' }}>
        <RoutesPanel />
      </div>
    </section>
  );
}
