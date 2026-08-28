import { useEffect, useState } from 'react';
import { Check, ArrowRight } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { ApiError, api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
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

  return (
    <div className="wizard-shell">

      {/* ÜST KISIM: 4 Adımlı Stepper */}
      <div style={{ maxWidth: '520px', margin: '0 auto', width: '100%' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', position: 'relative' }}>
          <div style={{ position: 'absolute', left: '30px', right: '30px', top: '50%', transform: 'translateY(-50%)', height: '2px', backgroundColor: '#d6d3d1', zIndex: 0 }}></div>

          {[
            { step: 1, label: 'Profil', status: 'completed' },
            { step: 2, label: 'Yaşam Tarzı', status: 'completed' },
            { step: 3, label: 'Tercihler', status: 'completed' },
            { step: 4, label: 'Bütçe', status: 'active' },
          ].map((item) => {
            const isCompleted = item.status === 'completed';
            const isActive = item.status === 'active';
            return (
              <div key={item.step} style={{ position: 'relative', zIndex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                <div style={{
                  width: '28px',
                  height: '28px',
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '12px',
                  fontWeight: 500,
                  backgroundColor: isCompleted ? '#C26927' : '#FDFBF7',
                  color: isCompleted ? '#ffffff' : isActive ? '#C26927' : '#a8a29e',
                  border: isCompleted ? 'none' : isActive ? '2px solid #C26927' : '2px solid #d6d3d1',
                  boxShadow: isActive ? '0 0 0 3px rgba(194, 105, 39, 0.1)' : 'none'
                }}>
                  {isCompleted ? <Check size={14} /> : item.step}
                </div>
                <span style={{ fontSize: '11px', marginTop: '4px', fontWeight: 500, color: isActive ? '#C26927' : '#a8a29e' }}>
                  {item.label}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {/* Başlık, Aralık Gösterimi ve Slider Kartı */}
      <div style={{ maxWidth: '640px', margin: '0 auto', width: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
        
        <h1 style={{ fontSize: '32px', fontFamily: 'serif', fontWeight: 'bold', color: '#1c1917', marginBottom: '8px' }}>
          Aylık kira bütçen ne kadar?
        </h1>
        <p style={{ color: '#78716c', fontSize: '14px', maxWidth: '480px', lineHeight: '1.4', marginBottom: '28px' }}>
          Bütçeni, sana gösterilen konutların uygunluk skorunu hesaplarken kullanacağız.
        </p>

        <div style={{ fontSize: '36px', fontFamily: 'serif', fontWeight: 'bold', color: '#C26927', marginBottom: '24px' }}>
          {formatMoney(minBudget)} – {formatMoney(maxBudget)}
        </div>

        {/* Slider Kartı*/}
        <div style={{ 
          width: '100%', 
          backgroundColor: '#F7F4EE', 
          border: '1px solid rgba(214, 211, 209, 0.8)', 
          borderRadius: '16px', 
          padding: '24px 32px',
          boxShadow: '0 2px 4px rgba(0,0,0,0.02)',
          display: 'flex',
          flexDirection: 'column',
          gap: '20px'
        }}>
          
          {/* Min Bütçe Slider */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', textAlign: 'left' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', fontWeight: 500, color: '#44403c' }}>
              <span>Minimum Kira</span>
              <span style={{ fontWeight: 'bold', color: '#C26927' }}>{formatMoney(minBudget)}</span>
            </div>
            <input 
              type="range" 
              min="5000" 
              max="90000" 
              step="1000"
              value={minBudget}
              onChange={(e) => {
                const val = Number(e.target.value);
                if (val <= maxBudget) setMinBudget(val);
              }}
              style={{ width: '100%', accentColor: '#C26927', cursor: 'pointer', height: '5px' }}
            />
          </div>

          <div style={{ width: '100%', height: '1px', backgroundColor: '#e7e5e4' }}></div>

          {/* Max Bütçe Slider */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', textAlign: 'left' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', fontWeight: 500, color: '#44403c' }}>
              <span>Maksimum Kira</span>
              <span style={{ fontWeight: 'bold', color: '#C26927' }}>{formatMoney(maxBudget)}</span>
            </div>
            <input 
              type="range" 
              min="10000" 
              max="150000" 
              step="1000"
              value={maxBudget}
              onChange={(e) => {
                const val = Number(e.target.value);
                if (val >= minBudget) setMaxBudget(val);
              }}
              style={{ width: '100%', accentColor: '#C26927', cursor: 'pointer', height: '5px' }}
            />
          </div>

        </div>

      </div>

      {/*Navigasyon Butonları */}
      <div style={{ maxWidth: '640px', margin: '0 auto', width: '100%', display: 'flex', flexDirection: 'column', gap: '8px', paddingTop: '16px', borderTop: '1px solid #e7e5e4' }}>
        {error && (
          <p style={{ color: '#b91c1c', fontSize: '13px', margin: 0, textAlign: 'center' }}>{error}</p>
        )}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button
            onClick={handleBack}
            style={{ padding: '8px 22px', borderRadius: '8px', border: '1px solid #d6d3d1', backgroundColor: 'transparent', color: '#44403c', fontSize: '14px', fontWeight: 500, cursor: 'pointer' }}
          >
            Geri
          </button>
          <button
            onClick={handleNext}
            disabled={mutation.isPending}
            style={{ padding: '8px 24px', borderRadius: '8px', backgroundColor: '#C26927', color: '#ffffff', fontSize: '14px', fontWeight: 500, border: 'none', cursor: mutation.isPending ? 'not-allowed' : 'pointer', opacity: mutation.isPending ? 0.7 : 1, display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            {mutation.isPending ? 'Kaydediliyor…' : 'Tamamla'} <ArrowRight size={16} />
          </button>
        </div>
      </div>

    </div>
  );
}