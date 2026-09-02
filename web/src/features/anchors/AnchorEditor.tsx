import { useEffect, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import {
  DndContext,
  PointerSensor,
  closestCenter,
  useSensor,
  useSensors,
  type DragEndEvent,
} from '@dnd-kit/core';
import {
  SortableContext,
  arrayMove,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import type { Anchor, TravelMode } from '@vivido/shared';
import { MAX_ANCHORS } from '@vivido/shared';
import { ApiError, api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import type { MapPoint } from '@/shared/map/CankayaMap';

/**
 * Anchor listesi + ekleme formu — HARİTASIZ (W4).
 *
 * Haritadan ayrıldı çünkü iki farklı yerde iki farklı harita besliyor:
 *   · `AnchorPanel` (profil sayfası, onboarding) → kendi gömülü 320px haritası
 *   · Explore çekmecesi → arkadaki TAM EKRAN Çankaya haritası
 *
 * Bu yüzden seçilen nokta **kontrollü**: `pending` dışarıdan gelir, editör
 * yalnızca "şu noktayı isimlendir ve kaydet" işini yapar. Aksi halde explore
 * çekmecesinin içine ikinci bir harita gömmek gerekirdi — haritanın üstünde
 * harita.
 *
 * ⚠️ `priority` GÖNDERİLMEZ — sunucu atar (K-G).
 */

export interface AnchorEditorProps {
  /** Haritada seçilmiş, henüz isimlendirilmemiş nokta. */
  pending: MapPoint | null;
  onPendingChange: (point: MapPoint | null) => void;
  /**
   * "Yer ekle" düğmesine basıldığında çağrılır. Explore'da haritayı nokta
   * seçme moduna alır; gömülü haritalı kullanımda gerekmez.
   */
  onRequestPick?: () => void;
  /** Nokta seçme modu açık mı — düğme durumunu buna göre çiziyoruz. */
  picking?: boolean;
  /**
   * Nokta adres aramasından geldiyse bulunan yerin adı — etiket alanına
   * hazır yazılır. Haritaya tıklayarak seçilen noktalarda `null` gelir ve
   * alan boşalır (önceki aramadan kalan ad orada kalmasın).
   */
  suggestedLabel?: string | null;
}

export function AnchorEditor({
  pending,
  onPendingChange,
  onRequestPick,
  picking = false,
  suggestedLabel = null,
}: AnchorEditorProps) {
  const queryClient = useQueryClient();
  const [label, setLabel] = useState('');
  const [error, setError] = useState<string | null>(null);

  // Öneri DEĞİŞTİĞİNDE yazılır, her render'da değil — kullanıcı hazır gelen
  // adı silip kendi etiketini yazdıysa (ör. "Kızılay" → "İş") bir sonraki
  // render onu geri getirmemeli.
  useEffect(() => {
    setLabel(suggestedLabel ?? '');
  }, [suggestedLabel]);

  const { data: anchors = [], isLoading, error: loadError } = useSessionQuery({
    queryKey: ['anchors'],
    queryFn: () => api.get<Anchor[]>('/profile/anchors'),
    retry: false,
  });

  // K-C: profil ilk `PUT /profile` ile oluşur. Onboarding'in 3. adımında
  // kullanıcı henüz kaydetmediyse burası 404 döner — bu bir hata değil,
  // beklenen sıralama. Panel yerine yönlendirici bir not gösteriyoruz.
  const profileMissing =
    loadError instanceof ApiError && loadError.problem.code === 'PROFILE_NOT_FOUND';

  // `useSessionQuery` anahtarın SONUNA oturum kimliğini ekliyor
  // (`['anchors', 'user:42']`). TanStack önek eşleştirdiği için buradaki
  // kimliksiz anahtarlar aktif kullanıcının sorgusunu yakalamaya devam
  // eder — mutasyonlarda kimlik taşımak gerekmiyor.
  function invalidate() {
    void queryClient.invalidateQueries({ queryKey: ['anchors'] });
    // Profil de anchor listesi taşıyor; explore haritası ondan besleniyor.
    void queryClient.invalidateQueries({ queryKey: ['profile'] });
    // Anchor eklenince/silinince/sırası değişince arama alanı (merkez +
    // yarıçap) da değişir — /properties (harita pinleri + "En uygun evler")
    // tazelenmezse eski alana göre hesaplanmış sonuçlar ekranda kalır.
    // Aynı hata daha önce kayıt sihirbazındaki persona/bütçe adımlarında da
    // vardı (bkz. LifestyleSelection/BudgetSelection'daki aynı düzeltme).
    void queryClient.invalidateQueries({ queryKey: ['properties'] });
  }

  const createMutation = useMutation({
    mutationFn: (body: { label: string; lat: number; lon: number; mode: TravelMode }) =>
      api.post<Anchor>('/profile/anchors', body),
    onSuccess: () => {
      onPendingChange(null);
      setLabel('');
      setError(null);
      invalidate();
    },
    onError: (err) => setError(describeAnchorError(err)),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete<void>(`/profile/anchors/${id}`),
    onSuccess: invalidate,
    onError: (err) => setError(describeAnchorError(err)),
  });

  const reorderMutation = useMutation({
    mutationFn: (order: string[]) => api.put<Anchor[]>('/profile/anchors/order', { order }),
    onSuccess: invalidate,
    onError: (err) => setError(describeAnchorError(err)),
  });

  // Sürükleme başlamadan önce 6px eşik: basit tıklamalar (sil butonu)
  // yanlışlıkla sürükleme sayılmasın.
  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 6 } }));

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    const oldIndex = anchors.findIndex((a) => a.id === active.id);
    const newIndex = anchors.findIndex((a) => a.id === over.id);
    if (oldIndex < 0 || newIndex < 0) return;

    const next = arrayMove(anchors, oldIndex, newIndex);
    // Sunucu tüm listeyi bekliyor; eksik gönderirsek 422 döner.
    reorderMutation.mutate(next.map((a) => a.id));
  }

  const full = anchors.length >= MAX_ANCHORS;

  if (profileMissing) {
    return (
      <p className="notice">
        Yer eklemek için önce <strong>persona seçip kaydetmen</strong> gerekiyor.
        Kaydettikten sonra bu panel açılacak.
      </p>
    );
  }

  return (
    <div className="anchor-editor">
      {error && <p className="form-error" role="alert">{error}</p>}

      <div className="anchor-editor-head">
        <span className="section-count">
          {anchors.length} / {MAX_ANCHORS}
        </span>

        {onRequestPick && !pending && (
          <button
            className={`btn-chip${picking ? ' is-active' : ''}`}
            type="button"
            onClick={onRequestPick}
            disabled={full}
            title={full ? `En fazla ${MAX_ANCHORS} yer eklenebilir.` : 'Haritadan yer seç'}
          >
            {picking ? 'Haritaya tıkla…' : '+ Yer ekle'}
          </button>
        )}
      </div>

      {pending && (
        <form
          className="anchor-form"
          onSubmit={(e) => {
            e.preventDefault();
            if (!label.trim()) { setError('Bir etiket gir (ör. "Üniversite").'); return; }
            // Ulaşım şekli artık kullanıcıya sorulmuyor — koridor hesabı
            // her bacak için gerçek yol tarifiyle zaten yürüme/araç arasında
            // kendisi karar veriyor (bkz. PropertiesController.
            // BuildCorridorLegsAsync: önce yaya, olmazsa araç dener). Bu
            // seçim yalnızca tek-anchor'lu ya da hiç yol bulunamayan nadir
            // durumda buffer genişliğini belirliyordu — kullanıcıya ekstra
            // bir soru sormaya değecek kadar etkili değildi.
            createMutation.mutate({ label: label.trim(), lat: pending.lat, lon: pending.lon, mode: 'car' });
          }}
        >
          <label className="field">
            <span>Etiket</span>
            <input
              value={label}
              onChange={(e) => setLabel(e.target.value)}
              placeholder="Örn. Hacettepe Beytepe"
              autoFocus
            />
          </label>

          <div className="row-actions">
            <button className="btn-primary btn-sm" type="submit" disabled={createMutation.isPending}>
              {createMutation.isPending ? 'Ekleniyor…' : 'Ekle'}
            </button>
            <button
              className="btn-secondary btn-sm"
              type="button"
              onClick={() => { onPendingChange(null); setError(null); }}
            >
              Vazgeç
            </button>
          </div>
        </form>
      )}

      {isLoading ? (
        <p className="muted">Yükleniyor…</p>
      ) : anchors.length === 0 ? (
        <p className="muted">
          Henüz yer eklemedin. Düzenli gittiğin yerleri ekleyip önem sırasına
          dizdiğinde skorlar bu sıraya göre hesaplanır.
        </p>
      ) : (
        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
          <SortableContext items={anchors.map((a) => a.id)} strategy={verticalListSortingStrategy}>
            <ol className="anchor-list">
              {anchors.map((anchor) => (
                <SortableAnchor
                  key={anchor.id}
                  anchor={anchor}
                  onDelete={() => deleteMutation.mutate(anchor.id)}
                />
              ))}
            </ol>
          </SortableContext>
        </DndContext>
      )}

      {reorderMutation.isPending && <p className="muted">Sıra kaydediliyor…</p>}
    </div>
  );
}

