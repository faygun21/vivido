import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQuery, useMutation } from '@tanstack/react-query';
import { AnchorPanel } from '@/features/anchors/AnchorPanel';
import { PersonaCard } from './ui/PersonaCard';
import { BudgetInput } from './ui/BudgetInput';
import { api } from '@/shared/api/client';
import type { Persona, PersonaCode } from '@vivido/shared';

export function OnboardingPage() {
  const navigate = useNavigate();

  // State'ler
  const [selectedPersona, setSelectedPersona] =
    useState<PersonaCode | null>(null);

  const [budget, setBudget] =
    useState<number | null>(null);

  const [firstName, setFirstName] =
    useState('');

  const [lastName, setLastName] =
    useState('');

  // Persona verilerini fetch
  const {
    data: personas = [],
    isLoading
  } = useQuery({
    queryKey: ['personas'],

    queryFn: async () => {
      const response =
        await api.get<Persona[]>('/personas');

      return response;
    }
  });

  // Profili oluşturma / güncelleme
  const mutation = useMutation({
    mutationFn: async () => {
      return api.put('/profile', {
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        personaCode: selectedPersona,
        monthlyBudget: budget
      });
    },

    onSuccess: () => {
      navigate('/explore');
    }
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
        padding: '0 20px'
      }}
    >
      <h1>Başlayalım</h1>

      <p
        className="muted"
        style={{
          marginBottom: '32px'
        }}
      >
        Sana en uygun rotaları çizebilmemiz için
        profilini oluştur.
      </p>

      {/* Profil Bilgileri */}
      <div
        style={{
          marginBottom: '32px'
        }}
      >
        <h2
          style={{
            fontSize: '1.2rem',
            marginBottom: '16px'
          }}
        >
          1. Profil Bilgileri
        </h2>

        <div
          style={{
            display: 'grid',
            gap: '16px'
          }}
        >
          {/* Ad */}
          <div>
            <label
              htmlFor="firstName"
              style={{
                display: 'block',
                marginBottom: '8px',
                fontWeight: 500
              }}
            >
              Ad
            </label>

            <input
              id="firstName"
              type="text"
              value={firstName}
              onChange={(e) =>
                setFirstName(e.target.value)
              }
              placeholder="Adınız"
              required
              style={{
                width: '100%',
                padding: '12px',
                border: '1px solid #ddd',
                borderRadius: '8px',
                fontSize: '16px',
                boxSizing: 'border-box'
              }}
            />
          </div>

          {/* Soyad */}
          <div>
            <label
              htmlFor="lastName"
              style={{
                display: 'block',
                marginBottom: '8px',
                fontWeight: 500
              }}
            >
              Soyad
            </label>

            <input
              id="lastName"
              type="text"
              value={lastName}
              onChange={(e) =>
                setLastName(e.target.value)
              }
              placeholder="Soyadınız"
              required
              style={{
                width: '100%',
                padding: '12px',
                border: '1px solid #ddd',
                borderRadius: '8px',
                fontSize: '16px',
                boxSizing: 'border-box'
              }}
            />
          </div>
        </div>
      </div>

      {/* Persona Seçimi */}
      <div
        style={{
          marginBottom: '32px'
        }}
      >
        <h2
          style={{
            fontSize: '1.2rem',
            marginBottom: '16px'
          }}
        >
          2. Persona Seçimi
        </h2>

        {isLoading ? (
          <p>Yükleniyor...</p>
        ) : personas.length === 0 ? (
          <p className="muted">
            Persona listesi yüklenemedi.
            Lütfen tekrar deneyin.
          </p>
        ) : (
          <div>
            {personas.map((p) => (
              <PersonaCard
                key={p.code}
                code={p.code}
                displayNameTr={p.displayNameTr}
                descriptionTr={p.descriptionTr}
                isSelected={
                  selectedPersona === p.code
                }
                onSelect={(code) =>
                  setSelectedPersona(
                    code as PersonaCode
                  )
                }
              />
            ))}
          </div>
        )}
      </div>

      {/* Bütçe */}
      <div
        style={{
          marginBottom: '40px'
        }}
      >
        <h2
          style={{
            fontSize: '1.2rem',
            marginBottom: '16px'
          }}
        >
          3. Aylık Kira Bütçesi
        </h2>

        <BudgetInput
          value={budget}
          onChange={setBudget}
        />
      </div>

      {/* Anchor Paneli */}
      <div
        style={{
          borderTop: '1px solid #eee',
          paddingTop: '32px',
          marginBottom: '32px'
        }}
      >
        <h2
          style={{
            fontSize: '1.2rem',
            marginBottom: '16px'
          }}
        >
          4. Önemli Konumlar (Anchor)
        </h2>

        <AnchorPanel />
      </div>

      {/* Kaydet */}
      <button
        onClick={() => mutation.mutate()}
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
              : 'pointer'
        }}
      >
        {mutation.isPending
          ? 'Kaydediliyor...'
          : 'Kaydet ve Başla'}
      </button>
    </section>
  );
}