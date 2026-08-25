import { useState, useEffect } from 'react';
import { Check, ArrowRight } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useQueryClient } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';

interface Persona {
  id: string;
  title: string;
  description: string;
  mainIcon: string;
  subIcons: string[];
}

// id'ler `personas.code` (backend) ile birebir aynı olmalı — aksi hâlde
// PUT /profile personaCode'u tanımıyor demektir.
const personas: Persona[] = [
  {
    id: 'student',
    title: 'Öğrenci',
    description: 'Ulaşım, üniversite ve sosyal yaşam öncelikli',
    mainIcon: '/kep.svg',
    subIcons: ['/bus.svg', '/school.svg', '/cafe.svg'],
  },
  {
    id: 'remote_worker',
    title: 'Uzaktan Çalışan',
    description: 'Cafe, spor ve sosyal alanlar öncelikli',
    mainIcon: '/pc.svg',
    subIcons: ['/cafe.svg', '/sport_kahve.svg', '/park.svg'],
  },
  {
    id: 'family_kids',
    title: 'Çocuklu Aile',
    description: 'Eğitim, market ve park alanları öncelikli',
    mainIcon: '/family.svg',
    subIcons: ['/school.svg', '/avm.svg', '/park.svg'],
  },
  {
    id: 'elderly',
    title: 'Emekli',
    description: 'Sağlık, günlük ihtiyaçlar ve sakin yaşam öncelikli',
    mainIcon: '/glasses.svg',
    subIcons: ['/hastane.svg', '/avm.svg', '/park.svg'],
  },
];

