interface BudgetInputProps {
  minValue: number | null;
  maxValue: number | null;
  onMinChange: (value: number | null) => void;
  onMaxChange: (value: number | null) => void;
}

/**
 * Aylık kira aralığı girdisi.
 *
 * Satır içi `style` nesnelerinden token'lara taşındı: alanlar `#ccc`
 * kenarlık, `6px` yarıçap ve `16px` yazı kullanıyordu — üçü de
 * uygulamanın hiçbir yerindeki değerlerle uyuşmuyordu. Aynı ekranda,
 * hemen üstündeki Ad/Soyad alanları başka bir görünüme sahipti.
 *
 * İki alan yan yana: bir ARALIK tarif ediyorlar. Alt alta dizilince
 * iki bağımsız sayı gibi okunuyorlardı; ekran daraldığında (≤480px)
 * `.wizard-two-col` zaten alt alta düşürüyor.
 */
export function BudgetInput({
  minValue,
  maxValue,
  onMinChange,
  onMaxChange,
}: BudgetInputProps) {
  // Aralık ters çevrilmişse alanın KENDİSİ işaretlenmeli; sayfanın
  // altındaki tek satırlık uyarı, hangi alanın sorunlu olduğunu
  // söylemiyordu.
  const invalid = minValue !== null && maxValue !== null && minValue > maxValue;

  return (
    <div className="budget-input">
      <span className="profile-label" id="budget-input-label">
        Aylık Kira Aralığı (TL)
      </span>

      <div className="budget-input-row" role="group" aria-labelledby="budget-input-label">
        <div className="field">
          <input
            type="number"
            min="0"
            step="500"
            value={minValue ?? ''}
            onChange={(e) => onMinChange(e.target.value ? Number(e.target.value) : null)}
            placeholder="Minimum kira"
            aria-label="Minimum aylık kira"
            aria-invalid={invalid}
            className={invalid ? 'is-invalid' : undefined}
          />
        </div>

        {/* Görsel bağlaç: iki kutunun TEK bir aralık olduğunu söyler. */}
        <span className="budget-input-sep" aria-hidden="true">–</span>

        <div className="field">
          <input
            type="number"
            min="0"
            step="500"
            value={maxValue ?? ''}
            onChange={(e) => onMaxChange(e.target.value ? Number(e.target.value) : null)}
            placeholder="Maksimum kira"
            aria-label="Maksimum aylık kira"
            aria-invalid={invalid}
            className={invalid ? 'is-invalid' : undefined}
          />
        </div>
      </div>
    </div>
  );
}
