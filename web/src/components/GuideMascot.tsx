import { useState, useEffect } from 'react';
import { useWideScreen } from '@/shared/useWideScreen';
import { useAuthStore } from '@/features/auth/authStore';

export type DrawerTab = 'profil' | 'analiz' | 'rota' | 'harita';

export interface TourStep {
  title?: string;
  text: string;
  selector?: string; 
  targetTab?: DrawerTab; 
}

interface GuideMascotProps {
  isOpen: boolean;
  steps?: TourStep[];
  onTabChange?: (tab: DrawerTab) => void;
  onComplete?: () => void;
}

export function GuideMascot({ isOpen, steps: propSteps, onTabChange, onComplete }: GuideMascotProps) {
  const [currentStepIndex, setCurrentStepIndex] = useState(0);
  const [isBubbleVisible, setIsBubbleVisible] = useState(true);
  const [isTourActive, setIsTourActive] = useState(true);
  
  const wideScreen = useWideScreen();
  const isGuest = useAuthStore((s) => s.isGuest);

  const defaultSteps: TourStep[] = [
    {
      title: 'Hoş Geldin! 👋',
      text: 'Sana haritada en uygun kiralık evleri ve çevreyi nasıl keşfedeceğini göstereyim. Hazırsan başlayalım!',
    },
    {
      title: 'Arama Çubuğu 🔍',
      text: 'Buradan aradığın mahalleyi, caddeyi veya konumu aratarak haritayı direkt oraya odaklayabilirsin.',
      selector: '.drawer-head + div', 
    },
    {
      title: 'Profil Sekmesi 👤',
      text: isGuest
        ? 'Bu sekmeden profiline ulaşabilirsin. Ücretsiz hesap oluşturduğunda buradan sana özel seçimlerini yapabilir ve düzenli gittiğin yerleri ekleyebilirsin.'
        : 'Bu sekmede "Profili düzenle" diyerek seçimlerini değiştirebilir, "+ Yer ekle" butonuna tıklayarak düzenli gittiğin yerleri ekleyebilirsin.',
      targetTab: 'profil',
      selector: '.drawer-tabs button:nth-child(1)', 
    },
    {
      title: 'Konum Analizi 📍',
      text: 'Buradan analiz yapabilirsin. Seçtiğin bir konum etrafındaki analiz mesafesi ve yürüme süresini ayarlayarak çevreyi keşfedebilirsin.',
      targetTab: 'analiz',
      selector: '.drawer-tabs button:nth-child(2)', 
    },
    {
      title: 'Akıllı Rota 🗺️',
      text: isGuest
        ? 'Burası akıllı rota aracı! Haritadan seçtiğin evleri en mantıklı sırayla gezmek üzere rota planlayabilmek için tek yapman gereken giriş yapmak.'
        : 'Bu sekmeden rota oluşturabilirsin. Haritadan seçtiğin evleri en mantıklı sırayla gezmek için rotanı buradan planlayacaksın.',
      targetTab: 'rota',
      selector: '.drawer-tabs button:nth-child(3)', 
    },
    {
      title: 'Harita Katmanları 🏙️',
      text: 'Burada harita içinde görmek istediğin yerlerin (market, park vb.) görünürlüğüyle oynayabilir ve katmanları yönetebilirsin.',
      targetTab: 'harita',
      selector: '.drawer-tabs button:nth-child(4)', 
    },
    {
      title: 'En Uygun Evler ⭐',
      text: isGuest
        ? 'Giriş yaptığında sağ üstte "En Uygun Evler" butonu belirecek. Oraya tıklayarak profiline en uygun evlerin listesini ve skor detaylarını görebileceksin!'
        : 'Son olarak köşedeki bu butona tıklayarak sana en uygun evlerin listesini, puanlarını ve detaylarını görebilirsin.',
      targetTab: 'profil', 
      selector: '.top-panel-toggle', 
    },
    {
      title: 'Hazırsın! 🎉',
      text: 'Artık haritayı serbestçe keşfedebilirsin. İstediğin zaman bana tıklayarak ipuçlarını tekrar görebilirsin.',
    }
  ];

  const steps = propSteps ?? defaultSteps;
  const currentStep = steps[currentStepIndex];
  const isLastStep = currentStepIndex === steps.length - 1;

  useEffect(() => {
    if (!isOpen) {
      setIsBubbleVisible(false);
    }
  }, [isOpen]);

  useEffect(() => {
    if (!isTourActive || !isOpen || !isBubbleVisible) return;

    const step = steps[currentStepIndex];
    
    if (step.targetTab && onTabChange) {
      onTabChange(step.targetTab);
    }

    if (!step.selector) return;
    const targetSelector = step.selector as string;

    const timer = setTimeout(() => {
      const targetElement = document.querySelector(targetSelector) as HTMLElement | null;
      
      if (targetElement) {
        const originalOutline = targetElement.style.outline;
        const originalOutlineOffset = targetElement.style.outlineOffset;
        const originalBorderRadius = targetElement.style.borderRadius;
        const originalTransition = targetElement.style.transition;
        const originalBoxShadow = targetElement.style.boxShadow;
        const originalZIndex = targetElement.style.zIndex;

        targetElement.style.transition = 'all 0.3s ease';
        targetElement.style.outline = '3px solid #e06d3b';
        targetElement.style.outlineOffset = '4px';
        targetElement.style.borderRadius = '8px';
        targetElement.style.boxShadow = '0 0 15px rgba(224, 109, 59, 0.4)';
        targetElement.style.zIndex = '100';

        targetElement.scrollIntoView({ behavior: 'smooth', block: 'nearest' });

        targetElement.dataset.cleanup = 'true';
        targetElement.addEventListener(
          'cleanup-highlight',
          () => {
            targetElement.style.outline = originalOutline;
            targetElement.style.outlineOffset = originalOutlineOffset;
            targetElement.style.borderRadius = originalBorderRadius;
            targetElement.style.transition = originalTransition;
            targetElement.style.boxShadow = originalBoxShadow;
            targetElement.style.zIndex = originalZIndex;
          },
          { once: true }
        );
      }
    }, 100);

    return () => {
      clearTimeout(timer);
      const prevElement = document.querySelector(targetSelector) as HTMLElement | null;
      if (prevElement && prevElement.dataset.cleanup) {
        prevElement.dispatchEvent(new Event('cleanup-highlight'));
        delete prevElement.dataset.cleanup;
      }
    };
  }, [currentStepIndex, isTourActive, isOpen, isBubbleVisible, steps, onTabChange]);

  function handleNext() {
    if (isLastStep) {
      setIsTourActive(false);
      setIsBubbleVisible(false);
      if (onComplete) onComplete();
    } else {
      setCurrentStepIndex((prev) => prev + 1);
    }
  }

  function handlePrev() {
    if (currentStepIndex > 0) {
      setCurrentStepIndex((prev) => prev - 1);
    }
  }

  function handleSkip() {
    setIsTourActive(false);
    setIsBubbleVisible(false);
    if (onComplete) onComplete();
  }

  return (
    <div
      style={{
        position: 'absolute',
        bottom: wideScreen ? '20px' : (isOpen ? 'calc(45% - 24px)' : '0px'),
        left: wideScreen ? (isOpen ? '343px' : '-200px') : (isOpen ? '15px' : '-200px'),
        transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
        zIndex: 1000,
        display: 'flex',
        alignItems: 'flex-end',
        gap: '12px',
        pointerEvents: 'none',
      }}
    >
      <img
        src={wideScreen ? "/mascot.png" : "/mascot_2.png"}
        alt="Rehber Maskot"
        style={{
          display: 'block',
          width: wideScreen ? '75px' : '65px',
          height: 'auto',
          filter: 'drop-shadow(0 4px 8px rgba(0,0,0,0.15))',
          pointerEvents: 'auto',
          cursor: 'pointer',
        }}
        onClick={() => {
          setIsBubbleVisible((prev) => !prev);
          if (!isTourActive) {
            setIsTourActive(true);
            setCurrentStepIndex(0);
          }
        }}
      />

      {isBubbleVisible && (
        <div
          style={{
            backgroundColor: '#F0EEE9',
            padding: '14px 16px',
            borderRadius: '16px',
            boxShadow: '0 8px 24px rgba(0,0,0,0.15)',
            position: 'absolute',
            bottom: '100%',
            left: wideScreen ? '10px' : '0px',
            marginBottom: '10px',
            width: '230px',
            pointerEvents: 'auto',
            border: '1px solid #f0eee9',
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
            <span style={{ fontSize: '11px', fontWeight: 600, color: '#e06d3b' }}>
              {currentStepIndex + 1} / {steps.length}
            </span>
            <button
              onClick={handleSkip}
              style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#a8a29e', fontSize: '12px', padding: '2px' }}
            >
              ✕
            </button>
          </div>

          {currentStep.title && (
            <h4 style={{ margin: '0 0 4px 0', fontSize: '13px', color: '#1c1917', fontWeight: 700 }}>
              {currentStep.title}
            </h4>
          )}

          <p style={{ margin: '0 0 12px 0', fontSize: '12px', color: '#44403c', lineHeight: '1.4' }}>
            {currentStep.text}
          </p>

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '8px' }}>
            {currentStepIndex > 0 ? (
              <button
                onClick={handlePrev}
                style={{ background: 'none', border: '1px solid #e7e5e4', borderRadius: '6px', padding: '4px 8px', fontSize: '11px', cursor: 'pointer', color: '#57534e' }}
              >
                Geri
              </button>
            ) : (
              <button
                onClick={handleSkip}
                style={{ background: 'none', border: 'none', fontSize: '11px', cursor: 'pointer', color: '#a8a29e', padding: 0 }}
              >
                Geç
              </button>
            )}

            <button
              onClick={handleNext}
              style={{ backgroundColor: '#e06d3b', color: '#F0EEE9', border: 'none', borderRadius: '6px', padding: '5px 12px', fontSize: '11px', fontWeight: 600, cursor: 'pointer' }}
            >
              {isLastStep ? 'Tamamla' : 'İleri'}
            </button>
          </div>

          <div
            style={{ 
              position: 'absolute', 
              bottom: '-8px', 
              left: wideScreen ? '20px' : '30px', 
              width: 0, height: 0, 
              borderLeft: '8px solid transparent', 
              borderRight: '8px solid transparent', 
              borderTop: '8px solid #F0EEE9' 
            }}
          />
        </div>
      )}
    </div>
  );
}