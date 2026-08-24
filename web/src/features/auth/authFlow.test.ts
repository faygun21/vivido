import { describe, expect, it, vi } from 'vitest';
import { ApiError, api } from '@/shared/api/client';
import { HOME_PATH, routeAfterAuth } from '@/features/auth/authFlow';

describe('routeAfterAuth', () => {
  it('profil varsa ana ekrana yönlendirir', async () => {
    vi.spyOn(api, 'get').mockResolvedValueOnce({});
    const navigate = vi.fn();

    await routeAfterAuth(navigate);

    expect(navigate).toHaveBeenCalledWith(HOME_PATH, { replace: true });
  });

  it('yalnızca profil bulunamadığında onboarding ekranına yönlendirir', async () => {
    vi.spyOn(api, 'get').mockRejectedValueOnce(
      new ApiError(404, {
        type: 'about:blank',
        title: 'Profil bulunamadı',
        status: 404,
        code: 'PROFILE_NOT_FOUND',
      }),
    );
    const navigate = vi.fn();

    await routeAfterAuth(navigate);

    expect(navigate).toHaveBeenCalledWith('/onboarding', { replace: true });
  });

  it('sunucu hatasını gizlemez', async () => {
    const serverError = new ApiError(500, {
      type: 'about:blank',
      title: 'Sunucu tarafında bir hata oluştu',
      status: 500,
    });
    vi.spyOn(api, 'get').mockRejectedValueOnce(serverError);
    const navigate = vi.fn();

    await expect(routeAfterAuth(navigate)).rejects.toBe(serverError);
    expect(navigate).not.toHaveBeenCalled();
  });
});
