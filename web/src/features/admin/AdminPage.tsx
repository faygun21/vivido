import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  Eye,
  EyeOff,
  MailCheck,
  ShieldCheck,
  ShieldOff,
  UserCheck,
  UserX,
} from 'lucide-react';
import { api, ApiError } from '@/shared/api/client';
import { useAuthStore } from '@/features/auth/authStore';
import { AdminIconAction } from './AdminIconAction';

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
 * Satır eylemlerinin ikon ölçüsü.
 *
 * `lucide-react` öntanımlı olarak 24px ve `strokeWidth: 2` çizer; 17px'e
 * küçültülen bir ikonda o kalınlık tıkanır, ince çizgili bir tabloda da
 * gereğinden fazla ağırlık taşır.
 */
const ICON = { size: 17, strokeWidth: 1.75 } as const;

/** Bir istek uçarken diğer eylemler kapalı — sebebi ipucunda yazsın. */
const BUSY_REASON = 'Önceki işlem sürüyor…';

/**
 * Sunucudan gelen hatayı okunur bir cümleye çevirir.
 *
 * Eskiden her hata "bir hata oluştu" ile geçiştiriliyordu; sunucunun
 * gönderdiği gerçek sebep ("Kendi admin yetkinizi kaldıramazsınız")
 * kullanıcıya hiç ulaşmıyordu.
 */
function describeError(error: unknown, fallback: string): string {
  // `code` VARSA gövde bizim `ApiProblem` yardımcımızdan geldi demektir —
  // `detail`/`title` kasıtlı ve Türkçe (yukarıdaki "Kendi admin yetkinizi
  // kaldıramazsınız" örneği gibi). YOKSA (ASP.NET Core'un otomatik
  // ürettiği beklenmeyen bir hata) `title` çerçevenin İngilizce
  // varsayılanı olabilir ("Not Found" gibi) — çağıranın verdiği `fallback`
  // kullanılır.
  if (error instanceof ApiError && error.problem.code) {
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
  const [detailUserId, setDetailUserId] = useState<string | null>(null);

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

      <div className="admin-insights">
        <SystemHealthPanel />
        <MetricsPanel />
      </div>

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
                          <AdminIconAction
                            label={
                              detailUserId === user.id
                                ? 'Detayı gizle'
                                : 'Detay'
                            }
                            icon={
                              detailUserId === user.id ? (
                                <EyeOff {...ICON} />
                              ) : (
                                <Eye {...ICON} />
                              )
                            }
                            active={detailUserId === user.id}
                            onClick={() =>
                              setDetailUserId((current) =>
                                current === user.id ? null : user.id,
                              )
                            }
                          />

                          {!verified && (
                            <AdminIconAction
                              label="Elle doğrula"
                              icon={<MailCheck {...ICON} />}
                              intent="ok"
                              disabledReason={busy ? BUSY_REASON : null}
                              onClick={() => handleVerify(user)}
                            />
                          )}

                          <AdminIconAction
                            label={user.isAdmin ? 'Yetkiyi al' : 'Admin yap'}
                            icon={
                              user.isAdmin ? (
                                <ShieldOff {...ICON} />
                              ) : (
                                <ShieldCheck {...ICON} />
                              )
                            }
                            intent="accent"
                            // Kendi yetkisini alamaz: sistemde hiç admin
                            // kalmama riski. Sunucu da ayrıca engelliyor.
                            disabledReason={
                              isSelf
                                ? 'Kendi yönetici yetkini değiştiremezsin.'
                                : busy
                                  ? BUSY_REASON
                                  : null
                            }
                            onClick={() =>
                              adminMutation.mutate({
                                userId: user.id,
                                isAdmin: !user.isAdmin,
                              })
                            }
                          />

                          <AdminIconAction
                            label={
                              user.isActive ? 'Pasifleştir' : 'Aktifleştir'
                            }
                            icon={
                              user.isActive ? (
                                <UserX {...ICON} />
                              ) : (
                                <UserCheck {...ICON} />
                              )
                            }
                            intent={user.isActive ? 'danger' : 'ok'}
                            disabledReason={
                              isSelf
                                ? 'Kendi hesabının durumunu değiştiremezsin.'
                                : busy
                                  ? BUSY_REASON
                                  : null
                            }
                            onClick={() =>
                              activeMutation.mutate({
                                userId: user.id,
                                isActive: !user.isActive,
                              })
                            }
                          />
                        </div>
                      </td>
                    </tr>
                  );
                })}

                {/* Detay, seçili kullanıcının ALTINDA açılıyor — ayrı bir
                    sayfaya gitmek listedeki yeri kaybettirirdi. */}
                {detailUserId !== null &&
                  users.some((u) => u.id === detailUserId) && (
                    <tr>
                      <td colSpan={7} className="admin-detail-cell">
                        <UserDetailPanel
                          userId={detailUserId}
                          onClose={() => setDetailUserId(null)}
                        />
                      </td>
                    </tr>
                  )}
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

