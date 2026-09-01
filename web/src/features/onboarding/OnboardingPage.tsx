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
import { personaVisual } from '@/shared/persona/personaVisuals';

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

/* Persona ikonları `@/shared/persona/personaVisuals`'ta — bu tablo
   burada, `LifestyleSelection`'da ve (eksik olduğu için) profil
   sayfasında olmak üzere üç ayrı yerde tutuluyordu. */

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

  /*
    Bu sayfa baştan sona satır içi `style` nesneleriyle yazılmıştı ve
    uygulamanın ÜÇÜNCÜ paletini taşıyordu:

    - Vurgu `#c86f38`. Token `--accent: #C0421D`, sihirbaz `#C26927`.
      Aynı üründe üç ayrı "marka turuncusu" vardı; kullanıcı Profil'e
      girip çıkarken rengin değiştiğini görüyordu.
    - Başlıklar `"Playfair Display", serif` — bu font Poppins gibi
      HİÇ YÜKLENMİYORDU, tarayıcı sessizce genel bir serif'e düşüyordu
      (Windows'ta Times New Roman). Yani "zarif serif başlık" niyeti
      hiçbir makinede görünmedi.
    - Kabuk `fontFamily: 'system-ui'` diyerek Poppins'i ayrıca eziyordu.

    Hepsi token'lara taşındı; yapı ve davranış aynı kaldı.
  */
  return (
    <div className="profile-edit">
      <div className="profile-edit-inner">
        <header className="profile-edit-head">
          <h1>Profil</h1>
          <p className="muted">
            Seçimlerin skorlamayı doğrudan etkiler — değiştirdiğinde konut
            sıralaman yeniden hesaplanır.
          </p>
        </header>

        {/* 1. PROFİL BİLGİLERİ */}
        <section className="profile-section">
          <h2 className="profile-section-title">
            <span className="profile-section-num">1</span>
            Profil Bilgileri
          </h2>
          <div className="wizard-two-col">
            <div className="field">
              <label className="profile-label" htmlFor="firstName">Ad</label>
              <input
                id="firstName"
                type="text"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                placeholder="Adınız"
              />
            </div>
            <div className="field">
              <label className="profile-label" htmlFor="lastName">Soyad</label>
              <input
                id="lastName"
                type="text"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                placeholder="Soyadınız"
              />
            </div>
          </div>
        </section>

        {/* 2. YAŞAM TARZI (PERSONA) */}
        <section className="profile-section">
          <h2 className="profile-section-title">
            <span className="profile-section-num">2</span>
            Yaşam tarzına en uygun profili seç
          </h2>

          {personasLoading ? (
            <div className="wizard-persona-grid" aria-busy="true" aria-label="Profiller yükleniyor">
              {[0, 1, 2, 3].map((row) => (
                <div key={row} className="skeleton persona-skeleton" aria-hidden="true" />
              ))}
            </div>
          ) : (
            <div
              className="wizard-persona-grid wizard-persona-grid--roomy anim-stagger"
              role="radiogroup"
              aria-label="Yaşam tarzı profili"
            >
              {personas.map((persona) => {
                const isSelected = selectedPersona === persona.code;
                const uiData = personaVisual(persona.code);
                return (
                  /* `<div onClick>` DEĞİL `<button role="radio">`:
                     kartlar klavyeyle seçilemiyor, Tab sırasına hiç
                     girmiyordu. */
                  <button
                    key={persona.code}
                    type="button"
                    role="radio"
                    aria-checked={isSelected}
                    onClick={() => {
                      setSelectedPersona(persona.code as PersonaCode);
                      setShouldScrollToCriteria(true);
                    }}
                    className={`wizard-persona wizard-persona--stacked${
                      isSelected ? ' is-selected' : ''
                    }`}
                  >
                    {isSelected && (
                      <span className="wizard-persona-check" aria-hidden="true">
                        <Check strokeWidth={3} />
                      </span>
                    )}

                    <span className="persona-stacked-head">
                      <span className="wizard-persona-icon">
                        <img src={uiData.mainIcon} alt="" />
                      </span>
                      <span className="wizard-persona-title">{persona.displayNameTr}</span>
                    </span>

                    <span className="persona-stacked-desc">{persona.descriptionTr}</span>

                    <span className="wizard-persona-subicons" aria-hidden="true">
                      {uiData.subIcons.map((subIcon) => (
                        <img key={subIcon} src={subIcon} alt="" />
                      ))}
                    </span>
                  </button>
                );
              })}
            </div>
          )}
        </section>

        {/* 3. YAŞAM KRİTERLERİ */}
        {selectedPersona && categoryWeights.length > 0 && (
          <section ref={criteriaSectionRef} className="profile-section profile-section--anchor">
            <h2 className="profile-section-title">
              <span className="profile-section-num">3</span>
              Yaşam Kriterleri ve Önem Sırası
            </h2>
            <p className="profile-section-desc">
              Seçtiğin profile göre başlangıç sırası otomatik getirildi. Kriterleri
              sürükleyerek senin için en önemli olanı en üste taşı.
            </p>

            <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleCriteriaDragEnd}>
              <SortableContext items={categoryWeights.map((item) => item.categoryCode)} strategy={verticalListSortingStrategy}>
                <ol className="pref-list pref-list--wide">
                  {categoryWeights.map((item, index) => (
                    <SortableCriterion key={item.categoryCode} item={item} index={index} />
                  ))}
                </ol>
              </SortableContext>
            </DndContext>
          </section>
        )}

        {/* 4. BÜTÇE */}
        <section className="profile-section">
          <h2 className="profile-section-title">
            <span className="profile-section-num">{selectedPersona ? '4' : '3'}</span>
            Aylık kira bütçen nedir?
          </h2>
          {/* Tek çocuklu bir `1fr 1fr` grid, `BudgetInput`'u yarım genişlikte
              sıkıştırıyordu (2. sütun hep boş kalıyordu) — kaldırıldı;
              `BudgetInput` zaten kendi iki alanını içeride yönetiyor. */}
          <div className="profile-budget">
            <BudgetInput
              minValue={minMonthlyBudget}
              maxValue={maxMonthlyBudget}
              onMinChange={setMinMonthlyBudget}
              onMaxChange={setMaxMonthlyBudget}
            />
          </div>
          {budgetRangeIsInvalid && (
            <p className="profile-inline-error" role="alert">
              Minimum kira, maksimum kiradan büyük olamaz.
            </p>
          )}
        </section>

        {/* 5. ANCHOR (ÖNEMLİ KONUMLAR) */}
        <section className="profile-section">
          <h2 className="profile-section-title">
            <span className="profile-section-num">{selectedPersona ? '5' : '4'}</span>
            Önemli Konumlar (Anchor)
          </h2>
          <p className="profile-section-desc">
            Sana yakın olmasını istediğin spesifik yerleri (iş yeri, okul vb.)
            ekleyebilirsin.
          </p>
          <AnchorPanel />
        </section>

        {/* KAYDET — sayfanın altına YAPIŞIK.
            Sayfa beş bölüm uzunluğunda; kullanıcı kriterleri sürükledikten
            sonra kaydetmek için en alta inmek zorundaydı ve "kaydettim mi"
            sorusu ekranda hiçbir yerde cevaplanmıyordu. */}
        <div className="profile-save-bar">
          {error && (
            <p className="profile-inline-error" role="alert">
              {error}
            </p>
          )}
          <button
            type="button"
            className="btn-primary profile-save"
            onClick={() => mutation.mutate()}
            disabled={formIsInvalid || mutation.isPending}
          >
            {mutation.isPending ? 'Kaydediliyor…' : 'Kaydet'}
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
      className={`pref-item${isDragging ? ' is-dragging' : ''}`}
      // Yalnızca dnd-kit'in her karede ürettiği iki değer satır içi kalıyor.
      style={{
        transform: transform
          ? `translate3d(${transform.x}px, ${transform.y}px, 0)`
          : undefined,
        transition,
      }}
    >
      <span className="pref-rank" aria-hidden="true">{index + 1}</span>
      <GripVertical className="pref-grip" aria-hidden="true" />
      <span className="pref-title">
        {CATEGORY_LABELS[item.categoryCode] ?? item.categoryCode}
      </span>
    </li>
  );
}