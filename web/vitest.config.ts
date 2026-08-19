import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vitest/config'

/**
 * Test yapılandırması.
 *
 * NEDEN AYRI DOSYA: Vitest 3, Vite 7 tiplerine bağımlı; proje Vite 8
 * kullanıyor. `test` bloğunu vite.config.ts içine koyup `defineConfig`i
 * `vitest/config`den alırsak `@vitejs/plugin-react` (Vite 8) ile tip
 * çakışması çıkıyor. Ayrı dosyada eklenti yok, çakışma da yok.
 *
 * Vitest bu dosyayı bulduğunda vite.config.ts'i YOK SAYAR — bu yüzden
 * alias burada da tanımlı olmak zorunda.
 *
 * React bileşen testleri için `@vitejs/plugin-react` gerekmiyor:
 * JSX dönüşümünü Vitest'in esbuild'i tsconfig'deki `"jsx": "react-jsx"`
 * ayarıyla zaten yapıyor. Eklenti yalnızca Fast Refresh için lazım, o da
 * geliştirme sunucusuna ait.
 */
export default defineConfig({
  resolve: {
    alias: {
      // ⚠️ vite.config.ts ve tsconfig.app.json'daki ile AYNI kalmalı.
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
  },
})
