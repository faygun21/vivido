import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';

interface AdminUser {
  id: string;
  email: string;
  displayName: string | null;
  isAdmin: boolean;
  isActive: boolean;
  createdAt: string;
}

export function AdminPage() {
  const queryClient = useQueryClient();
  const currentUser = useAuthStore((s) => s.user);

  const [search, setSearch] = useState('');
  const [actionError, setActionError] = useState<string | null>(null);

  const {
    data: users = [],
    isLoading,
    isError,
  } = useQuery({
    queryKey: ['admin-users'],
    queryFn: () => api.get<AdminUser[]>('/admin/users'),
  });

  const filteredUsers = useMemo(() => {
    const value = search.trim().toLocaleLowerCase('tr-TR');

    if (!value) return users;

    return users.filter((user) => {
      const name = user.displayName?.toLocaleLowerCase('tr-TR') ?? '';
      const email = user.email.toLocaleLowerCase('tr-TR');

      return name.includes(value) || email.includes(value);
    });
  }, [users, search]);

  const stats = useMemo(
    () => ({
      total: users.length,
      admins: users.filter((u) => u.isAdmin).length,
      active: users.filter((u) => u.isActive).length,
      passive: users.filter((u) => !u.isActive).length,
    }),
    [users],
  );

  const adminMutation = useMutation({
    mutationFn: ({
      userId,
      isAdmin,
    }: {
      userId: string;
      isAdmin: boolean;
    }) =>
      api.patch(`/admin/users/${userId}/admin`, {
        isAdmin,
      }),

    onMutate: () => {
      setActionError(null);
    },

    onSuccess: async () => {
      await queryClient.invalidateQueries({
        queryKey: ['admin-users'],
      });
    },

    onError: () => {
      setActionError('Admin yetkisi değiştirilirken bir hata oluştu.');
    },
  });

  const activeMutation = useMutation({
    mutationFn: ({
      userId,
      isActive,
    }: {
      userId: string;
      isActive: boolean;
    }) =>
      api.patch(`/admin/users/${userId}/active`, {
        isActive,
      }),

    onMutate: () => {
      setActionError(null);
    },

    onSuccess: async () => {
      await queryClient.invalidateQueries({
        queryKey: ['admin-users'],
      });
    },

    onError: () => {
      setActionError('Kullanıcı durumu değiştirilirken bir hata oluştu.');
    },
  });

  const anyMutationPending =
    adminMutation.isPending || activeMutation.isPending;

  if (isLoading) {
    return (
      <div className="admin-page" style={pageStyle}>
        <p>Kullanıcılar yükleniyor...</p>
      </div>
    );
  }

  if (isError) {
    return (
      <div className="admin-page" style={pageStyle}>
        <h1>Admin Paneli</h1>
        <p style={errorStyle}>
          Kullanıcı listesi alınırken bir hata oluştu.
        </p>
      </div>
    );
  }

  return (
    <div className="admin-page" style={pageStyle}>
      <div style={titleAreaStyle}>
        <div>
          <h1 style={{ margin: 0 }}>Admin Paneli</h1>
          <p style={{ marginTop: '10px', marginBottom: 0 }}>
            Sistemdeki kullanıcıları görüntüleyebilir ve yetkilerini yönetebilirsin.
          </p>
        </div>
      </div>

      <div className="admin-stats-grid" style={statsGridStyle}>
        <StatCard label="Toplam Kullanıcı" value={stats.total} />
        <StatCard label="Admin" value={stats.admins} />
        <StatCard label="Aktif" value={stats.active} />
        <StatCard label="Pasif" value={stats.passive} />
      </div>

      <div style={toolbarStyle}>
        <input
          type="search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Ad veya e-posta ara..."
          style={searchInputStyle}
        />

        <span style={resultCountStyle}>
          {filteredUsers.length} kullanıcı gösteriliyor
        </span>
      </div>

      {actionError && (
        <div style={errorBoxStyle}>
          {actionError}
        </div>
      )}

      <div style={tableWrapperStyle}>
        <table style={tableStyle}>
          <thead>
            <tr>
              <th style={headerStyle}>Ad</th>
              <th style={headerStyle}>E-posta</th>
              <th style={headerStyle}>Admin</th>
              <th style={headerStyle}>Durum</th>
              <th style={headerStyle}>Kayıt Tarihi</th>
              <th style={headerStyle}>İşlemler</th>
            </tr>
          </thead>

          <tbody>
            {filteredUsers.map((user) => {
              const isCurrentUser = currentUser?.id === user.id;

              return (
                <tr key={user.id}>
                  <td style={cellStyle}>
                    <div style={{ fontWeight: 600 }}>
                      {user.displayName || '-'}
                    </div>

                    {isCurrentUser && (
                      <div style={youTextStyle}>
                        Bu sensin
                      </div>
                    )}
                  </td>

                  <td style={cellStyle}>
                    {user.email}
                  </td>

                  <td style={cellStyle}>
                    <StatusBadge
                      text={user.isAdmin ? 'Admin' : 'Kullanıcı'}
                    />
                  </td>

                  <td style={cellStyle}>
                    <StatusBadge
                      text={user.isActive ? 'Aktif' : 'Pasif'}
                    />
                  </td>

                  <td style={cellStyle}>
                    {new Date(user.createdAt).toLocaleDateString('tr-TR')}
                  </td>

                  <td style={cellStyle}>
                    <div style={actionsStyle}>
                      <button
                        type="button"
                        disabled={anyMutationPending || isCurrentUser}
                        onClick={() =>
                          adminMutation.mutate({
                            userId: user.id,
                            isAdmin: !user.isAdmin,
                          })
                        }
                        style={{
                          ...buttonStyle,
                          ...(anyMutationPending || isCurrentUser
                            ? disabledButtonStyle
                            : {}),
                        }}
                        title={
                          isCurrentUser
                            ? 'Kendi admin yetkinizi değiştiremezsiniz.'
                            : undefined
                        }
                      >
                        {adminMutation.isPending
                          ? 'İşleniyor...'
                          : user.isAdmin
                            ? 'Adminliği Kaldır'
                            : 'Admin Yap'}
                      </button>

                      <button
                        type="button"
                        disabled={anyMutationPending || isCurrentUser}
                        onClick={() =>
                          activeMutation.mutate({
                            userId: user.id,
                            isActive: !user.isActive,
                          })
                        }
                        style={{
                          ...buttonStyle,
                          ...(anyMutationPending || isCurrentUser
                            ? disabledButtonStyle
                            : {}),
                        }}
                        title={
                          isCurrentUser
                            ? 'Kendi hesabınızı pasif yapamazsınız.'
                            : undefined
                        }
                      >
                        {activeMutation.isPending
                          ? 'İşleniyor...'
                          : user.isActive
                            ? 'Pasif Yap'
                            : 'Aktif Yap'}
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}

            {filteredUsers.length === 0 && (
              <tr>
                <td colSpan={6} style={emptyStyle}>
                  Aramana uygun kullanıcı bulunamadı.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function StatCard({
  label,
  value,
}: {
  label: string;
  value: number;
}) {
  return (
    <div style={statCardStyle}>
      <span style={statLabelStyle}>{label}</span>
      <strong style={statValueStyle}>{value}</strong>
    </div>
  );
}

function StatusBadge({
  text,
}: {
  text: string;
}) {
  return (
    <span style={badgeStyle}>
      {text}
    </span>
  );
}

// Yatay dolgu ve `.admin-stats-grid`in sütun sayısı `.admin-page` CSS
// sınıfında responsive — bkz. index.css (2026-08-28: 48px dolgu + 4 sabit
// sütun 375px'lik telefonda istatistik kartlarını eziyordu).
const pageStyle = {};

const titleAreaStyle = {
  marginBottom: '28px',
};

const statsGridStyle = {
  marginBottom: '24px',
};

const statCardStyle = {
  padding: '18px',
  border: '1px solid #ded8d1',
  borderRadius: '12px',
  background: '#fff',
};

const statLabelStyle = {
  display: 'block',
  fontSize: '13px',
  color: '#746d66',
  marginBottom: '6px',
};

const statValueStyle = {
  fontSize: '28px',
};

const toolbarStyle = {
  display: 'flex',
  justifyContent: 'space-between',
  alignItems: 'center',
  gap: '16px',
  marginBottom: '18px',
  flexWrap: 'wrap' as const,
};

const searchInputStyle = {
  minWidth: '280px',
  maxWidth: '420px',
  width: '100%',
  padding: '11px 14px',
  border: '1px solid #cfc8c1',
  borderRadius: '10px',
  background: '#fff',
  fontSize: '14px',
};

const resultCountStyle = {
  color: '#746d66',
  fontSize: '14px',
};

const tableWrapperStyle = {
  overflowX: 'auto' as const,
  border: '1px solid #e2ddd8',
  borderRadius: '12px',
  background: '#fff',
};

const tableStyle = {
  width: '100%',
  borderCollapse: 'collapse' as const,
};

const headerStyle = {
  textAlign: 'left' as const,
  padding: '14px',
  borderBottom: '1px solid #ddd',
  background: '#faf8f5',
};

const cellStyle = {
  padding: '14px',
  borderBottom: '1px solid #eee',
  verticalAlign: 'middle' as const,
};

const actionsStyle = {
  display: 'flex',
  gap: '8px',
  flexWrap: 'wrap' as const,
};

const buttonStyle = {
  padding: '8px 12px',
  borderRadius: '8px',
  border: '1px solid #bbb',
  background: '#fff',
  cursor: 'pointer',
};

const disabledButtonStyle = {
  cursor: 'not-allowed',
  opacity: 0.45,
};

const badgeStyle = {
  display: 'inline-block',
  padding: '5px 9px',
  borderRadius: '999px',
  border: '1px solid #d6d0ca',
  background: '#f7f4f1',
  fontSize: '13px',
};

const youTextStyle = {
  marginTop: '4px',
  color: '#8a8178',
  fontSize: '12px',
};

const errorStyle = {
  color: 'crimson',
};

const errorBoxStyle = {
  marginBottom: '16px',
  padding: '12px 14px',
  border: '1px solid #e8b6b6',
  borderRadius: '10px',
  background: '#fff2f2',
  color: '#9b1c1c',
};

const emptyStyle = {
  padding: '28px',
  textAlign: 'center' as const,
  color: '#746d66',
};