// ═══════════════════════════════════════════════════════════════════
//  SİSTEM SAĞLIĞI VE METRİKLER
// ═══════════════════════════════════════════════════════════════════

interface ServiceProbe {
  healthy: boolean;
  elapsedMs: number;
  error: string | null;
}

interface SystemHealth {
  osrmCar: ServiceProbe;
  osrmFoot: ServiceProbe;
  database: ServiceProbe;
  data: {
    properties: number;
    pois: number;
    neighborhoods: number;
    accessRows: number;
    dataVersions: { dataVersion: string; count: number }[];
  };
}

interface Metrics {
  users: {
    users: number;
    verified: number;
    admins: number;
    profiles: number;
    anchors: number;
    favorites: number;
    routes: number;
    personas: { personaCode: string; count: number }[];
  };
  scores: {
    excellent: number;
    good: number;
    fair: number;
    poor: number;
    total: number;
    median: number | null;
    atCeiling: number;
    atFloor: number;
  };
}

const nf = new Intl.NumberFormat('tr-TR');

function ProbeRow({ label, probe }: { label: string; probe: ServiceProbe }) {
  return (
    <div className="admin-probe">
      <span
        className={
          probe.healthy ? 'admin-dot admin-dot--ok' : 'admin-dot admin-dot--down'
        }
        aria-hidden
      />
      <span className="admin-probe-label">{label}</span>
      <span className="admin-probe-value">
        {probe.healthy ? `${probe.elapsedMs} ms` : (probe.error ?? 'ulaşılamıyor')}
      </span>
    </div>
  );
}

/**
 * Bağımlı servislerin durumu ve veri kümesi sayıları.
 *
 * Neden var: OSRM bu projede iki gün çöküktü ve kimse fark etmedi — site
 * sağlıklı görünürken yalnızca rota oluşturma 503 dönüyordu. Arıza sessiz
 * olduğu için ancak kullanıcı şikâyet edince ortaya çıktı.
 */
function SystemHealthPanel() {
  const { data, isLoading } = useQuery({
    queryKey: ['admin-system-health'],
    queryFn: () => api.get<SystemHealth>('/admin/system-health'),
    // Sağlık bilgisi bayatlamamalı; panel açık dururken de tazelensin.
    refetchInterval: 30_000,
  });

  if (isLoading || !data) return null;

  const mixedVersions = data.data.dataVersions.length > 1;

  return (
    <section className="admin-card">
      <h2 className="admin-card-title">Sistem</h2>

      <div className="admin-probes">
        <ProbeRow label="OSRM · araç" probe={data.osrmCar} />
        <ProbeRow label="OSRM · yürüme" probe={data.osrmFoot} />
        <ProbeRow label="Veritabanı" probe={data.database} />
      </div>

      <h2 className="admin-card-title">Veri</h2>
      <div className="admin-figures">
        <Figure label="Konut" value={data.data.properties} />
        <Figure label="POI" value={data.data.pois} />
        <Figure label="Mahalle" value={data.data.neighborhoods} />
        <Figure label="Erişim satırı" value={data.data.accessRows} />
      </div>

      <p className="admin-count" style={{ marginTop: '0.6rem' }}>
        Veri sürümü:{' '}
        {data.data.dataVersions.map((v) => v.dataVersion).join(', ') || '—'}
      </p>

      {/* Birden fazla sürüm bir arada = ETL yarım kalmış. */}
      {mixedVersions && (
        <div className="admin-error" style={{ marginTop: '0.6rem' }}>
          Veri kümesinde birden fazla sürüm var. ETL yarım kalmış olabilir;
          skorlar tutarsız olabilir.
        </div>
      )}
    </section>
  );
}

