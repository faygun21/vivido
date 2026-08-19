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
  const [selectedPersona, setSelectedPersona] = useState<PersonaCode | null>(null);
  const [budget, setBudget] = useState<number | null>(null);

  // persona verilerini fetch
  const { data: personas = [], isLoading } = useQuery({
    queryKey: ['personas'],
    queryFn: async () => {
      const response = await api.get<Persona[]>('/personas');
      return response; 
    }
  });

  //profili güncelleme
  const mutation = useMutation({
    mutationFn: async () => {
      return api.put('/profile', { 
        personaCode: selectedPersona, 
        monthlyBudget: budget 
      });
    },
    onSuccess: () => {
      navigate('/explore');
    }
  });

  return (
    <section className="page" style={{ maxWidth: '600px', margin: '40px auto', padding: '0 20px' }}>
      <h1>Başlayalım</h1>
      <p className="muted" style={{ marginBottom: '32px' }}>
        Sana en uygun rotaları çizebilmemiz için profilini seç.
      </p>

      {/* Persona Seçimi */}
      <div style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '16px' }}>1. Persona Seçimi</h2>
        {isLoading ? (
          <p>Yükleniyor...</p>
        ) : (
          <div>
            {personas.map((p) => (
              <PersonaCard
                key={p.code}
                code={p.code}
                displayNameTr={p.displayNameTr}
                descriptionTr={p.descriptionTr}
                isSelected={selectedPersona === p.code}
                onSelect={(code) => setSelectedPersona(code as PersonaCode)}
              />
            ))}
          </div>
        )}
      </div>

      {/* Bütçe */}
      <div style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '16px' }}>2. Aylık Kira Bütçesi</h2>
        <BudgetInput value={budget} onChange={setBudget} />
      </div>

      {/* Anchor Paneli */}
      <div style={{ borderTop: '1px solid #eee', paddingTop: '32px', marginBottom: '32px' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '16px' }}>3. Önemli Konumlar (Anchor)</h2>
        <AnchorPanel />
      </div>
      <button 
        onClick={() => mutation.mutate()}
        disabled={!selectedPersona || mutation.isPending}
        style={{
          padding: '16px', 
          width: '100%',
          backgroundColor: (!selectedPersona || mutation.isPending) ? '#ccc' : '#000',
          color: '#fff',
          border: 'none',
          borderRadius: '8px',
          fontSize: '16px',
          fontWeight: 'bold',
          cursor: (!selectedPersona || mutation.isPending) ? 'not-allowed' : 'pointer'
        }}
      >
        {mutation.isPending ? 'Kaydediliyor...' : 'Kaydet ve Başla'}
      </button>
    </section>
  );
}