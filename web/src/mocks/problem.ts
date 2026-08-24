import { HttpResponse } from 'msw';
import type { ErrorCode, ProblemDetails } from '@vivido/shared';

/**
 * Sahte hata cevabı üretir — gerçek backend ile AYNI biçimde.
 *
 * Arayüz `problem+json` bekliyorsa mock da onu döndürmeli; yoksa
 * gerçek API'ye geçildiğinde hata yolları ilk kez orada denenmiş olur.
 */
export function problem(
  status: number,
  title: string,
  code?: ErrorCode,
  detail?: string,
) {
  const body: ProblemDetails = {
    type: code
      ? `https://vivido.dev/errors/${code.toLowerCase().replaceAll('_', '-')}`
      : 'about:blank',
    title,
    status,
    ...(detail ? { detail } : {}),
    ...(code ? { code } : {}),
  };
  return HttpResponse.json(body, {
    status,
    headers: { 'Content-Type': 'application/problem+json' },
  });
}

/** Doğrulama hatası — ASP.NET Core'un ValidationProblemDetails yapısı. */
export function validationProblem(errors: Record<string, string[]>) {
  const body: ProblemDetails = {
    type: 'https://vivido.dev/errors/validation',
    title: 'Doğrulama hatası',
    status: 400,
    errors,
  };
  return HttpResponse.json(body, {
    status: 400,
    headers: { 'Content-Type': 'application/problem+json' },
  });
}
