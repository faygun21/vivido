import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
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
import { MAX_ANCHORS, anchorWeights } from '@vivido/shared';
import { ApiError, api } from '@/shared/api/client';
import { CankayaMap, type MapPoint } from '@/shared/map/CankayaMap';

/**
 * Anchor paneli — W4.
 *
 * Akış: haritaya tıkla → nokta seçilir → etiket + mod gir → kaydet.
 * Sıralama sürükle-bırakla değişir, bırakıldığı an sunucuya yazılır.
 *
 * ⚠️ `priority` GÖNDERİLMEZ — sunucu atar (K-G).
 * ⚠️ `anchorWeights()` packages/shared'da ZATEN yazılı, import ediliyor.
 *
 * Sözleşme: vivido-api-sozlesmesi.md §4 · Kabul kriteri: 00-KAPSAM.md → W4
 */
export function AnchorPanel() {
  const queryClient = useQueryClient();
  const [pending, setPending] = useState<MapPoint | null>(null);
  const [label, setLabel] = useState('');
  const [mode, setMode] = useState<TravelMode>('car');
  const [error, setError] = useState<string | null>(null);

  const { data: anchors = [], isLoading, error: loadError } = useQuery({
    queryKey: ['anchors'],
    queryFn: () => api.get<Anchor[]>('/profile/anchors'),
    retry: false,
  });

  // K-C: profil ilk `PUT /profile` ile oluşur. Onboarding'in 3. adımında
  // kullanıcı henüz kaydetmediyse burası 404 döner — bu bir hata değil,
  // beklenen sıralama. Panel yerine yönlendirici bir not gösteriyoruz.
  const profileMissing =
    loadError instanceof ApiError && loadError.problem.code === 'PROFILE_NOT_FOUND';

  function invalidate() {
    void queryClient.invalidateQueries({ queryKey: ['anchors'] });
    // Profil de anchor listesi taşıyor; explore haritası ondan besleniyor.
    void queryClient.invalidateQueries({ queryKey: ['profile'] });
  }

  const createMutation = useMutation({
    mutationFn: (body: { label: string; lat: number; lon: number; mode: TravelMode }) =>
      api.post<Anchor>('/profile/anchors', body),
    onSuccess: () => {
      setPending(null);
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

  const weights = anchorWeights(anchors.length);
  const full = anchors.length >= MAX_ANCHORS;

  return (
    <div className="anchor-panel">
      <h2>Düzenli gittiğin yerler</h2>
      <p className="muted">
        En fazla {MAX_ANCHORS} yer ekleyebilirsin. Önem sırasına dizdiğinde
        skorlar bu sıraya göre yeniden hesaplanır — en önemli yer,
        diğerlerinin toplamı kadar ağırlık taşır.
      </p>

      {error && <p className="form-error" role="alert">{error}</p>}

      {profileMissing ? (
        <p className="notice">
          Yer eklemek için önce <strong>persona seçip kaydetmen</strong> gerekiyor.
          Kaydettikten sonra bu panel açılacak.
        </p>
      ) : (
      <>
      <div className="anchor-map">
        <CankayaMap
          height="320px"
          onMapClick={full ? undefined : (p) => { setPending(p); setError(null); }}
          markers={[
            ...anchors.map((a) => ({
              id: a.id,
              lat: a.lat,
              lon: a.lon,
              label: a.label,
              priority: a.priority,
            })),
            ...(pending ? [{ id: '__yeni', lat: pending.lat, lon: pending.lon, label: 'Yeni yer' }] : []),
          ]}
        />
      </div>

      <p className="muted map-hint">
        {full
          ? `${MAX_ANCHORS} yer eklendi. Yeni eklemek için önce birini sil.`
          : 'Haritaya tıklayarak yer seç.'}
      </p>

      {pending && (
        <form
          className="anchor-form"
          onSubmit={(e) => {
            e.preventDefault();
            if (!label.trim()) { setError('Bir etiket gir (ör. "Üniversite").'); return; }
            createMutation.mutate({ label: label.trim(), lat: pending.lat, lon: pending.lon, mode });
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

          <label className="field">
            <span>Nasıl gidiyorsun?</span>
            <select value={mode} onChange={(e) => setMode(e.target.value as TravelMode)}>
              <option value="car">Araçla</option>
              <option value="foot">Yürüyerek</option>
            </select>
          </label>

          <div className="row-actions">
            <button className="btn-primary" type="submit" disabled={createMutation.isPending}>
              {createMutation.isPending ? 'Ekleniyor…' : 'Ekle'}
            </button>
            <button className="btn-secondary" type="button" onClick={() => setPending(null)}>
              Vazgeç
            </button>
          </div>
        </form>
      )}

      {isLoading ? (
        <p className="muted">Yükleniyor…</p>
      ) : anchors.length === 0 ? (
        <p className="muted">Henüz yer eklemedin.</p>
      ) : (
        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
          <SortableContext items={anchors.map((a) => a.id)} strategy={verticalListSortingStrategy}>
            <ol className="anchor-list">
              {anchors.map((anchor, index) => (
                <SortableAnchor
                  key={anchor.id}
                  anchor={anchor}
                  weight={weights[index] ?? 0}
                  onDelete={() => deleteMutation.mutate(anchor.id)}
                />
              ))}
            </ol>
          </SortableContext>
        </DndContext>
      )}

      {reorderMutation.isPending && <p className="muted">Sıra kaydediliyor…</p>}
      </>
      )}
    </div>
  );
}

function SortableAnchor({
  anchor,
  weight,
  onDelete,
}: {
  anchor: Anchor;
  weight: number;
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
        <span className="muted">
          {anchor.mode === 'car' ? 'Araçla' : 'Yürüyerek'} · ağırlık {weight.toFixed(3)}
        </span>
      </span>

      <button className="btn-icon" type="button" onClick={onDelete} title="Sil">
        ✕
      </button>
    </li>
  );
}

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