/**
 * Kayıt formu ad+soyadı `${firstName} ${lastName}`.trim() olarak TEK bir
 * `displayName`'de birleştirip gönderiyor (bkz. RegisterPage.tsx). Burada
 * tersini yapıp ayırıyoruz — kullanıcıya adını tekrar SORMAMAK için.
 * Soyadı yoksa (tek kelimelik displayName) boş bırakıyoruz; backend
 * LastName'i zorunlu istiyor, boş string kabul ediyor.
 */
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

  useEffect(() => {
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = 'auto';
    };
  }, []);

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
      // Onboarding'in kendi profil sorgusu bayat kalmasın — az önce
      // yazdığımız persona'yı hemen görsün.
      await queryClient.invalidateQueries({ queryKey: ['profile'] });
      // Bütçe/anchor gibi geri kalan alanlar hâlâ eksik; onboarding formu
      // onları tamamlıyor. NOT: OnboardingPage şu an persona seçimini var
      // olan profilden ÖNCEDEN DOLDURMUYOR (selectedPersona her zaman null
      // başlıyor) — kullanıcı burada seçtiği persona'yı orada bir kez daha
      // seçmek zorunda kalacak. Sorun değil (DB'de zaten kayıtlı, formu
      // atlarsa da persona kaybolmaz) ama kullanıcı deneyimi için
      // OnboardingPage'e persona ön-doldurma eklemek ayrı bir iyileştirme.
      navigate('/onboarding');
    } catch {
      setError('Kaydedilemedi, lütfen tekrar deneyin.');
    } finally {
      setSaving(false);
    }
  }

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
      padding: '24px 32px',
      fontFamily: 'sans-serif',
      boxSizing: 'border-box',
      overflow: 'hidden',
      zIndex: 9999
    }}>
      
      {/* ÜST KISIM: 5 Adımlı Stepper */}
      <div style={{ maxWidth: '600px', margin: '0 auto', width: '100%' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', position: 'relative' }}>
          <div style={{ position: 'absolute', left: '30px', right: '30px', top: '50%', transform: 'translateY(-50%)', height: '2px', backgroundColor: '#d6d3d1', zIndex: 0 }}></div>

          {[
            { step: 1, label: 'Profil', status: 'completed' },
            { step: 2, label: 'Yaşam Tarzı', status: 'active' },
            { step: 3, label: 'Tercihler', status: 'pending' },
            { step: 4, label: 'Bütçe', status: 'pending' },
            { step: 5, label: 'Özel Konumlar', status: 'pending' },
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

      {/* ORTA KISIM: Başlık ve Kartlar */}
      <div style={{ maxWidth: '720px', margin: '0 auto', width: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <h1 style={{ fontSize: '32px', fontFamily: 'serif', fontWeight: 'bold', color: '#1c1917', textAlign: 'center', marginBottom: '6px' }}>
          Seni biraz tanıyalım
        </h1>
        <p style={{ color: '#57534e', textAlign: 'center', marginBottom: '20px', fontSize: '14px' }}>
          Yaşam tarzına en yakın profili seç. Tüm tercihlerini daha sonra özelleştirebilirsin.
        </p>

        {/* Kartlar Grid Yapısı (2x2) */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '14px', width: '100%', marginBottom: '14px' }}>
          {personas.map((persona) => {
            const isSelected = selectedId === persona.id;
            return (
              <div
                key={persona.id}
                onClick={() => setSelectedId(persona.id)}
                style={{
                  position: 'relative',
                  padding: '18px 20px',
                  borderRadius: '16px',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                  border: isSelected ? '1px solid #C26927' : '1px solid rgba(214, 211, 209, 0.8)',
                  backgroundColor: isSelected ? '#FAF6F0' : '#F7F4EE',
                  boxShadow: isSelected ? '0 2px 4px rgba(0,0,0,0.06)' : 'none',
                  display: 'flex',
                  flexDirection: 'column',
                  justifyContent: 'space-between'
                }}
              >
                {isSelected && (
                  <div style={{ position: 'absolute', top: '14px', right: '14px', width: '20px', height: '20px', backgroundColor: '#C26927', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#ffffff' }}>
                    <Check size={11} />
                  </div>
                )}

                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px' }}>
                  <div style={{ width: '40px', height: '40px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, backgroundColor: isSelected ? '#EBDAD0' : '#EFECE6' }}>
                    <img src={persona.mainIcon} alt={persona.title} style={{ width: '20px', height: '20px', objectFit: 'contain' }} />
                  </div>

                  <div style={{ paddingRight: '12px' }}>
                    <h3 style={{ fontFamily: 'serif', fontWeight: 'bold', fontSize: '16px', marginBottom: '3px', color: isSelected ? '#C26927' : '#1c1917' }}>
                      {persona.title}
                    </h3>
                    <p style={{ color: '#57534e', fontSize: '13px', lineHeight: '1.35', marginBottom: '8px' }}>
                      {persona.description}
                    </p>

                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      {persona.subIcons.map((subIcon, idx) => (
                        <img key={idx} src={subIcon} alt="sub-icon" style={{ width: '16px', height: '16px', objectFit: 'contain', opacity: 0.7 }} />
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        <button style={{ background: 'none', border: 'none', color: '#78716c', fontSize: '13px', textDecoration: 'underline', textUnderlineOffset: '3px', cursor: 'pointer' }}>
          Kendim Özelleştireceğim
        </button>
      </div>

      {/* ALT KISIM: Navigasyon Butonları */}
      <div style={{ maxWidth: '720px', margin: '0 auto', width: '100%', display: 'flex', flexDirection: 'column', gap: '8px', paddingTop: '16px', borderTop: '1px solid #e7e5e4' }}>
        {error && (
          <p style={{ color: '#b91c1c', fontSize: '13px', margin: 0, textAlign: 'center' }}>{error}</p>
        )}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button style={{ padding: '8px 22px', borderRadius: '8px', border: '1px solid #d6d3d1', backgroundColor: 'transparent', color: '#44403c', fontSize: '14px', fontWeight: 500, cursor: 'pointer' }}>
            Geri
          </button>
          <button
            onClick={handleNext}
            disabled={saving}
            style={{ padding: '8px 24px', borderRadius: '8px', backgroundColor: '#C26927', color: '#ffffff', fontSize: '14px', fontWeight: 500, border: 'none', cursor: saving ? 'not-allowed' : 'pointer', opacity: saving ? 0.7 : 1, display: 'flex', alignItems: 'center', gap: '6px' }}
          >
            {saving ? 'Kaydediliyor…' : 'Devam Et'} <ArrowRight size={16} />
          </button>
        </div>
      </div>

    </div>
  );
}