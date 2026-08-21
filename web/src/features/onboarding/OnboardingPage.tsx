import {
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import { useNavigate } from 'react-router-dom';
import {
  useQuery,
  useMutation,
} from '@tanstack/react-query';

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

import { AnchorPanel } from '@/features/anchors/AnchorPanel';
import { PersonaCard } from './ui/PersonaCard';
import { BudgetInput } from './ui/BudgetInput';

import {
  ApiError,
  api,
} from '@/shared/api/client';

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

export function OnboardingPage() {
  const navigate = useNavigate();

  const [selectedPersona, setSelectedPersona] =
    useState<PersonaCode | null>(null);

  const [budget, setBudget] =
    useState<number | null>(null);

  const [firstName, setFirstName] =
    useState('');

  const [lastName, setLastName] =
    useState('');

  const [
    categoryWeights,
    setCategoryWeights,
  ] = useState<PersonaCategoryWeight[]>([]);

  /*
   * Persona kartına kullanıcı kendisi tıkladığında
   * kriterler bölümüne kaydırmak için.
   *
   * Kayıtlı profil otomatik yüklenirken sayfanın
   * kendi kendine aşağı zıplamasını istemiyoruz.
   */
  const [
    shouldScrollToCriteria,
    setShouldScrollToCriteria,
  ] = useState(false);

  const criteriaSectionRef =
    useRef<HTMLDivElement | null>(null);

  /*
   * PERSONA LİSTESİ
   */
  const {
    data: personas = [],
    isLoading: personasLoading,
  } = useQuery({
    queryKey: ['personas'],

    queryFn: async () => {
      return api.get<Persona[]>('/personas');
    },
  });

  /*
   * DAHA ÖNCE KAYDEDİLMİŞ PROFİL
   *
   * Yeni kullanıcıda GET /profile 404 dönebilir.
   * Bu normaldir; null kabul ediyoruz.
   */
  const {
    data: savedProfile,
  } = useQuery({
    queryKey: ['profile'],

    queryFn: async (): Promise<UserProfile | null> => {
      try {
        return await api.get<UserProfile>(
          '/profile',
        );
      } catch (err) {
        if (
          err instanceof ApiError &&
          err.problem.code ===
            'PROFILE_NOT_FOUND'
        ) {
          return null;
        }

        throw err;
      }
    },

    retry: false,
  });

  /*
   * Kayıtlı profil varsa form alanlarını
   * otomatik doldur.
   */
  useEffect(() => {
    if (!savedProfile) {
      return;
    }

    setFirstName(savedProfile.firstName);
    setLastName(savedProfile.lastName);
    setBudget(savedProfile.monthlyBudget);
    setSelectedPersona(
      savedProfile.personaCode,
    );
  }, [savedProfile]);

  const selectedPersonaData =
    useMemo(
      () =>
        personas.find(
          (persona) =>
            persona.code ===
            selectedPersona,
        ),
      [
        personas,
        selectedPersona,
      ],
    );

  /*
   * PERSONA → KRİTER SIRASI
   *
   * İki ihtimal var:
   *
   * 1) Kullanıcı bu persona için daha önce
   *    kişisel sıra kaydetmiş:
   *
   *    → DB'deki categoryOrder kullanılır.
   *
   * 2) Kayıtlı kişisel sıra yok:
   *
   *    → Persona'nın varsayılan ağırlık
   *      sırası kullanılır.
   *
   * Sonrasında ağırlıklar pozisyona göre
   * yeniden hesaplanır.
   */
  useEffect(() => {
    if (!selectedPersonaData) {
      setCategoryWeights([]);
      return;
    }

    /*
     * Önce persona'nın varsayılan sırası.
     */
    const defaultOrdered =
      [
        ...selectedPersonaData
          .categoryWeights,
      ].sort(
        (a, b) =>
          b.weight - a.weight,
      );

    let ordered = defaultOrdered;

    /*
     * Kayıtlı sıra yalnızca kayıtlı persona
     * ile şu an seçilmiş persona aynıysa
     * kullanılmalı.
     *
     * Örneğin family_kids için kaydedilmiş
     * sıra student personasına uygulanmaz.
     */
    if (
      savedProfile &&
      savedProfile.personaCode ===
        selectedPersona &&
      savedProfile.categoryOrder.length >
        0
    ) {
      const savedOrderSet =
        new Set(
          savedProfile.categoryOrder,
        );

      /*
       * DB'deki sıraya göre kriterleri diz.
       */
      const savedOrderedItems =
        savedProfile.categoryOrder.flatMap(
          (categoryCode) => {
            const item =
              defaultOrdered.find(
                (candidate) =>
                  candidate.categoryCode ===
                  categoryCode,
              );

            return item ? [item] : [];
          },
        );

      /*
       * İleride yeni bir kriter eklenirse ve
       * eski kullanıcının categoryOrder'ında
       * bulunmazsa kaybolmasın; listenin
       * sonuna eklenir.
       */
      const missingItems =
        defaultOrdered.filter(
          (item) =>
            !savedOrderSet.has(
              item.categoryCode,
            ),
        );

      ordered = [
        ...savedOrderedItems,
        ...missingItems,
      ];
    }

    /*
     * Sıraya göre ağırlık üret.
     *
     * 8 kriter:
     *
     * 8 + 7 + 6 + 5 + 4 + 3 + 2 + 1
     * = 36
     *
     * Böylece:
     *
     * 1. sıra en yüksek
     * 2. sıra ikinci en yüksek
     * ...
     *
     * toplam = 1
     */
    const totalScore =
      ordered.reduce(
        (sum, _, index) =>
          sum +
          (ordered.length - index),
        0,
      );

    const normalized =
      ordered.map(
        (item, index) => ({
          ...item,

          weight:
            (ordered.length - index) /
            totalScore,
        }),
      );

    setCategoryWeights(
      normalized,
    );
  }, [
    selectedPersonaData,
    selectedPersona,
    savedProfile,
  ]);

  /*
   * Kullanıcı persona kartına tıklamışsa
   * kriterler hazır olduğunda otomatik
   * aşağı kaydır.
   */
  useEffect(() => {
    if (
      shouldScrollToCriteria &&
      categoryWeights.length > 0
    ) {
      criteriaSectionRef.current
        ?.scrollIntoView({
          behavior: 'smooth',
          block: 'start',
        });

      setShouldScrollToCriteria(
        false,
      );
    }
  }, [
    shouldScrollToCriteria,
    categoryWeights.length,
  ]);

  /*
   * Normal tıklamaların yanlışlıkla
   * sürükleme sayılmaması için eşik.
   */
  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 6,
      },
    }),
  );

  /*
   * KRİTER SÜRÜKLE-BIRAK
   */
  function handleCriteriaDragEnd(
    event: DragEndEvent,
  ) {
    const { active, over } = event;

    if (
      !over ||
      active.id === over.id
    ) {
      return;
    }

    setCategoryWeights(
      (current) => {
        const oldIndex =
          current.findIndex(
            (item) =>
              item.categoryCode ===
              active.id,
          );

        const newIndex =
          current.findIndex(
            (item) =>
              item.categoryCode ===
              over.id,
          );

        if (
          oldIndex < 0 ||
          newIndex < 0
        ) {
          return current;
        }

        const reordered =
          arrayMove(
            current,
            oldIndex,
            newIndex,
          );

        /*
         * Yeni sıraya göre ağırlıkları
         * yeniden üret.
         */
        const totalScore =
          reordered.reduce(
            (sum, _, index) =>
              sum +
              (
                reordered.length -
                index
              ),
            0,
          );

        return reordered.map(
          (item, index) => ({
            ...item,

            weight:
              (
                reordered.length -
                index
              ) /
              totalScore,
          }),
        );
      },
    );
  }

  /*
   * PROFİLİ KAYDET
   *
   * categoryOrder DB'ye gider.
   */
  const mutation =
    useMutation({
      mutationFn: async () => {
        return api.put(
          '/profile',
          {
            firstName:
              firstName.trim(),

            lastName:
              lastName.trim(),

            personaCode:
              selectedPersona,

            monthlyBudget:
              budget,

            categoryOrder:
              categoryWeights.map(
                (item) =>
                  item.categoryCode,
              ),
          },
        );
      },

      onSuccess: () => {
        navigate('/explore');
      },
    });

  const formIsInvalid =
    firstName.trim() === '' ||
    lastName.trim() === '' ||
    !selectedPersona;

  return (
    <section
      className="page"
      style={{
        maxWidth: '600px',
        margin: '40px auto',
        padding: '0 20px',
      }}
    >
      <h1>Başlayalım</h1>

      <p
        className="muted"
        style={{
          marginBottom: '32px',
        }}
      >
        Sana en uygun rotaları
        çizebilmemiz için profilini
        oluştur.
      </p>

      {/* 1 — Profil Bilgileri */}
      <div
        style={{
          marginBottom: '32px',
        }}
      >
        <h2
          style={{
            fontSize: '1.2rem',
            marginBottom: '16px',
          }}
        >
          1. Profil Bilgileri
        </h2>

        <div
          style={{
            display: 'grid',
            gap: '16px',
          }}
        >
          <div>
            <label
              htmlFor="firstName"
              style={{
                display: 'block',
                marginBottom: '8px',
                fontWeight: 500,
              }}
            >
              Ad
            </label>

            <input
              id="firstName"
              type="text"
              value={firstName}
              onChange={(e) =>
                setFirstName(
                  e.target.value,
                )
              }
              placeholder="Adınız"
              required
              style={{
                width: '100%',
                padding: '12px',
                border:
                  '1px solid #ddd',
                borderRadius: '8px',
                fontSize: '16px',
                boxSizing:
                  'border-box',
              }}
            />
          </div>

          <div>
            <label
              htmlFor="lastName"
              style={{
                display: 'block',
                marginBottom: '8px',
                fontWeight: 500,
              }}
            >
              Soyad
            </label>

            <input
              id="lastName"
              type="text"
              value={lastName}
              onChange={(e) =>
                setLastName(
                  e.target.value,
                )
              }
              placeholder="Soyadınız"
              required
              style={{
                width: '100%',
                padding: '12px',
                border:
                  '1px solid #ddd',
                borderRadius: '8px',
                fontSize: '16px',
                boxSizing:
                  'border-box',
              }}
            />
          </div>
        </div>
      </div>

      {/* 2 — Persona */}
      <div
        style={{
          marginBottom: '32px',
        }}
      >
        <h2
          style={{
            fontSize: '1.2rem',
            marginBottom: '16px',
          }}
        >
          2. Persona Seçimi
        </h2>

        {personasLoading ? (
          <p>Yükleniyor...</p>
        ) : personas.length === 0 ? (
          <p className="muted">
            Persona listesi
            yüklenemedi. Lütfen
            tekrar deneyin.
          </p>
        ) : (
          <div>
            {personas.map(
              (persona) => (
                <PersonaCard
                  key={persona.code}
                  code={persona.code}
                  displayNameTr={
                    persona.displayNameTr
                  }
                  descriptionTr={
                    persona.descriptionTr
                  }
                  isSelected={
                    selectedPersona ===
                    persona.code
                  }
                  onSelect={(code) => {
                    setSelectedPersona(
                      code as PersonaCode,
                    );

                    setShouldScrollToCriteria(
                      true,
                    );
                  }}
                />
              ),
            )}
          </div>
        )}
      </div>

      {/* 3 — Yaşam Kriterleri */}
      {selectedPersona &&
        categoryWeights.length >
          0 && (
          <div
            ref={
              criteriaSectionRef
            }
            style={{
              marginBottom:
                '40px',

              scrollMarginTop:
                '24px',
            }}
          >
            <h2
              style={{
                fontSize:
                  '1.2rem',

                marginBottom:
                  '8px',
              }}
            >
              3. Yaşam Kriterleri
              ve Önem Sırası
            </h2>

            <p
              className="muted"
              style={{
                marginBottom:
                  '20px',
              }}
            >
              Seçtiğin profile
              göre başlangıç
              sırası otomatik
              getirildi.
              Kriterleri
              sürükleyerek önem
              sırasını
              değiştirebilirsin.
            </p>

            <DndContext
              sensors={sensors}
              collisionDetection={
                closestCenter
              }
              onDragEnd={
                handleCriteriaDragEnd
              }
            >
              <SortableContext
                items={
                  categoryWeights.map(
                    (item) =>
                      item.categoryCode,
                  )
                }
                strategy={
                  verticalListSortingStrategy
                }
              >
                <ol
                  style={{
                    listStyle:
                      'none',

                    padding: 0,
                    margin: 0,

                    display:
                      'grid',

                    gap: '12px',
                  }}
                >
                  {categoryWeights.map(
                    (
                      item,
                      index,
                    ) => (
                      <SortableCriterion
                        key={
                          item.categoryCode
                        }
                        item={
                          item
                        }
                        index={
                          index
                        }
                      />
                    ),
                  )}
                </ol>
              </SortableContext>
            </DndContext>
          </div>
        )}

      {/* 4 — Bütçe */}
      <div
        style={{
          marginBottom: '40px',
        }}
      >
        <h2
          style={{
            fontSize: '1.2rem',
            marginBottom: '16px',
          }}
        >
          {selectedPersona
            ? '4.'
            : '3.'}{' '}
          Aylık Kira Bütçesi
        </h2>

        <BudgetInput
          value={budget}
          onChange={setBudget}
        />
      </div>

      {/* 5 — Anchor */}
      <div
        style={{
          borderTop:
            '1px solid #eee',

          paddingTop: '32px',

          marginBottom:
            '32px',
        }}
      >
        <h2
          style={{
            fontSize: '1.2rem',
            marginBottom: '16px',
          }}
        >
          {selectedPersona
            ? '5.'
            : '4.'}{' '}
          Önemli Konumlar
          (Anchor)
        </h2>

        <AnchorPanel />
      </div>

      <button
        onClick={() =>
          mutation.mutate()
        }
        disabled={
          formIsInvalid ||
          mutation.isPending
        }
        style={{
          padding: '16px',
          width: '100%',

          backgroundColor:
            formIsInvalid ||
            mutation.isPending
              ? '#ccc'
              : '#000',

          color: '#fff',
          border: 'none',

          borderRadius: '8px',

          fontSize: '16px',

          fontWeight: 'bold',

          cursor:
            formIsInvalid ||
            mutation.isPending
              ? 'not-allowed'
              : 'pointer',
        }}
      >
        {mutation.isPending
          ? 'Kaydediliyor...'
          : 'Kaydet ve Başla'}
      </button>
    </section>
  );
}

function SortableCriterion({
  item,
  index,
}: {
  item: PersonaCategoryWeight;
  index: number;
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({
    id: item.categoryCode,
  });

  return (
    <li
      ref={setNodeRef}
      {...attributes}
      {...listeners}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '14px',

        padding: '14px 16px',

        border:
          '1px solid #ddd',

        borderRadius: '8px',

        opacity:
          isDragging
            ? 0.65
            : 1,

        transform:
          transform
            ? `translate3d(${transform.x}px, ${transform.y}px, 0)`
            : undefined,

        transition,

        cursor:
          isDragging
            ? 'grabbing'
            : 'grab',

        userSelect: 'none',
      }}
    >
      <span
        aria-hidden="true"
        style={{
          fontSize: '22px',
          padding: '2px',
        }}
      >
        ⠿
      </span>

      <strong
        style={{
          minWidth: '28px',
        }}
      >
        {index + 1}.
      </strong>

      <div
        style={{
          flex: 1,
        }}
      >
        <strong>
          {CATEGORY_LABELS[
            item.categoryCode
          ] ??
            item.categoryCode}
        </strong>
      </div>
    </li>
  );
}