import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import type { Persona, UserProfile } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { AnchorPanel } from '@/features/anchors/AnchorPanel';

/**
 * Profil yönetimi — persona/bütçe özeti + anchor paneli.
 *
 * Anchor paneli hem burada hem onboarding'in 3. adımında kullanılıyor;
 * bileşen kendi kendine yettiği için iki yerde de aynı kod çalışıyor.
 */
export function ProfilePage() {
  const { data: profile, isLoading } = useQuery({
    queryKey: ['profile'],
    queryFn: () => api.get<UserProfile>('/profile'),
    retry: false,
  });

  const { data: personas = [] } = useQuery({
    queryKey: ['personas'],
    queryFn: () => api.get<Persona[]>('/personas'),
  });

  const persona = personas.find((p) => p.code === profile?.personaCode);

  return (
    <section className="page">
      <h1>Profil</h1>

      <div className="info-card">
        <h2>Persona ve bütçe</h2>
        {isLoading ? (
          <p className="muted">Yükleniyor…</p>
        ) : profile ? (
          <>
            <dl className="kv">
              <dt>Persona</dt>
              <dd>{persona?.displayNameTr ?? profile.personaCode}</dd>
              <dt>Aylık bütçe</dt>
              <dd>
                {profile.monthlyBudget != null
                  ? `${profile.monthlyBudget.toLocaleString('tr-TR')} ₺`
                  : 'Girilmedi'}
              </dd>
            </dl>
            {persona && <p className="muted">{persona.descriptionTr}</p>}
          </>
        ) : (
          <p className="muted">
            Profil bulunamadı. <Link to="/onboarding">Onboarding'i tamamla</Link>
          </p>
        )}
        <Link className="btn-secondary" to="/onboarding">
          Persona / bütçe değiştir
        </Link>
      </div>

      <AnchorPanel />
    </section>
  );
}
