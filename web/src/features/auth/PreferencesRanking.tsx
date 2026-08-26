import { useEffect, useMemo, useState } from 'react';
import { Check, ArrowRight, GripVertical } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { ApiError, api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import type { Persona, UserProfile } from '@vivido/shared';

interface PreferenceItem {
  categoryCode: string;
  title: string;
  icon: string;
}

// Backend'deki gerçek POI kategori kodlarıyla (bkz. db/schema/002_seed_reference.sql,
// PersonaCategoryWeights) BİREBİR aynı olmak zorunda — bu ekran uydurma id'lerle
// (transport/cafe/sport) çalışıyordu ve sıralama hiçbir zaman kaydedilmiyordu,
// backend'e hiç ulaşmıyordu.
const CATEGORY_META: Record<string, { title: string; icon: string }> = {
  transit: { title: 'Toplu Taşıma Ulaşımı', icon: '/bus.svg' },
  food: { title: 'Kafe & Restoran', icon: '/cafe.svg' },
  market: { title: 'Market / Süpermarket', icon: '/avm.svg' },
  gym: { title: 'Spor Salonu', icon: '/sport_kahve.svg' },
  park: { title: 'Park & Yeşil alan', icon: '/park.svg' },
  pharmacy: { title: 'Eczane', icon: '/hastane.svg' },
  health: { title: 'Sağlık', icon: '/hastane.svg' },
  school: { title: 'Okul (İlkokul/Ortaokula yakınlık)', icon: '/school.svg' },
};

export default function PreferencesRanking() {
  const [preferences, setPreferences] = useState<PreferenceItem[]>([]);
  const [draggedIndex, setDraggedIndex] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const { data: personas = [] } = useSessionQuery({
    queryKey: ['personas'],
    queryFn: async () => api.get<Persona[]>('/personas'),
  });

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

  const selectedPersonaData = useMemo(
    () => personas.find((persona) => persona.code === savedProfile?.personaCode),
    [personas, savedProfile?.personaCode],
  );

  // Persona'nın varsayılan ağırlık sırası; kullanıcının daha önce bu persona
  // için kaydettiği kişisel sıra varsa (örn. edit akışından geri döndüyse) o
  // esas alınır — bkz. OnboardingPage.tsx'teki aynı birleştirme mantığı.
  useEffect(() => {
    if (!selectedPersonaData) return;

    const defaultOrder = [...selectedPersonaData.categoryWeights]
      .sort((a, b) => b.weight - a.weight)
      .map((w) => w.categoryCode);

    let order = defaultOrder;

    if (
      savedProfile &&
      savedProfile.personaCode === selectedPersonaData.code &&
      savedProfile.categoryOrder.length > 0
    ) {
      const savedSet = new Set(savedProfile.categoryOrder);
      const missing = defaultOrder.filter((code) => !savedSet.has(code));
      order = [...savedProfile.categoryOrder, ...missing];
    }

    setPreferences(
      order
        .filter((code) => CATEGORY_META[code])
        .map((code) => ({ categoryCode: code, ...CATEGORY_META[code] })),
    );
  }, [selectedPersonaData, savedProfile]);

  useEffect(() => {
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = 'auto';
    };
  }, []);

  const mutation = useMutation({
    mutationFn: async () => {
      if (!savedProfile) throw new Error('Profil henüz yüklenmedi.');
      return api.put('/profile', {
        firstName: savedProfile.firstName,
        lastName: savedProfile.lastName,
        personaCode: savedProfile.personaCode,
        minMonthlyBudget: savedProfile.minMonthlyBudget,
        maxMonthlyBudget: savedProfile.maxMonthlyBudget,
        categoryOrder: preferences.map((p) => p.categoryCode),
      });
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['profile'] });
      // Kriter sırası skorları değiştirir — /properties'i de tazele.
      await queryClient.invalidateQueries({ queryKey: ['properties'] });
      navigate('/budget');
    },
    onError: () => {
      setError('Kaydedilemedi, lütfen tekrar deneyin.');
    },
  });

  const handleBack = () => {
    navigate('/lifestyle');
  };

  const handleNext = () => {
    setError(null);
    mutation.mutate();
  };

  const handleDragStart = (index: number) => {
    setDraggedIndex(index);
  };

  const handleDragOver = (e: React.DragEvent, index: number) => {
    e.preventDefault();
    if (draggedIndex === null || draggedIndex === index) return;

    const newPreferences = [...preferences];
    const draggedItem = newPreferences[draggedIndex];

    newPreferences.splice(draggedIndex, 1);
    newPreferences.splice(index, 0, draggedItem);

    setDraggedIndex(index);
    setPreferences(newPreferences);
  };

  const handleDragEnd = () => {
    setDraggedIndex(null);
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      width: '100vw',
      height: '100vh',
      backgroundColor: '#FDFBF7',
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'space-between',
      padding: '20px 32px',
      fontFamily: 'sans-serif',
      boxSizing: 'border-box',
      overflow: 'hidden',
      zIndex: 9999
    }}>

      {/* 4 Adımlı Stepper*/}
      <div style={{ maxWidth: '520px', margin: '0 auto', width: '100%' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', position: 'relative' }}>
          <div style={{ position: 'absolute', left: '30px', right: '30px', top: '50%', transform: 'translateY(-50%)', height: '2px', backgroundColor: '#d6d3d1', zIndex: 0 }}></div>

          {[
            { step: 1, label: 'Profil', status: 'completed' },
            { step: 2, label: 'Yaşam Tarzı', status: 'completed' },
            { step: 3, label: 'Tercihler', status: 'active' },
            { step: 4, label: 'Bütçe', status: 'pending' },
          ].map((item) => {
            const isCompleted = item.status === 'completed';
            const isActive = item.status === 'active';
            return (
              <div key={item.step} style={{ position: 'relative', zIndex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                <div style={{
                  width: '26px',
                  height: '26px',
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '11px',
                  fontWeight: 500,
                  backgroundColor: isCompleted ? '#C26927' : '#FDFBF7',
                  color: isCompleted ? '#ffffff' : isActive ? '#C26927' : '#a8a29e',
                  border: isCompleted ? 'none' : isActive ? '2px solid #C26927' : '2px solid #d6d3d1',
                  boxShadow: isActive ? '0 0 0 3px rgba(194, 105, 39, 0.1)' : 'none'
                }}>
                  {isCompleted ? <Check size={13} /> : item.step}
                </div>
                <span style={{ fontSize: '11px', marginTop: '3px', fontWeight: 500, color: isActive ? '#C26927' : '#a8a29e' }}>
                  {item.label}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {/* Başlık ve Sürükle-Bırak Liste */}
      <div style={{ maxWidth: '700px', margin: '0 auto', width: '100%', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '10px' }}>
          <h1 style={{ fontSize: '24px', fontFamily: 'serif', fontWeight: 'bold', color: '#1c1917', margin: 0 }}>
            Öncelik Sıralaman
          </h1>
          <span style={{ fontSize: '12px', color: '#a8a29e' }}>Sürükle ve bırak</span>
        </div>

        {/* Liste Alanı */}
        <div style={{
          display: 'flex',
          flexDirection: 'column',
          gap: '8px',
          width: '100%',
        }}>
          {preferences.map((item, index) => (
            <div
              key={item.categoryCode}
              draggable
              onDragStart={() => handleDragStart(index)}
              onDragOver={(e) => handleDragOver(e, index)}
              onDragEnd={handleDragEnd}
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '11px 16px',
                backgroundColor: draggedIndex === index ? '#EFECE6' : '#F7F4EE',
                border: draggedIndex === index ? '1px dashed #C26927' : '1px solid rgba(214, 211, 209, 0.8)',
                borderRadius: '12px',
                cursor: 'grab',
                opacity: draggedIndex === index ? 0.6 : 1,
                transition: 'background-color 0.2s ease, border 0.2s ease',
                boxShadow: '0 1px 3px rgba(0,0,0,0.02)',
                userSelect: 'none',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', pointerEvents: 'none' }}>
                <GripVertical size={18} color="#a8a29e" />

                <div style={{ width: '30px', height: '30px', borderRadius: '50%', backgroundColor: '#EFECE6', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <img src={item.icon} alt={item.title} style={{ width: '16px', height: '16px', objectFit: 'contain' }} />
                </div>

                <span style={{ fontSize: '14px', fontWeight: 500, color: '#1c1917' }}>
                  {item.title}
                </span>
              </div>
            </div>
          ))}
        </div>

      </div>

      {/* Navigasyon Butonları */}
      <div style={{ maxWidth: '700px', margin: '0 auto', width: '100%', display: 'flex', flexDirection: 'column', gap: '8px', paddingTop: '14px', borderTop: '1px solid #e7e5e4' }}>
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
            disabled={mutation.isPending || preferences.length === 0}
            style={{ padding: '8px 24px', borderRadius: '8px', backgroundColor: '#C26927', color: '#ffffff', fontSize: '14px', fontWeight: 500, border: 'none', cursor: mutation.isPending ? 'not-allowed' : 'pointer', opacity: mutation.isPending ? 0.7 : 1, display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            {mutation.isPending ? 'Kaydediliyor…' : 'Devam Et'} <ArrowRight size={16} />
          </button>
        </div>
      </div>

    </div>
  );
}
