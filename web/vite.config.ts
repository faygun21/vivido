import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Test yapılandırması burada DEĞİL, `vitest.config.ts` içinde.
// Sebep: Vitest 3, Vite 7 tiplerine bağımlı; proje Vite 8 kullanıyor.
// İkisi aynı dosyada birleşince eklenti tipleri çakışıyor.

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],

  optimizeDeps: {
    // MapLibre GeoJSON ayrıştırmayı ve karo çizimini bir Web Worker'da yapar.
    // Vite'ın bağımlılık ön-derleyicisi bu worker dosyasını bozuyor:
    //   "The file does not exist at .../deps/maplibre-gl-worker.mjs"
    // Sonuç sinsi — harita kabı, arka plan ve kontroller çalışır ama HİÇBİR
    // veri katmanı çizilmez, hata da vermez. Ön-derlemenin dışında tutuyoruz.
    exclude: ['maplibre-gl'],
  },

  resolve: {
    alias: {
      // `@/shared/api/client` gibi import'lar için — özellik klasörleri
      // iç içe olduğundan `../../../shared/...` zincirleri okunmaz hale gelir.
      // ⚠️ vitest.config.ts ve tsconfig.app.json'daki ile AYNI kalmalı.
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
})
