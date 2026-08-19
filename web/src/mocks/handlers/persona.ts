import { http, HttpResponse } from 'msw';
import type { Persona } from '@vivido/shared';
import { API_BASE_URL } from '@/shared/config';
import { userIdFromAuthHeader } from '@/mocks/db';
import { problem } from '@/mocks/problem';

/**
 * Persona handler'ı — SAHİBİ: Kişi 2
 *
 * Metinler `db/schema/002_seed_reference.sql` ile BİREBİR aynı.
 * Değiştirmeyin — gerçek API'ye geçildiğinde ekran değişirse
 * tasarım kararları yanlış veriyle alınmış olur.
 */

const PERSONAS: Persona[] = [
  {
    code: 'student',
    displayNameTr: 'Öğrenci',
    descriptionTr:
      'Toplu taşıma ve sosyal hayat öncelikli; okula/kampüse erişim belirleyici.',
    icon: 'graduation-cap',
  },
  {
    code: 'family_kids',
    displayNameTr: 'Çocuklu aile',
    descriptionTr:
      'Okul, market ve park yakınlığı öncelikli; sakin çevre tercih edilir.',
    icon: 'users',
  },
  {
    code: 'remote_worker',
    displayNameTr: 'Uzaktan çalışan',
    descriptionTr:
      'Evden çalışır; kafe, park ve spor salonu günlük hayatın merkezinde.',
    icon: 'laptop',
  },
  {
    code: 'elderly',
    displayNameTr: 'Yaşlı / emekli',
    descriptionTr:
      'Eczane, market ve sağlık kuruluşuna yürüme mesafesi belirleyici.',
    icon: 'heart',
  },
];

export const personaHandlers = [
  // Korumalı (K-F): onboarding kayıttan SONRA geliyor, token her zaman var.
  http.get(`${API_BASE_URL}/personas`, ({ request }) => {
    if (!userIdFromAuthHeader(request)) {
      return problem(401, 'Oturum gerekli', 'TOKEN_EXPIRED');
    }
    return HttpResponse.json(PERSONAS);
  }),
];
