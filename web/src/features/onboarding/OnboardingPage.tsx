import {
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
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
import { Check, GripVertical } from 'lucide-react';

import { AnchorPanel } from '@/features/anchors/AnchorPanel';
import { BudgetInput } from './ui/BudgetInput';
import { ApiError, api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';

import type {
  Persona,
  PersonaCode,
  PersonaCategoryWeight,
  UserProfile,
} from '@vivido/shared';

const CATEGORY_LABELS: Record<string, string> = {
  market: 'Market / süpermarket',
  pharmacy: 'Eczane',
  transit: 'Toplu taşıma durağı',
  food: 'Kafe & restoran',
  park: 'Park & yeşil alan',
  gym: 'Spor salonu',
  school: 'İlkokul / ortaokul',
  health: 'ASM / hastane',
};

// API'den gelen persona kodlarına göre lokal SVG ikonlarını eşleştiriyoruz
const PERSONA_UI_DATA: Record<string, { mainIcon: string; subIcons: string[] }> = {
  student: {
    mainIcon: '/kep.svg',
    subIcons: ['/bus.svg', '/school.svg', '/cafe.svg'],
  },
  remote_worker: {
    mainIcon: '/pc.svg',
    subIcons: ['/cafe.svg', '/sport_kahve.svg', '/park.svg'],
  },
  family_kids: {
    mainIcon: '/family.svg',
    subIcons: ['/school.svg', '/avm.svg', '/park.svg'],
  },
  elderly: {
    mainIcon: '/glasses.svg',
    subIcons: ['/hastane.svg', '/avm.svg', '/park.svg'],
  },
};

export function OnboardingPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  // Form states
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [selectedPersona, setSelectedPersona] = useState<PersonaCode | null>(null);
  const [categoryWeights, setCategoryWeights] = useState<PersonaCategoryWeight[]>([]);
  const [minMonthlyBudget, setMinMonthlyBudget] = useState<number | null>(null);
  const [maxMonthlyBudget, setMaxMonthlyBudget] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [shouldScrollToCriteria, setShouldScrollToCriteria] = useState(false);
  const criteriaSectionRef = useRef<HTMLDivElement | null>(null);

  // API Queries
  const { data: personas = [], isLoading: personasLoading } = useSessionQuery({
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

  // Profil verilerini form alanlarına aktar
  useEffect(() => {
    if (!savedProfile) return;
    setFirstName(savedProfile.firstName);
    setLastName(savedProfile.lastName);
    setMinMonthlyBudget(savedProfile.minMonthlyBudget);
    setMaxMonthlyBudget(savedProfile.maxMonthlyBudget);
    setSelectedPersona(savedProfile.personaCode);
  }, [savedProfile]);

  const selectedPersonaData = useMemo(
    () => personas.find((p) => p.code === selectedPersona),
    [personas, selectedPersona],
  );

  // Persona değiştiğinde kriter sırasını ayarla
  useEffect(() => {
    if (!selectedPersonaData) {
      setCategoryWeights([]);
      return;
    }

    const defaultOrdered = [...selectedPersonaData.categoryWeights].sort((a, b) => b.weight - a.weight);
    let ordered = defaultOrdered;

    if (savedProfile && savedProfile.personaCode === selectedPersona && savedProfile.categoryOrder.length > 0) {
      const savedOrderSet = new Set(savedProfile.categoryOrder);
      const savedOrderedItems = savedProfile.categoryOrder.flatMap((categoryCode) => {
        const item = defaultOrdered.find((candidate) => candidate.categoryCode === categoryCode);
        return item ? [item] : [];
      });
      const missingItems = defaultOrdered.filter((item) => !savedOrderSet.has(item.categoryCode));
      ordered = [...savedOrderedItems, ...missingItems];
    }

    const totalScore = ordered.reduce((sum, _, index) => sum + (ordered.length - index), 0);
    const normalized = ordered.map((item, index) => ({
      ...item,
      weight: (ordered.length - index) / totalScore,
    }));

    setCategoryWeights(normalized);
  }, [selectedPersonaData, selectedPersona, savedProfile]);

  // Persona seçildiğinde Kriterler bölümüne yumuşak kaydırma
  useEffect(() => {
    if (shouldScrollToCriteria && categoryWeights.length > 0) {
      criteriaSectionRef.current?.scrollIntoView({
        behavior: 'smooth',
        block: 'start',
      });
      setShouldScrollToCriteria(false);
    }
  }, [shouldScrollToCriteria, categoryWeights.length]);

  // DnD Sensors
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
  );

  function handleCriteriaDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    setCategoryWeights((current) => {
      const oldIndex = current.findIndex((item) => item.categoryCode === active.id);
      const newIndex = current.findIndex((item) => item.categoryCode === over.id);
      if (oldIndex < 0 || newIndex < 0) return current;

      const reordered = arrayMove(current, oldIndex, newIndex);
      const totalScore = reordered.reduce((sum, _, index) => sum + (reordered.length - index), 0);

      return reordered.map((item, index) => ({
        ...item,
        weight: (reordered.length - index) / totalScore,
      }));
    });
  }

  const mutation = useMutation({
    mutationFn: async () => {
      return api.put('/profile', {
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        personaCode: selectedPersona,
        minMonthlyBudget,
        maxMonthlyBudget,
        categoryOrder: categoryWeights.map((item) => item.categoryCode),
      });
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['profile'] });
      void queryClient.invalidateQueries({ queryKey: ['properties'] });
      navigate('/explore');
    },
    onError: () => {
      setError('Profil kaydedilemedi, lütfen tekrar deneyin.');
    }
  });

  const budgetRangeIsInvalid = minMonthlyBudget !== null && maxMonthlyBudget !== null && minMonthlyBudget > maxMonthlyBudget;

  const formIsInvalid = 
    firstName.trim() === '' || 
    lastName.trim() === '' || 
    !selectedPersona || 
    budgetRangeIsInvalid;

  return (
    <div style={{
      backgroundColor: '#FDFBF7',
      minHeight: '100vh',
      fontFamily: 'system-ui, -apple-system, sans-serif',
      color: '#2a2825',
      paddingBottom: '80px'
    }}>
      <div style={{ 
        maxWidth: '800px', 
        margin: '0 auto', 
        padding: '60px 24px 24px' 
      }}>
        
        {/* ÜST BAŞLIK */}
        <div style={{ marginBottom: '56px' }}>
          <h1 style={{ fontSize: '2.8rem', fontFamily: '"Playfair Display", serif', fontWeight: 'bold', color: '#1c1917', marginBottom: '12px' }}>
            Profil
          </h1>
        </div>

        {/* 1. PROFIL BİLGİLERİ */}
        <section style={{ marginBottom: '56px' }}>
          <h2 style={{ fontSize: '1.4rem', fontFamily: '"Playfair Display", serif', color: '#3d3832', fontWeight: 600, marginBottom: '20px' }}>
            1. Profil Bilgileri
          </h2>
          <div className="wizard-two-col">
            <div>
              <label htmlFor="firstName" style={{ display: 'block', marginBottom: '8px', fontWeight: 500, fontSize: '14px', color: '#57534e' }}>Ad</label>
              <input
                id="firstName"
                type="text"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                placeholder="Adınız"
                style={{ width: '100%', padding: '14px', border: '1px solid #d6d3d1', borderRadius: '12px', fontSize: '16px', backgroundColor: '#fff', boxSizing: 'border-box', transition: 'border-color 0.2s' }}
              />
            </div>
            <div>
              <label htmlFor="lastName" style={{ display: 'block', marginBottom: '8px', fontWeight: 500, fontSize: '14px', color: '#57534e' }}>Soyad</label>
              <input
                id="lastName"
                type="text"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                placeholder="Soyadınız"
                style={{ width: '100%', padding: '14px', border: '1px solid #d6d3d1', borderRadius: '12px', fontSize: '16px', backgroundColor: '#fff', boxSizing: 'border-box', transition: 'border-color 0.2s' }}
              />
            </div>
          </div>
        </section>

        {/* 2. YAŞAM TARZI (PERSONA) */}
        <section style={{ marginBottom: '56px' }}>
          <h2 style={{ fontSize: '1.4rem', fontFamily: '"Playfair Display", serif', color: '#3d3832', fontWeight: 600, marginBottom: '20px' }}>
            2. Yaşam tarzına en uygun profili seç
          </h2>
          
          {personasLoading ? (
            <p style={{ color: '#7a736a' }}>Profiller yükleniyor...</p>
          ) : (
            <div className="wizard-persona-grid" style={{ gap: '20px' }}>
              {personas.map((persona) => {
                const isSelected = selectedPersona === persona.code;
                const uiData = PERSONA_UI_DATA[persona.code] || PERSONA_UI_DATA['student'];
                return (
                  <div
                    key={persona.code}
                    onClick={() => {
                      setSelectedPersona(persona.code as PersonaCode);
                      setShouldScrollToCriteria(true);
                    }}
                    style={{
                      position: 'relative', padding: '24px', borderRadius: '16px', cursor: 'pointer',
                      transition: 'all 0.2s ease', border: isSelected ? '2px solid #c86f38' : '1px solid #e7e5e4',
                      backgroundColor: isSelected ? '#FAF6F0' : '#F7F4EE',
                      boxShadow: isSelected ? '0 4px 12px rgba(200, 111, 56, 0.08)' : 'none',
                      display: 'flex', flexDirection: 'column',
                    }}
                  >
                    {isSelected && (
                      <div style={{ position: 'absolute', top: '16px', right: '16px', width: '24px', height: '24px', backgroundColor: '#c86f38', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#ffffff' }}>
                        <Check size={14} strokeWidth={3} />
                      </div>
                    )}
                    <div style={{ display: 'flex', alignItems: 'center', gap: '16px', marginBottom: '16px' }}>
                      <div style={{ width: '48px', height: '48px', borderRadius: '50%', backgroundColor: isSelected ? '#EBDAD0' : '#EAE6DF', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                        <img src={uiData.mainIcon} alt={persona.displayNameTr} style={{ width: '24px', height: '24px', objectFit: 'contain' }} />
                      </div>
                      <h3 style={{ fontFamily: '"Playfair Display", serif', fontWeight: 'bold', fontSize: '1.2rem', margin: 0, color: isSelected ? '#c86f38' : '#2a2825' }}>
                        {persona.displayNameTr}
                      </h3>
                    </div>
                    <p style={{ color: '#57534e', fontSize: '14px', lineHeight: '1.5', margin: '0 0 24px 0', paddingBottom: '20px', borderBottom: '1px solid rgba(0,0,0,0.06)', flex: 1 }}>
                      {persona.descriptionTr}
                    </p>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                      {uiData.subIcons.map((subIcon, idx) => (
                        <img key={idx} src={subIcon} alt="sub-icon" style={{ width: '18px', height: '18px', objectFit: 'contain', opacity: 0.6 }} />
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>

        {/* 3. YAŞAM KRİTERLERİ */}
        {selectedPersona && categoryWeights.length > 0 && (
          <section ref={criteriaSectionRef} style={{ marginBottom: '56px', scrollMarginTop: '40px' }}>
            <h2 style={{ fontSize: '1.4rem', fontFamily: '"Playfair Display", serif', color: '#3d3832', fontWeight: 600, marginBottom: '8px' }}>
              3. Yaşam Kriterleri ve Önem Sırası
            </h2>
            <p style={{ color: '#7a736a', fontSize: '15px', marginBottom: '24px' }}>
              Seçtiğin profile göre başlangıç sırası otomatik getirildi. Kriterleri sürükleyerek senin için en önemli olanı en üste taşı.
            </p>

            <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleCriteriaDragEnd}>
              <SortableContext items={categoryWeights.map((item) => item.categoryCode)} strategy={verticalListSortingStrategy}>
                <ol style={{ listStyle: 'none', padding: 0, margin: 0, display: 'grid', gap: '12px', maxWidth: '600px' }}>
                  {categoryWeights.map((item, index) => (
                    <SortableCriterion key={item.categoryCode} item={item} index={index} />
                  ))}
                </ol>
              </SortableContext>
            </DndContext>
          </section>
        )}

        {/* 4. BÜTÇE */}
        <section style={{ marginBottom: '56px' }}>
          <h2 style={{ fontSize: '1.4rem', fontFamily: '"Playfair Display", serif', color: '#3d3832', fontWeight: 600, marginBottom: '20px' }}>
            {selectedPersona ? '4.' : '3.'} Aylık kira bütçen nedir?
          </h2>
          {/* Tek çocuklu bir `1fr 1fr` grid, `BudgetInput`'u yarım genişlikte
              sıkıştırıyordu (2. sütun hep boş kalıyordu) — kaldırıldı;
              `BudgetInput` zaten kendi iki alanını içeride yönetiyor. */}
          <div style={{ maxWidth: '500px' }}>
            <BudgetInput
              minValue={minMonthlyBudget}
              maxValue={maxMonthlyBudget}
              onMinChange={setMinMonthlyBudget}
              onMaxChange={setMaxMonthlyBudget}
            />
          </div>
          {budgetRangeIsInvalid && (
            <p style={{ color: '#b91c1c', marginTop: '12px', fontSize: '14px', fontWeight: 500 }}>
              Minimum kira, maksimum kiradan büyük olamaz.
            </p>
          )}
        </section>

        {/* 5. ANCHOR (ÖNEMLİ KONUMLAR) */}
        <section style={{ marginBottom: '56px' }}>
          <h2 style={{ fontSize: '1.4rem', fontFamily: '"Playfair Display", serif', color: '#3d3832', fontWeight: 600, marginBottom: '8px' }}>
            {selectedPersona ? '5.' : '4.'} Önemli Konumlar (Anchor)
          </h2>
          <p style={{ color: '#7a736a', fontSize: '15px', marginBottom: '24px' }}>
            Sana yakın olmasını istediğin spesifik yerleri (iş yeri, okul vb.) ekleyebilirsin.
          </p>
          <AnchorPanel />
        </section>

        {/* ALT KAYDET BUTONU */}
        <div style={{ borderTop: '1px solid #e7e5e4', paddingTop: '32px', display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '12px' }}>
          {error && (
            <p style={{ color: '#b91c1c', fontSize: '14px', margin: 0, fontWeight: 500 }}>{error}</p>
          )}
          <button
            onClick={() => mutation.mutate()}
            disabled={formIsInvalid || mutation.isPending}
            style={{
              padding: '16px 40px',
              backgroundColor: formIsInvalid || mutation.isPending ? '#d6d3d1' : '#c86f38',
              color: '#fff',
              border: 'none',
              borderRadius: '12px',
              fontSize: '16px',
              fontWeight: '600',
              cursor: formIsInvalid || mutation.isPending ? 'not-allowed' : 'pointer',
              transition: 'all 0.2s ease',
              boxShadow: formIsInvalid ? 'none' : '0 4px 12px rgba(200, 111, 56, 0.2)'
            }}
          >
            {mutation.isPending ? 'Kaydediliyor...' : 'Kaydet'}
          </button>
        </div>

      </div>
    </div>
  );
}

// Kriter Sıralama Bileşeni
function SortableCriterion({ item, index }: { item: PersonaCategoryWeight; index: number; }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: item.categoryCode,
  });

  return (
    <li
      ref={setNodeRef}
      {...attributes}
      {...listeners}
      style={{
        display: 'flex', alignItems: 'center', gap: '16px', padding: '16px 20px',
        backgroundColor: '#fff', border: '1px solid #e7e5e4', borderRadius: '12px',
        boxShadow: isDragging ? '0 8px 16px rgba(200, 111, 56, 0.15)' : '0 2px 4px rgba(0,0,0,0.02)',
        opacity: isDragging ? 0.9 : 1,
        transform: transform ? `translate3d(${transform.x}px, ${transform.y}px, 0) scale(${isDragging ? 1.02 : 1})` : undefined,
        transition: transition || 'box-shadow 0.2s, transform 0.2s',
        cursor: isDragging ? 'grabbing' : 'grab', userSelect: 'none', zIndex: isDragging ? 10 : 1
      }}
    >
      <GripVertical size={20} color="#a8a29e" />
      <strong style={{ minWidth: '24px', fontSize: '15px', color: '#c86f38' }}>{index + 1}.</strong>
      <div style={{ flex: 1 }}>
        <strong style={{ fontWeight: 500, fontSize: '15px', color: '#44403c' }}>
          {CATEGORY_LABELS[item.categoryCode] ?? item.categoryCode}
        </strong>
      </div>
    </li>
  );
}