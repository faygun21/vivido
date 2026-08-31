import { useMutation, useQueryClient } from '@tanstack/react-query';
import type { PropertyNoteResponse, UpsertPropertyNoteRequest } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useSessionKey, useSessionQuery } from '@/shared/api/sessionQuery';

export function usePropertyNote(propertyId: string) {
  const numericPropertyId = Number(propertyId);
  const sessionKey = useSessionKey();
  const queryClient = useQueryClient();
  const queryKey = ['property-note', numericPropertyId, sessionKey] as const;

  const query = useSessionQuery<PropertyNoteResponse>({
    queryKey: ['property-note', numericPropertyId],
    queryFn: () => api.get<PropertyNoteResponse>(`/properties/${numericPropertyId}/note`),
    enabled: Number.isSafeInteger(numericPropertyId) && numericPropertyId > 0,
  });

  const save = useMutation({
    mutationFn: (request: UpsertPropertyNoteRequest) =>
      api.put<PropertyNoteResponse>(`/properties/${numericPropertyId}/note`, request),
    onSuccess: (saved) => {
      queryClient.setQueryData(queryKey, saved);
    },
  });

  const remove = useMutation({
    mutationFn: () => api.delete(`/properties/${numericPropertyId}/note`),
    onSuccess: () => {
      queryClient.setQueryData<PropertyNoteResponse>(queryKey, {
        propertyId: numericPropertyId,
        note: null,
        createdAt: null,
        updatedAt: null,
      });
    },
  });

  return {
    note: query.data?.note ?? null,
    isLoading: query.isLoading,
    loadError: query.isError,
    retryLoad: query.refetch,
    saveNote: save.mutate,
    isSaving: save.isPending,
    saveError: save.isError,
    deleteNote: remove.mutate,
    isDeleting: remove.isPending,
    deleteError: remove.isError,
  };
}
