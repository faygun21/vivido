import { useEffect, useState } from 'react';
import { Check, ArrowRight } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useQueryClient } from '@tanstack/react-query';
import { ApiError, api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { useAuthStore } from '@/features/auth/authStore';
import { WizardSteps } from '@/features/auth/ui/WizardSteps';
import { personaVisual } from '@/shared/persona/personaVisuals';
import type { UserProfile } from '@vivido/shared';

/**
 * Sihirbazın 2. adımındaki dört persona.
 *
 * ⚠️ Başlık ve açıklama BURADA sabit — `OnboardingPage` aynı bilgiyi
 * `GET /personas` ile veritabanından çekiyor. İki kaynak ayrışabilir;
 * bu bilinen bir borç ve sözleşme değişirse burası da güncellenmeli.
 * İkonlar ise artık ortak: `@/shared/persona/personaVisuals`.
 */
interface WizardPersona {
  id: string;
  title: string;
  description: string;
}

const personas: WizardPersona[] = [
  {
    id: 'student',
    title: 'Öğrenci',
    description: 'Ulaşım, üniversite ve sosyal yaşam öncelikli',
  },
  {
    id: 'remote_worker',
    title: 'Uzaktan Çalışan',
    description: 'Cafe, spor ve sosyal alanlar öncelikli',
  },
  {
    id: 'family_kids',
    title: 'Çocuklu Aile',
    description: 'Eğitim, market ve park alanları öncelikli',
  },
  {
    id: 'elderly',
    title: 'Emekli',
    description: 'Sağlık, günlük ihtiyaçlar ve sakin yaşam öncelikli',
  },
];

function splitDisplayName(displayName: string | null | undefined): {
  firstName: string;
  lastName: string;
} {
  const trimmed = (displayName ?? '').trim();
  if (trimmed === '') return { firstName: '', lastName: '' };

  const spaceIndex = trimmed.indexOf(' ');
  if (spaceIndex === -1) return { firstName: trimmed, lastName: '' };

  return {
    firstName: trimmed.slice(0, spaceIndex),
    lastName: trimmed.slice(spaceIndex + 1).trim(),
  };
}

export default function LifestyleSelection() {
  const [selectedId, setSelectedId] = useState<string>('remote_worker');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const displayName = useAuthStore((s) => s.user?.displayName);

  // Sihirbaz daha önce yarıda bırakıldıysa (bkz. ExplorePage'deki
  // "profil var ama bütçe hâlâ boş" yönlendirmesi) kullanıcı buraya GERİ
  // gönderilebiliyor — o zaman burada daha önce seçtiği persona sessizce
  // 'remote_worker' varsayılanına dönmemeli. `PreferencesRanking` ve
  // `BudgetSelection` zaten bu deseni kullanıyor, burada eksikti.
  const { data: savedProfile } = useSessionQuery({
    queryKey: ['profile'],
    queryFn: async (): Promise<UserProfile | null> => {
      try {
        return await api.get<UserProfile>('/profile');
      } catch (err) {
        if (err instanceof ApiError && err.problem.code === 'PROFILE_NOT_FOUND') {
          return null;
        }
        throw err;
      }
    },
    retry: false,
  });

  useEffect(() => {
    if (savedProfile?.personaCode) setSelectedId(savedProfile.personaCode);
  }, [savedProfile]);

  async function handleNext() {
    setSaving(true);
    setError(null);
    try {
      const { firstName, lastName } = splitDisplayName(displayName);
      await api.put('/profile', {
        firstName,
        lastName,
        personaCode: selectedId,
      });
      await queryClient.invalidateQueries({ queryKey: ['profile'] });
      // Persona değişince skorlar da değişir — /properties (map/top/detail)
      // aynı sorgu anahtarı önekini paylaşıyor, tek çağrı hepsini kapsıyor.
      await queryClient.invalidateQueries({ queryKey: ['properties'] });
      navigate('/preferences');
    } catch {
      setError('Kaydedilemedi, lütfen tekrar deneyin.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="wizard-shell">
      <WizardSteps current={2} />

      <div className="wizard-body">
        <h1 className="wizard-title">Seni biraz tanıyalım</h1>
        <p className="wizard-subtitle">
          Yaşam tarzına en yakın profili seç. Tüm tercihlerini daha sonra
          özelleştirebilirsin.
        </p>

        {/*
          Kartlar artık `<div onClick>` DEĞİL gerçek `<button>`. Öncesinde
          klavyeyle seçilemiyor, Tab sırasına hiç girmiyor ve ekran
          okuyucuya tıklanabilir olduklarını söylemiyorlardı — dört
          seçenekli bu ekran yalnızca fareyle kullanılabiliyordu.

          `role="radio"` + `aria-checked`: bunlar bağımsız düğmeler değil,
          birbirini dışlayan TEK bir seçim. Ekran okuyucu "4 seçenekten
          2'si" diye okuyabilsin.
        */}
        <div className="wizard-persona-grid anim-stagger" role="radiogroup" aria-label="Yaşam tarzı profili">
          {personas.map((persona) => {
            const isSelected = selectedId === persona.id;
            const visual = personaVisual(persona.id);
            return (
              <button
                key={persona.id}
                type="button"
                role="radio"
                aria-checked={isSelected}
                onClick={() => setSelectedId(persona.id)}
                className={`wizard-persona${isSelected ? ' is-selected' : ''}`}
              >
                {isSelected && (
                  <span className="wizard-persona-check" aria-hidden="true">
                    <Check />
                  </span>
                )}

                <span className="wizard-persona-icon">
                  <img src={visual.mainIcon} alt="" />
                </span>

                <span className="wizard-persona-text">
                  <span className="wizard-persona-title">{persona.title}</span>
                  <span className="wizard-persona-desc">{persona.description}</span>

                  <span className="wizard-persona-subicons" aria-hidden="true">
                    {visual.subIcons.map((subIcon) => (
                      <img key={subIcon} src={subIcon} alt="" />
                    ))}
                  </span>
                </span>
              </button>
            );
          })}
        </div>

        <button type="button" className="wizard-skip" onClick={handleNext}>
          Kendim Özelleştireceğim
        </button>
      </div>

      <div className="wizard-foot">
        {error && (
          <p className="wizard-error" role="alert">
            {error}
          </p>
        )}
        <div className="wizard-foot-row">
          <button type="button" className="wizard-back" onClick={() => navigate(-1)}>
            Geri
          </button>
          <button
            type="button"
            className="wizard-next"
            onClick={handleNext}
            disabled={saving}
          >
            {saving ? 'Kaydediliyor…' : 'Devam Et'}
            {saving ? (
              <span className="wizard-spinner" aria-hidden="true" />
            ) : (
              <ArrowRight aria-hidden="true" />
            )}
          </button>
        </div>
      </div>
    </div>
  );
}