import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';

interface AdminUser {
  id: string;
  email: string;
  displayName: string | null;
  isAdmin: boolean;
  isActive: boolean;
  /** NULL ise kullanıcı e-postasını hiç doğrulamadı. */
  emailVerifiedAt: string | null;
  createdAt: string;
}

/** `GET /admin/users` — sayfalı yanıt. */
interface AdminUserPage {
  items: AdminUser[];
  page: number;
  pageSize: number;
  total: number;
}

const PAGE_SIZE = 25;

/**
 * Sunucudan gelen hatayı okunur bir cümleye çevirir.
 *
 * Eskiden her hata "bir hata oluştu" ile geçiştiriliyordu; sunucunun
 * gönderdiği gerçek sebep ("Kendi admin yetkinizi kaldıramazsınız")
 * kullanıcıya hiç ulaşmıyordu.
 */
function describeError(error: unknown, fallback: string): string {
  if (error instanceof ApiError) {
    return error.problem.detail ?? error.problem.title ?? fallback;
  }
  return fallback;
}

export function AdminPage() {
  const queryClient = useQueryClient();
  const currentUser = useAuthStore((s) => s.user);

  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [actionError, setActionError] = useState<string | null>(null);

  // Arama SUNUCUDA yapılıyor; her tuşta istek atmamak için 300 ms bekletiyoruz.
  useEffect(() => {
    const timer = setTimeout(() => {
      setSearch(searchInput.trim());
      setPage(1);
    }, 300);
    return () => clearTimeout(timer);
  }, [searchInput]);

  const { data, isLoading, isError } = useQuery({
    queryKey: ['admin-users', search, page],
    queryFn: () => {
      const params = new URLSearchParams({
        page: String(page),
        pageSize: String(PAGE_SIZE),
      });
      if (search) params.set('search', search);
      return api.get<AdminUserPage>(`/admin/users?${params.toString()}`);
    },
  });

  const users = useMemo(() => data?.items ?? [], [data]);
  const total = data?.total ?? 0;
  const pageCount = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const refresh = () =>
    queryClient.invalidateQueries({ queryKey: ['admin-users'] });

  const adminMutation = useMutation({
    mutationFn: ({ userId, isAdmin }: { userId: string; isAdmin: boolean }) =>
      api.patch(`/admin/users/${userId}/admin`, { isAdmin }),
    onMutate: () => setActionError(null),
    onSuccess: refresh,
    onError: (error) =>
      setActionError(describeError(error, 'Admin yetkisi değiştirilemedi.')),
  });

  const activeMutation = useMutation({
    mutationFn: ({ userId, isActive }: { userId: string; isActive: boolean }) =>
      api.patch(`/admin/users/${userId}/active`, { isActive }),
    onMutate: () => setActionError(null),
    onSuccess: refresh,
    onError: (error) =>
      setActionError(describeError(error, 'Hesap durumu değiştirilemedi.')),
  });

  const verifyMutation = useMutation({
    mutationFn: (userId: string) =>
      api.post(`/admin/users/${userId}/verify-email`),
    onMutate: () => setActionError(null),
    onSuccess: refresh,
    onError: (error) =>
      setActionError(describeError(error, 'E-posta doğrulanamadı.')),
  });

  const busy =
    adminMutation.isPending ||
    activeMutation.isPending ||
    verifyMutation.isPending;

  function handleVerify(user: AdminUser) {
    // Elle doğrulama, kimlik doğrulama adımını ATLIYOR — geri alınamaz ve
    // sorumluluğu admine ait. Onay istemek burada gereksiz sürtünme değil.
    const ok = window.confirm(
      `${user.email} adresini doğrulanmış sayacaksın.\n\n` +
        'Bu adım e-posta sahipliğini kanıtlamaz; yalnızca kodun ulaşmadığı ' +
        'durumlar için kullan. Devam edilsin mi?',
    );
    if (ok) verifyMutation.mutate(user.id);
  }

  return (
    <div className="admin-page">
      <header className="admin-head">
        <div>
          <h1>Admin paneli</h1>
          <p className="admin-sub">
            Kullanıcıları görüntüle, yetkileri ve hesap durumlarını yönet.
          </p>
        </div>
      </header>

      <div className="admin-toolbar">
        <input
          type="search"
          className="admin-search"
          value={searchInput}
          onChange={(event) => setSearchInput(event.target.value)}
          placeholder="Ad veya e-posta ara…"
        />
        <span className="admin-count">
          {isLoading ? 'Yükleniyor…' : `${total} kullanıcı`}
        </span>
      </div>

      <EmailStatusCard />

      {actionError && <div className="admin-error">{actionError}</div>}

      {isError ? (
        <div className="admin-error">Kullanıcı listesi alınamadı.</div>
      ) : (
        <>
          <div className="admin-table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Kullanıcı</th>
                  <th>E-posta</th>
                  <th>Doğrulama</th>
                  <th>Rol</th>
                  <th>Durum</th>
                  <th>Kayıt</th>
                  <th aria-label="İşlemler" />
                </tr>
              </thead>
              <tbody>
                {users.length === 0 && !isLoading && (
                  <tr>
                    <td colSpan={7} className="admin-empty">
                      {search
                        ? `"${search}" için kullanıcı bulunamadı.`
                        : 'Kullanıcı yok.'}
                    </td>
                  </tr>
                )}

                {users.map((user) => {
                  const isSelf = currentUser?.id === user.id;
                  const verified = user.emailVerifiedAt !== null;

                  return (
                    <tr key={user.id}>
                      <td>
                        <div className="admin-name">
                          {user.displayName || '—'}
                        </div>
                        {isSelf && <div className="admin-you">Bu sensin</div>}
                      </td>

                      <td className="admin-email">{user.email}</td>

                      <td>
                        {verified ? (
                          <span className="data-badge">Doğrulandı</span>
                        ) : (
                          // Bekleyen doğrulama VURGULANIYOR: kodun ulaşmadığı
                          // kullanıcıyı panelde ayırt edebilmek, elle
                          // doğrulama düğmesinin var olma sebebi.
                          <span className="admin-badge admin-badge--warn">
                            Bekliyor
                          </span>
                        )}
                      </td>

                      <td>
                        <span
                          className={
                            user.isAdmin
                              ? 'admin-badge admin-badge--admin'
                              : 'data-badge'
                          }
                        >
                          {user.isAdmin ? 'Admin' : 'Kullanıcı'}
                        </span>
                      </td>

                      <td>
                        <span
                          className={
                            user.isActive
                              ? 'data-badge'
                              : 'admin-badge admin-badge--off'
                          }
                        >
                          {user.isActive ? 'Aktif' : 'Pasif'}
                        </span>
                      </td>

                      <td className="admin-date">
                        {new Date(user.createdAt).toLocaleDateString('tr-TR')}
                      </td>

                      <td>
                        <div className="admin-actions">
                          {!verified && (
                            <button
                              type="button"
                              className="btn-sm btn-secondary"
                              disabled={busy}
                              onClick={() => handleVerify(user)}
                            >
                              Elle doğrula
                            </button>
                          )}

                          <button
                            type="button"
                            className="btn-sm btn-secondary"
                            // Kendi yetkisini alamaz: sistemde hiç admin
                            // kalmama riski. Sunucu da ayrıca engelliyor.
                            disabled={busy || isSelf}
                            onClick={() =>
                              adminMutation.mutate({
                                userId: user.id,
                                isAdmin: !user.isAdmin,
                              })
                            }
                          >
                            {user.isAdmin ? 'Yetkiyi al' : 'Admin yap'}
                          </button>

                          <button
                            type="button"
                            className="btn-sm btn-secondary"
                            disabled={busy || isSelf}
                            onClick={() =>
                              activeMutation.mutate({
                                userId: user.id,
                                isActive: !user.isActive,
                              })
                            }
                          >
                            {user.isActive ? 'Pasifleştir' : 'Aktifleştir'}
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {pageCount > 1 && (
            <div className="admin-pager">
              <button
                type="button"
                className="btn-sm btn-secondary"
                disabled={page <= 1 || isLoading}
                onClick={() => setPage((value) => Math.max(1, value - 1))}
              >
                ← Önceki
              </button>
              <span className="admin-count">
                {page} / {pageCount}
              </span>
              <button
                type="button"
                className="btn-sm btn-secondary"
                disabled={page >= pageCount || isLoading}
                onClick={() =>
                  setPage((value) => Math.min(pageCount, value + 1))
                }
              >
                Sonraki →
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}

/** `GET /admin/email-status` — parola İÇERMEZ. */
interface EmailStatus {
  provider: string;
  host: string;
  port: number;
  user: string;
  fromAddress: string;
  passwordConfigured: boolean;
  senderAligned: boolean;
  requireEmailVerification: boolean;
}

/**
 * E-posta gönderiminin yapılandırma durumu.
 *
 * Neden panelde: "kod gönderildi ama ulaşmadı" şikâyeti geldiğinde sebebi
 * sunucuya SSH ile bağlanmadan görebilmek için. Yanlış yapılandırmanın
 * belirtisi sessiz — API 202 döner, log "teslim edildi" yazar, kullanıcı
 * hiçbir şey almaz.
 *
 * Her şey yolundaysa yalnızca tek satırlık bir özet gösterip yoldan
 * çekiliyor; sorun varsa açıkça uyarıyor.
 */
function EmailStatusCard() {
  const { data, isLoading } = useQuery({
    queryKey: ['admin-email-status'],
    queryFn: () => api.get<EmailStatus>('/admin/email-status'),
  });

  if (isLoading || !data) return null;

  const problems: string[] = [];

  if (data.provider.toLowerCase() !== 'smtp') {
    problems.push(
      `Sağlayıcı "${data.provider}" — e-posta GÖNDERİLMİYOR, kod yalnızca ` +
        'sunucu loglarına yazılıyor. Gerçek gönderim için Email__Provider=smtp olmalı.',
    );
  } else if (!data.passwordConfigured) {
    problems.push(
      'SMTP parolası tanımlı değil. Kayıt sırasında gönderim hata verecek.',
    );
  } else if (!data.senderAligned) {
    problems.push(
      `Gönderen adresi (${data.fromAddress}) SMTP hesabından (${data.user}) farklı. ` +
        'Posta "gönderildi" görünse bile kurum/üniversite sunucuları SPF/DKIM ' +
        'uyuşmadığı için sessizce reddedebilir. İkisini aynı yapın.',
    );
  }

  if (!data.requireEmailVerification) {
    problems.push(
      'E-posta doğrulaması KAPALI — kayıtlar doğrulanmadan içeri giriyor.',
    );
  }

  if (problems.length === 0) {
    return (
      <p className="admin-count" style={{ marginBottom: '0.9rem' }}>
        E-posta: {data.provider} · {data.host}:{data.port} · gönderen{' '}
        {data.fromAddress}
      </p>
    );
  }

  return (
    <div className="admin-error" style={{ display: 'grid', gap: '0.4rem' }}>
      <strong>E-posta yapılandırmasında sorun var</strong>
      {problems.map((problem) => (
        <span key={problem}>{problem}</span>
      ))}
    </div>
  );
}
