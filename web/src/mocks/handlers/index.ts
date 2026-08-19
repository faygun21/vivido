import { authHandlers } from '@/mocks/handlers/auth';
import { personaHandlers } from '@/mocks/handlers/persona';
import { profileHandlers } from '@/mocks/handlers/profile';

/**
 * Tüm MSW handler'ları.
 *
 * Her özellik kendi dosyasında — dört kişi aynı anda çalışıyor,
 * tek dosyada toplanırsa her PR'da çakışır.
 *
 * Backend bir endpoint grubunu yayınlayınca ilgili dosya silinir
 * ve buradaki satırı kaldırılır.
 */
export const handlers = [
  ...authHandlers,
  ...personaHandlers,
  ...profileHandlers,
];