function SortableAnchor({
  anchor,
  onDelete,
}: {
  anchor: Anchor;
  onDelete: () => void;
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: anchor.id,
  });

  return (
    <li
      ref={setNodeRef}
      className={`anchor-item${isDragging ? ' anchor-item--dragging' : ''}`}
      // @dnd-kit/utilities'in CSS.Transform yardımcısı yerine elle yazıyoruz:
      // o paket web'in doğrudan bağımlılığı değil, sadece sortable'ın alt
      // bağımlılığı. Tek satırlık iş için lock dosyasını değiştirmeye değmez.
      style={{
        transform: transform ? `translate3d(${transform.x}px, ${transform.y}px, 0)` : undefined,
        transition,
      }}
    >
      <span className="anchor-grip" {...attributes} {...listeners} title="Sürükleyerek sırala">
        ⠿
      </span>
      <span className="anchor-order">{anchor.priority}</span>

      <span className="anchor-body">
        <strong>{anchor.label}</strong>
      </span>

      <button className="btn-icon" type="button" onClick={onDelete} title="Sil">
        ✕
      </button>
    </li>
  );
}

/** Dışa AÇILMIYOR: bileşen dosyasından bileşen olmayan bir şey dışa
 *  aktarılınca Vite'ın fast-refresh'i bu dosya için devre dışı kalıyor. */
function describeAnchorError(err: unknown): string {
  if (err instanceof ApiError) {
    switch (err.problem.code) {
      case 'ANCHOR_LIMIT_EXCEEDED':
        return `En fazla ${MAX_ANCHORS} yer ekleyebilirsin.`;
      case 'PROFILE_NOT_FOUND':
        return 'Önce persona seçip profilini kaydet.';
      case 'INVALID_ANCHOR_ORDER':
        return 'Sıralama kaydedilemedi, liste yeniden yüklendi.';
      default:
        return err.problem.title;
    }
  }
  return 'Beklenmeyen bir hata oluştu.';
}
