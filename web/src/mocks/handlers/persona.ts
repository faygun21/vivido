import { http, HttpResponse } from 'msw';
import type { Persona } from '@vivido/shared';
import { API_BASE_URL } from '@/shared/config';
import { userIdFromAuthHeader } from '@/mocks/db';
import { problem } from '@/mocks/problem';

const PERSONAS: Persona[] = [
  {
    code: 'student',
    displayNameTr: 'Öğrenci',
    descriptionTr:
      'Toplu taşıma ve sosyal hayat öncelikli; okula/kampüse erişim belirleyici.',
    icon: 'graduation-cap',
    categoryWeights: [
      { categoryCode: 'transit', weight: 0.259 },
      { categoryCode: 'food', weight: 0.235 },
      { categoryCode: 'market', weight: 0.165 },
      { categoryCode: 'park', weight: 0.118 },
      { categoryCode: 'gym', weight: 0.094 },
      { categoryCode: 'pharmacy', weight: 0.059 },
      { categoryCode: 'health', weight: 0.041 },
      { categoryCode: 'school', weight: 0.029 },
    ],
  },
  {
    code: 'family_kids',
    displayNameTr: 'Çocuklu aile',
    descriptionTr:
      'Okul, market ve park yakınlığı öncelikli; sakin çevre tercih edilir.',
    icon: 'users',
    categoryWeights: [
      { categoryCode: 'school', weight: 0.258 },
      { categoryCode: 'market', weight: 0.186 },
      { categoryCode: 'park', weight: 0.144 },
      { categoryCode: 'health', weight: 0.124 },
      { categoryCode: 'pharmacy', weight: 0.103 },
      { categoryCode: 'transit', weight: 0.082 },
      { categoryCode: 'food', weight: 0.062 },
      { categoryCode: 'gym', weight: 0.041 },
    ],
  },
  {
    code: 'remote_worker',
    displayNameTr: 'Uzaktan çalışan',
    descriptionTr:
      'Evden çalışır; kafe, park ve spor salonu günlük hayatın merkezinde.',
    icon: 'laptop',
    categoryWeights: [
      { categoryCode: 'food', weight: 0.247 },
      { categoryCode: 'market', weight: 0.202 },
      { categoryCode: 'park', weight: 0.180 },
      { categoryCode: 'gym', weight: 0.135 },
      { categoryCode: 'transit', weight: 0.090 },
      { categoryCode: 'pharmacy', weight: 0.067 },
      { categoryCode: 'health', weight: 0.045 },
      { categoryCode: 'school', weight: 0.034 },
    ],
  },
  {
    code: 'elderly',
    displayNameTr: 'Yaşlı / emekli',
    descriptionTr:
      'Eczane, market ve sağlık kuruluşuna yürüme mesafesi belirleyici.',
    icon: 'heart',
    categoryWeights: [
      { categoryCode: 'market', weight: 0.232 },
      { categoryCode: 'pharmacy', weight: 0.232 },
      { categoryCode: 'health', weight: 0.189 },
      { categoryCode: 'park', weight: 0.137 },
      { categoryCode: 'transit', weight: 0.095 },
      { categoryCode: 'food', weight: 0.053 },
      { categoryCode: 'gym', weight: 0.032 },
      { categoryCode: 'school', weight: 0.030 },
    ],
  },
];

export const personaHandlers = [
  http.get(`${API_BASE_URL}/personas`, ({ request }) => {
    if (!userIdFromAuthHeader(request)) {
      return problem(401, 'Oturum gerekli', 'TOKEN_EXPIRED');
    }

    return HttpResponse.json(PERSONAS);
  }),
];