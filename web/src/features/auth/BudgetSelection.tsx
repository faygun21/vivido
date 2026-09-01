import { useEffect, useState } from 'react';
import { ArrowRight } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { ApiError, api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { WizardSteps } from '@/features/auth/ui/WizardSteps';
import type { UserProfile } from '@vivido/shared';

export default function BudgetSelection() {
  const [minBudget, setMinBudget] = useState<number>(15000);
  const [maxBudget, setMaxBudget] = useState<number>(35000);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  // Önceki adımlarda kaydedilen ad/soyad, persona ve kriter sırası — bu
  // sayfa YALNIZCA bütçeyi değiştiriyor, ama PUT /profile tam bir upsert
  // olduğu için her seferinde hepsini birlikte göndermek gerekiyor.
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
    if (savedProfile?.minMonthlyBudget != null) setMinBudget(savedProfile.minMonthlyBudget);
    if (savedProfile?.maxMonthlyBudget != null) setMaxBudget(savedProfile.maxMonthlyBudget);
  }, [savedProfile]);

  const mutation = useMutation({
    mutationFn: async () => {
      if (!savedProfile) throw new Error('Profil henüz yüklenmedi.');
      return api.put('/profile', {
        firstName: savedProfile.firstName,
        lastName: savedProfile.lastName,
        personaCode: savedProfile.personaCode,
        categoryOrder: savedProfile.categoryOrder,
        minMonthlyBudget: minBudget,
        maxMonthlyBudget: maxBudget,
      });
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['profile'] });
      // Bütçe değişince /properties'teki filtre ve skorlar da değişir —
      // eski (yanlış) sonuç 30sn'lik staleTime dolana kadar ekranda kalmasın.
      await queryClient.invalidateQueries({ queryKey: ['properties'] });
      navigate('/explore');
    },
    onError: () => {
      setError('Kaydedilemedi, lütfen tekrar deneyin.');
    },
  });

  const handleBack = () => {
    navigate('/preferences');
  };

  const handleNext = () => {
    setError(null);
    mutation.mutate();
  };

  const formatMoney = (val: number) => {
    return val.toLocaleString('tr-TR') + ' TL';
  };

  // Seçilen bandın tüm ölçek üzerindeki yeri. İki ayrı kaydırıcı,
  // aslında TEK bir aralığı tarif ediyor ama ekranda bunu gösteren
  // hiçbir şey yoktu: kullanıcı iki bağımsız sayı ayarlıyormuş gibi
  // hissediyordu. Ortak bir şerit üzerinde seçilen dilimi boyamak,
  // "bu bir aralık" bilgisini etikete gerek kalmadan anlatır.
  const scaleMin = 5000;
  const scaleMax = 150000;
  const toPercent = (value: number) =>
    ((value - scaleMin) / (scaleMax - scaleMin)) * 100;

  const bandStart = toPercent(minBudget);
  const bandWidth = toPercent(maxBudget) - bandStart;

  return (
    <div className="wizard-shell">
      <WizardSteps current={4} />

      <div className="wizard-body wizard-body--center">
        <h1 className="wizard-title">Aylık kira bütçen ne kadar?</h1>
        <p className="wizard-subtitle">
          Bütçeni, sana gösterilen konutların uygunluk skorunu hesaplarken
          kullanacağız.
        </p>

        {/* `tabular-nums`: rakamlar değişirken sayı ZIPLAMASIN. Orantılı
            rakamlarda "1" diğerlerinden dar olduğu için kaydırıcıyı
            sürüklerken tüm satır sağa sola oynuyordu. */}
        <p className="budget-readout">
          {formatMoney(minBudget)} <span aria-hidden="true">–</span>{' '}
          {formatMoney(maxBudget)}
        </p>

        <div className="budget-card">
          {/* Aralığın görsel özeti — iki kaydırıcının ortak sonucu. */}
          <div className="budget-band" aria-hidden="true">
            <span
              className="budget-band-fill"
              style={{ left: `${bandStart}%`, width: `${bandWidth}%` }}
            />
          </div>

          <div className="budget-field">
            <label className="budget-label" htmlFor="budget-min">
              <span>Minimum Kira</span>
              <span className="budget-value">{formatMoney(minBudget)}</span>
            </label>
            <input
              id="budget-min"
              className="budget-range"
              type="range"
              min="5000"
              max="90000"
              step="1000"
              value={minBudget}
              onChange={(e) => {
                const val = Number(e.target.value);
                if (val <= maxBudget) setMinBudget(val);
              }}
            />
          </div>

          <div className="budget-divider" />

          <div className="budget-field">
            <label className="budget-label" htmlFor="budget-max">
              <span>Maksimum Kira</span>
              <span className="budget-value">{formatMoney(maxBudget)}</span>
            </label>
            <input
              id="budget-max"
              className="budget-range"
              type="range"
              min="10000"
              max="150000"
              step="1000"
              value={maxBudget}
              onChange={(e) => {
                const val = Number(e.target.value);
                if (val >= minBudget) setMaxBudget(val);
              }}
            />
          </div>
        </div>
      </div>

      <div className="wizard-foot">
        {error && (
          <p className="wizard-error" role="alert">
            {error}
          </p>
        )}
        <div className="wizard-foot-row">
          <button type="button" className="wizard-back" onClick={handleBack}>
            Geri
          </button>
          <button
            type="button"
            className="wizard-next"
            onClick={handleNext}
            disabled={mutation.isPending}
          >
            {mutation.isPending ? 'Kaydediliyor…' : 'Tamamla'}
            {mutation.isPending ? (
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