import '@testing-library/jest-dom/vitest';

/**
 * Vitest kurulum dosyası.
 *
 * MSW'nin Node tarafı (`setupServer`) buraya eklenecek — testlerde
 * tarayıcı worker'ı değil sunucu kesici kullanılır. Şu an handler
 * gerektiren bir test yok, sayfa testleri yazılırken eklenecek:
 *
 *   import { setupServer } from 'msw/node'
 *   import { handlers } from '@/mocks/handlers'
 *   const server = setupServer(...handlers)
 *   beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
 *   afterEach(() => server.resetHandlers())
 *   afterAll(() => server.close())
 */
