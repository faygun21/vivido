/**
 * Persona sözleşmesi.
 *
 * ⚠️ 4 persona var, 6 değil.
 * Üç haftalık plan `pet_owner` ve `car_free` personalarını kapsamdan
 * çıkardı (gerekçe: docs/02-KARARLAR.md → K-04):
 *
 *   · pet_owner  — dayandığı `pet` POI kategorisi de kesildi
 *   · car_free   — `transit` ağırlığı `student` ile büyük ölçüde örtüşüyor
 *
 * Bu liste `db/schema/002_seed_reference.sql` ile BİREBİR aynı olmalı.
 * Veritabanında 4 satır var; buraya 5. eklemek çalışma anında
 * foreign key hatası verir.
 */

export const PERSONA_CODES = [
  'student',
  'family_kids',
  'remote_worker',
  'elderly',
] as const;

export type PersonaCode = (typeof PERSONA_CODES)[number];

export interface Persona {
  code: PersonaCode;
  displayNameTr: string;
  descriptionTr: string;
  icon?: string;
}