function Figure({ label, value }: { label: string; value: number }) {
  return (
    <div className="admin-figure">
      <div className="admin-figure-value">{nf.format(value)}</div>
      <div className="admin-figure-label">{label}</div>
    </div>
  );
}

/**
 * Kullanım ve skor dağılımı.
 *
 * Skor histogramı motor kalibrasyonunun etkisini gösteriyor: bu projede bir
 * güncelleme medyanı 93.8'den 75.1'e indirdi ve ölçmek için elle SQL yazmak
 * gerekmişti.
 */
function MetricsPanel() {
  const { data, isLoading } = useQuery({
    queryKey: ['admin-metrics'],
    queryFn: () => api.get<Metrics>('/admin/metrics'),
  });

  if (isLoading || !data) return null;

  const s = data.scores;
  const bands = [
    { label: 'Çok iyi', value: s.excellent, cls: 'band-chip--excellent' },
    { label: 'İyi', value: s.good, cls: 'band-chip--good' },
    { label: 'Orta', value: s.fair, cls: 'band-chip--fair' },
    { label: 'Zayıf', value: s.poor, cls: 'band-chip--poor' },
  ];
  const max = Math.max(1, ...bands.map((b) => b.value));

  return (
    <section className="admin-card">
      <h2 className="admin-card-title">Kullanım</h2>
      <div className="admin-figures">
        <Figure label="Kullanıcı" value={data.users.users} />
        <Figure label="Doğrulanmış" value={data.users.verified} />
        <Figure label="Profil" value={data.users.profiles} />
        <Figure label="Rota" value={data.users.routes} />
        <Figure label="Favori" value={data.users.favorites} />
        <Figure label="Önemli konum" value={data.users.anchors} />
      </div>

      {data.users.personas.length > 0 && (
        <p className="admin-count" style={{ marginTop: '0.5rem' }}>
          Persona:{' '}
          {data.users.personas
            .map((p) => `${p.personaCode} (${p.count})`)
            .join(' · ')}
        </p>
      )}

      <h2 className="admin-card-title">
        Skor dağılımı
        {s.median !== null && (
          <span className="admin-count"> · medyan {s.median}</span>
        )}
      </h2>

      {s.total === 0 ? (
        <p className="admin-count">
          Skor önbelleği boş — henüz skorlama tetiklenmemiş.
        </p>
      ) : (
        <>
          <div className="admin-bars">
            {bands.map((band) => (
              <div key={band.label} className="admin-bar-row">
                <span className="admin-bar-label">{band.label}</span>
                <div className="admin-bar-track">
                  <div
                    className={`admin-bar-fill ${band.cls}`}
                    style={{ width: `${(band.value / max) * 100}%` }}
                  />
                </div>
                <span className="admin-bar-value">{nf.format(band.value)}</span>
              </div>
            ))}
          </div>

          {/* Uç değerler kalibrasyon sorununun en hızlı göstergesi. */}
          {(s.atCeiling > 0 || s.atFloor > 0) && (
            <p className="admin-count" style={{ marginTop: '0.5rem' }}>
              Tam 100 alan: {nf.format(s.atCeiling)} · 0 alan:{' '}
              {nf.format(s.atFloor)}
            </p>
          )}
        </>
      )}
    </section>
  );
}

