import { Check } from 'lucide-react';

/**
 * Onboarding sihirbazının adım göstergesi.
 *
 * Bu blok `LifestyleSelection`, `PreferencesRanking` ve `BudgetSelection`
 * içinde ÜÇ KEZ, satır içi `style` nesneleriyle kopyalanmıştı. Kopyalar
 * birbirinden çoktan ayrışmıştı: yuvarlak çapı bir sayfada 28px, ötekinde
 * 26px; etiket boşluğu 4px ve 3px; ikon 14px ve 13px. Aynı gösterge, üç
 * ayrı ölçüde çiziliyordu ve kullanıcı adımlar arasında geçerken bileşen
 * gözle görülür biçimde zıplıyordu.
 *
 * Görsel kararların tamamı `index.css`'teki `.wizard-step*` sınıflarında;
 * burada yalnızca hangi adımın nerede olduğu var.
 */

/* Dışa AÇILMADI: dosya yalnızca bileşen dışa aktarınca Vite'ın hızlı
   yenilemesi (fast refresh) çalışıyor — yanına bir sabit eklenince
   sihirbaz sayfaları her düzenlemede tam yeniden yükleniyor. */
const WIZARD_STEPS = ['Profil', 'Yaşam Tarzı', 'Tercihler', 'Bütçe'] as const;

interface WizardStepsProps {
  /** 1 tabanlı aktif adım numarası. */
  current: number;
}

export function WizardSteps({ current }: WizardStepsProps) {
  // İlerleme çizgisinin dolu kısmı. Aralık adım SAYISI değil adım
  // ARALIĞI üzerinden: dört adımda üç aralık var, ilk adımda çizgi
  // tamamen boş olmalı.
  const progress = Math.min(
    Math.max((current - 1) / (WIZARD_STEPS.length - 1), 0),
    1,
  );

  return (
    <div className="wizard-steps">
      <ol
        className="wizard-steps-track"
        style={{ '--progress': progress } as React.CSSProperties}
      >
        {WIZARD_STEPS.map((label, index) => {
          const step = index + 1;
          const done = step < current;
          const active = step === current;

          return (
            <li
              key={label}
              className={`wizard-step${done ? ' wizard-step--done' : ''}${
                active ? ' wizard-step--active' : ''
              }`}
              // Ekran okuyucu adımın durumunu görsel işaretten okuyamaz.
              aria-current={active ? 'step' : undefined}
            >
              <span className="wizard-step-dot">
                {done ? <Check aria-hidden="true" /> : step}
              </span>
              <span className="wizard-step-label">{label}</span>
              {/* Görsel gösterge "tamamlandı"yı bir tikle anlatıyor;
                  ekran okuyucu için karşılığını metne dökmek gerekiyor. */}
              {done && <span className="sr-only">tamamlandı</span>}
            </li>
          );
        })}
      </ol>
    </div>
  );
}
