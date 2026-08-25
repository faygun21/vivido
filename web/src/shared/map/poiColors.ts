/**
 * POI kategorisi → harita rengi. Hem katman çizimi (CankayaMap) hem de
 * katman paneli (PoiLayerPanel) buradan beslenir — iki yerde ayrı tanımlamak
 * renklerin sessizce ayrışmasına yol açar.
 */
export const POI_CATEGORY_COLORS: Record<string, string> = {
  market: '#e11d48',
  pharmacy: '#16a34a',
  health: '#0ea5e9',
  school: '#f59e0b',
  transit: '#6366f1',
  food: '#f97316',
  park: '#22c55e',
  gym: '#8b5cf6',
};

/** Bilinmeyen kategori için yedek renk. */
export const POI_FALLBACK_COLOR = '#64748b';

export function poiCategoryColor(code: string): string {
  return POI_CATEGORY_COLORS[code] ?? POI_FALLBACK_COLOR;
}
