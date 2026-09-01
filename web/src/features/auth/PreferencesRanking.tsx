import { useEffect, useMemo, useState } from 'react';
import { ArrowRight, GripVertical } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import {
  DndContext,
  PointerSensor,
  closestCenter,
  useSensor,
  useSensors,
  type DragEndEvent,
} from '@dnd-kit/core';
import {
  SortableContext,
  arrayMove,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { ApiError, api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { WizardSteps } from '@/features/auth/ui/WizardSteps';
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

  // `PointerSensor` mouse/dokunma/kalem hepsini tek olay modeliyle
  // kapsıyor — eski native HTML5 `draggable` (onDragStart/onDragOver)
  // dokunmatik ekranlarda HİÇ çalışmıyordu, sıralama telefonda tamamen
  // kullanılamazdı (2026-08-28). `OnboardingPage.tsx`'teki aynı desen.
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
  );

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    setPreferences((current) => {
      const oldIndex = current.findIndex((item) => item.categoryCode === active.id);
      const newIndex = current.findIndex((item) => item.categoryCode === over.id);
      if (oldIndex < 0 || newIndex < 0) return current;
      return arrayMove(current, oldIndex, newIndex);
    });
  }

  return (
    <div className="wizard-shell">
      <WizardSteps current={3} />

      <div className="wizard-body wizard-body--stretch">
        <div className="wizard-head-row">
          <h1 className="wizard-title wizard-title--left">Öncelik Sıralaman</h1>
          <span className="wizard-hint">Sürükle ve bırak</span>
        </div>

        {/* Sıra numarası GÖRÜNÜR olmalı: "1." kriter ile "6." kriterin
            skora katkısı çok farklı, ama liste yalnızca konumla
            anlatıyordu. Kullanıcı kaçıncı sırada olduğunu saymak
            zorunda kalıyordu. */}
        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
          <SortableContext
            items={preferences.map((item) => item.categoryCode)}
            strategy={verticalListSortingStrategy}
          >
            <ol className="pref-list">
              {preferences.map((item, index) => (
                <SortablePreferenceItem
                  key={item.categoryCode}
                  item={item}
                  rank={index + 1}
                />
              ))}
            </ol>
          </SortableContext>
        </DndContext>
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
            disabled={mutation.isPending || preferences.length === 0}
          >
            {mutation.isPending ? 'Kaydediliyor…' : 'Devam Et'}
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

function SortablePreferenceItem({ item, rank }: { item: PreferenceItem; rank: number }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: item.categoryCode,
  });

  return (
    <li
      ref={setNodeRef}
      {...attributes}
      {...listeners}
      className={`pref-item${isDragging ? ' is-dragging' : ''}`}
      // Yalnızca dnd-kit'in her karede hesapladığı iki değer satır içi
      // kalıyor — konum ve geçiş sürükleme sırasında sürekli değişir,
      // CSS sınıfına çıkarılamaz. Görsel kararların geri kalanı
      // `.pref-item` sınıfında.
      style={{
        transform: transform
          ? `translate3d(${transform.x}px, ${transform.y}px, 0)`
          : undefined,
        transition,
      }}
    >
      <span className="pref-rank" aria-hidden="true">{rank}</span>

      <GripVertical className="pref-grip" aria-hidden="true" />

      <span className="pref-icon">
        <img src={item.icon} alt="" />
      </span>

      <span className="pref-title">{item.title}</span>
    </li>
  );
}
