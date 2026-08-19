import { AnchorPanel } from '@/features/anchors/AnchorPanel';

/**
 * Onboarding — SAHİBİ: Kişi 2 · Hafta 1 Gün 3-4
 *
 * Üç adım (docs/01-PROJE-PLANI.md §11.1):
 *   1. Persona seç  (4 kart)      → Kişi 2
 *   2. Bütçe gir                  → Kişi 2
 *   3. Anchor ekle & sırala       → Kişi 3'ün <AnchorPanel /> bileşeni
 *
 * ⚠️ SINIR: 3. adımın içeriğini BURAYA yazma. Kişi 3'ün
 * `features/anchors/AnchorPanel.tsx` bileşenini çağır — böylece
 * ikiniz aynı dosyada çakışmazsınız.
 *
 * YAPILACAK (Kişi 2):
 *   · api.get<Persona[]>('/personas')  — TanStack Query ile
 *   · 4 persona kartı, seçim durumu
 *   · aylık kira bütçesi girişi (boş bırakılabilir → null)
 *   · api.put<UserProfile>('/profile', { personaCode, monthlyBudget })
 *   · tamamlanınca /explore'a yönlendir
 *
 * Kabul kriteri: docs/00-KAPSAM.md → W2
 */
export function OnboardingPage() {
  return (
    <section className="page">
      <h1>Başlayalım</h1>
      <p className="muted">
        Persona seçimi ve bütçe adımları Hafta 1 Gün 3-4'te tamamlanacak.
      </p>

      <AnchorPanel />
    </section>
  );
}
