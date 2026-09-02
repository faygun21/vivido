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

  /*
    Görsel kararlar `index.css`'teki `.mascot*` sınıflarına taşındı.
    Maskot uygulamanın BEŞİNCİ turuncusunu (`#e06d3b`) kullanıyordu ve
    `transition: all 0.3s` ile `left`/`bottom` gibi YERLEŞİM tetikleyen
    özellikleri animasyonluyordu — harita gibi ağır bir sahnede her
    karede yeniden hesap demek.

    Konum burada kalıyor çünkü `wideScreen`/`isOpen` ikilisine bağlı ve
    CSS'in bilmediği bir React durumundan geliyor; ama artık `left`
    yerine `transform` üzerinden — kaydırma derleyicide olur, yerleşimi
    hiç dokundurmaz.
  */
  const parked = !isOpen;

  /*
    Duruş EKRAN GENİŞLİĞİNE bağlı: panelden sarkan/tutunan görseller
    (`mascot_on_the_wall`, `mascot_2`) yaslanacak bir kenar olduğunu
    varsayıyor — geniş ekranda çekmecenin duvarı, dar ekranda alt
    sayfanın üst kenarı.

    ⚠️ Kapalıyken AYRI bir görsel (`mascot.png`) kullanılıyordu; artık
    kullanılmıyor çünkü maskot panel kapanınca ekrandan tamamen çıkıyor
    (bkz. `.mascot.is-parked`). Görseli tam da çıkış animasyonunun
    başladığı karede değiştirmek, giderken bir anlık "başka bir maskot"
    kırpması üretiyordu.
  */
  const figureSrc = wideScreen ? '/mascot_on_the_wall.png' : '/mascot_2.png';

  return (
    <div
      className={`mascot${wideScreen ? ' mascot--wide' : ''}${
        parked ? ' is-parked' : ''
      }`}
      aria-hidden={parked}
    >
      <img
        src={figureSrc}
        alt="Rehber Maskot"
        className="mascot-figure"
        // Sürüklenip sekmeye/masaüstüne bırakılabiliyordu — bir arayüz
        // ögesi, indirilecek bir resim değil (bkz. `.mascot-figure`).
        draggable={false}
        onClick={() => {
          setIsBubbleVisible((prev) => !prev);
          if (!isTourActive) {
            setIsTourActive(true);
            setCurrentStepIndex(0);
          }
        }}
      />

      {isBubbleVisible && (
        /* Balon maskotun ÜSTÜNDEN, ona doğru büyüyerek açılır:
           `transform-origin` sivri ucun olduğu köşede. Merkezden
           büyüyen bir balon hangi karakterin konuştuğunu anlatmaz. */
        <div className="mascot-bubble" role="dialog" aria-label="Rehber">
          <div className="mascot-bubble-head">
            <span className="mascot-step">
              {currentStepIndex + 1} / {steps.length}
            </span>
            <button
              type="button"
              className="mascot-close"
              onClick={handleSkip}
              aria-label="Rehberi kapat"
            >
              ✕
            </button>
          </div>

          {currentStep.title && <h4 className="mascot-title">{currentStep.title}</h4>}

          <p className="mascot-text">{currentStep.text}</p>

          {/* İlerleme çizgisi: kaç adım kaldığını "3 / 7" metnini
              okumadan gösterir. */}
          <div className="mascot-progress" aria-hidden="true">
            <span
              className="mascot-progress-fill"
              style={{ width: `${((currentStepIndex + 1) / steps.length) * 100}%` }}
            />
          </div>

          <div className="mascot-actions">
            {currentStepIndex > 0 ? (
              <button type="button" className="mascot-back" onClick={handlePrev}>
                Geri
              </button>
            ) : (
              <button type="button" className="mascot-skip" onClick={handleSkip}>
                Geç
              </button>
            )}

            <button type="button" className="mascot-next" onClick={handleNext}>
              {isLastStep ? 'Tamamla' : 'İleri'}
            </button>
          </div>

          <span className="mascot-arrow" aria-hidden="true" />
        </div>
      )}
    </div>
  );
}