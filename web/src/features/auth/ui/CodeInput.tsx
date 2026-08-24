/**
 * 6 haneli doğrulama kodu girişi.
 *
 * Tek bir `input`, altı ayrı kutu değil: altı kutulu tasarım güzel görünür
 * ama yapıştırma, geri silme, otomatik doldurma ve ekran okuyucu davranışının
 * hepsini elle yazmayı gerektirir ve üçü de kolayca bozulur. Tek alan
 * `inputMode="numeric"` + `autocomplete="one-time-code"` ile telefonda SMS/
 * e-posta kodunu tarayıcının kendisi doldurabiliyor.
 */
export function CodeInput({
  value,
  onChange,
  label,
}: {
  value: string;
  onChange: (next: string) => void;
  label: string;
}) {
  return (
    <label className="field">
      <span>{label}</span>
      <input
        className="code-input"
        type="text"
        inputMode="numeric"
        autoComplete="one-time-code"
        // maxLength tek başına yetmez: yapıştırılan "123 456" 7 karakter.
        // Rakam dışını aşağıda zaten eliyoruz.
        maxLength={6}
        placeholder="000000"
        value={value}
        onChange={(e) => onChange(e.target.value.replace(/\D/g, '').slice(0, 6))}
        required
      />
    </label>
  );
}