// ═══════════════════════════════════════════════════════════════════
//  KULLANICI DETAYI
// ═══════════════════════════════════════════════════════════════════

interface AdminAnchor {
  label: string;
  mode: string;
  priority: number;
}

interface AdminProfile {
  personaCode: string | null;
  minMonthlyBudget: number | null;
  maxMonthlyBudget: number | null;
  categoryOrder: string[];
  anchors: AdminAnchor[];
}

interface AdminUserDetail {
  id: string;
  email: string;
  displayName: string | null;
  isAdmin: boolean;
  isActive: boolean;
  emailVerifiedAt: string | null;
  createdAt: string;
  profile: AdminProfile | null;
  favoriteCount: number;
  routeCount: number;
}

const money = new Intl.NumberFormat('tr-TR', {
  style: 'currency',
  currency: 'TRY',
  maximumFractionDigits: 0,
});

/**
 * Bir kullanıcının skorunu belirleyen ayarlar.
 *
 * Neden var: "skorlar bana yanlış geliyor" diyen kullanıcıya bakmanın yolu
 * yoktu. Skor tamamen profile bağlı (persona, kriter sırası, bütçe, önemli
 * konumlar); bunları görmeden şikâyeti değerlendirmek mümkün değil.
 */
function UserDetailPanel({
  userId,
  onClose,
}: {
  userId: string;
  onClose: () => void;
}) {
  const { data, isLoading, isError } = useQuery({
    queryKey: ['admin-user-detail', userId],
    queryFn: () => api.get<AdminUserDetail>(`/admin/users/${userId}`),
  });

  return (
    <aside className="admin-detail">
      <div className="admin-detail-head">
        <strong>{isLoading ? 'Yükleniyor…' : (data?.displayName ?? 'Kullanıcı')}</strong>
        <button
          type="button"
          className="btn-sm btn-secondary"
          onClick={onClose}
        >
          Kapat
        </button>
      </div>

      {isError && <div className="admin-error">Detay alınamadı.</div>}

      {data && (
        <div className="admin-detail-body">
          <div className="admin-detail-row">
            <span>E-posta</span>
            <span>{data.email}</span>
          </div>
          <div className="admin-detail-row">
            <span>Kayıt</span>
            <span>{new Date(data.createdAt).toLocaleDateString('tr-TR')}</span>
          </div>
          <div className="admin-detail-row">
            <span>Favori · Rota</span>
            <span>
              {data.favoriteCount} · {data.routeCount}
            </span>
          </div>

          {data.profile === null ? (
            // Profilsiz kullanıcı skor GÖREMEZ: skorlama profildeki
            // ağırlıklara dayanıyor. "Hiçbir ev görünmüyor" şikâyetinin en
            // olası sebebi bu.
            <p className="admin-count" style={{ marginTop: '0.6rem' }}>
              Bu kullanıcı henüz profil oluşturmamış — kişiselleştirilmiş skor
              üretilemez.
            </p>
          ) : (
            <>
              <div className="admin-detail-row">
                <span>Persona</span>
                <span>{data.profile.personaCode ?? '—'}</span>
              </div>
              <div className="admin-detail-row">
                <span>Bütçe</span>
                <span>
                  {data.profile.minMonthlyBudget !== null &&
                  data.profile.maxMonthlyBudget !== null
                    ? `${money.format(data.profile.minMonthlyBudget)} – ${money.format(data.profile.maxMonthlyBudget)}`
                    : '—'}
                </span>
              </div>
              <div className="admin-detail-row">
                <span>Kriter sırası</span>
                <span>{data.profile.categoryOrder.join(' · ') || '—'}</span>
              </div>
              <div className="admin-detail-row">
                <span>Önemli konumlar</span>
                <span>
                  {data.profile.anchors.length === 0
                    ? '—'
                    : data.profile.anchors
                        .map((a) => `${a.label} (${a.mode})`)
                        .join(' · ')}
                </span>
              </div>
            </>
          )}
        </div>
      )}
    </aside>
  );
}
