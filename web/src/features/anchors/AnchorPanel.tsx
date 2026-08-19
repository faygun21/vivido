import { MAX_ANCHORS } from '@vivido/shared';

/**
 * Anchor paneli — SAHİBİ: Kişi 3 · Hafta 1 Gün 4-5
 *
 * Kendi kendine yeten bir bileşen. Hem onboarding'in 3. adımında,
 * hem de /profile sayfasında kullanılır — bu yüzden route'a değil
 * bileşene bağlı yazılmalı.
 *
 * YAPILACAK:
 *   · api.get<Anchor[]>('/profile/anchors')
 *   · haritaya tıkla → nokta koy → etiket gir → mod seç (foot | car)
 *   · api.post<Anchor>('/profile/anchors', { label, lat, lon, mode })
 *       ⚠️ priority GÖNDERME — sunucu atar (K-G)
 *   · dnd-kit ile sürükle-bırak sıralama
 *   · bırakıldığı anda api.put('/profile/anchors/order', { order: id[] })
 *   · anchorWeights(n) ile ağırlıkları göster — ZATEN YAZILI, import et
 *   · 422 + ANCHOR_LIMIT_EXCEEDED → "En fazla 3 yer"
 *
 * Sözleşme: vivido-api-sozlesmesi.md §4
 * Kabul kriteri: docs/00-KAPSAM.md → W4  (en kritik test)
 *
 * NOT: Hafta 1'de skor yok, yalnızca sıra kaydediliyor.
 * Skor tepkisi Hafta 2'de bağlanacak.
 */
export function AnchorPanel() {
  return (
    <div className="anchor-panel">
      <h2>Düzenli gittiğin yerler</h2>
      <p className="muted">
        En fazla {MAX_ANCHORS} yer ekleyebilirsin. Önem sırasına dizdiğinde
        skorlar bu sıraya göre yeniden hesaplanır.
      </p>
      <p className="muted">Bu panel Hafta 1 Gün 4-5'te tamamlanacak.</p>
    </div>
  );
}
