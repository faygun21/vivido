import { Link } from 'react-router-dom';
import type { Anchor, Persona, UserProfile } from '@vivido/shared';
import { api } from '@/shared/api/client';
import { useSessionQuery } from '@/shared/api/sessionQuery';
import { useAuthStore } from '@/features/auth/authStore';
import { AnchorPanel } from '@/features/anchors/AnchorPanel';
import { CATEGORY_VISUALS, personaVisual } from '@/shared/persona/personaVisuals';
import { RoutesPanel } from './FavoritesAndRoutesPanel';

/**
 * Profil yönetimi — persona/kira aralığı özeti + anchor paneli.
 *
 * ⭐ Yeniden tasarlandı (tasarım turu): sayfa üç adet düz beyaz kutudan
 * ibaretti ve her kutu bir başlık + birkaç satır gri metin taşıyordu.
 * İçerideki bilgi (persona, bütçe, kriter sırası) skorlamayı doğrudan
 * belirlediği hâlde ekranda hiçbir ağırlığı yoktu; "Persona: Öğrenci"
 * satırı, altındaki açıklama cümlesiyle aynı boyuttaydı.
 *
 * Şimdi: üstte kimlik başlığı, altında ikonlu başlıkları olan kartlar.
 * Persona kendi ikonuyla, bütçe bir ölçüm gibi, kriter sırası ise
 * gerçekten sıralı rozetlerle görünüyor — kullanıcı "skorum neye göre
 * hesaplanıyor" sorusunu tek bakışta cevaplayabiliyor.
 *
 * Anchor paneli hem burada hem onboarding'in 3. adımında kullanılıyor;
 * bileşen kendi kendine yettiği için iki yerde de aynı kod çalışıyor.
 */
export function ProfilePage() {
  const user = useAuthStore((s) => s.user);

  const { data: profile, isLoading } = useSessionQuery({
    queryKey: ['profile'],
    queryFn: () => api.get<UserProfile>('/profile'),
    retry: false,
  });

  const { data: personas = [] } = useSessionQuery({
    queryKey: ['personas'],
    queryFn: () => api.get<Persona[]>('/personas'),
  });

  // Anchor sayısı başlıkta gösteriliyor. Aynı sorgu anahtarı olduğu için
  // ek istek gitmez — `AnchorPanel` ile ortak önbellekten okunur.
  const { data: anchors = [] } = useSessionQuery({
    queryKey: ['anchors'],
    queryFn: () => api.get<Anchor[]>('/profile/anchors'),
    retry: false,
  });

  const persona = personas.find((p) => p.code === profile?.personaCode);
  const visual = personaVisual(profile?.personaCode);

  const fullName = [profile?.firstName, profile?.lastName]
    .filter((part) => part && part.trim() !== '')
    .join(' ');

  return (
    <section className="page profile">
      <ProfileHero name={fullName} email={user?.email} personaName={persona?.displayNameTr} />

      <article className="pcard">
        <header className="pcard-head">
          <span className="pcard-icon" aria-hidden="true">
            <img src={visual.mainIcon} alt="" />
          </span>
          <div className="pcard-head-text">
            <h2>Yaşam tarzın ve bütçen</h2>
            <p>Konut skorların bu ikisine göre hesaplanıyor.</p>
          </div>
        </header>

        {isLoading ? (
          <div className="pcard-body" aria-busy="true">
            <div className="skeleton persona-summary-skeleton" />
          </div>
        ) : profile ? (
          <div className="pcard-body">
            <div className="persona-summary">
              <div className="persona-summary-main">
                <p className="persona-summary-name">
                  {persona?.displayNameTr ?? profile.personaCode}
                </p>
                {persona && (
                  <p className="persona-summary-desc">{persona.descriptionTr}</p>
                )}
              </div>

              {/* Bütçe bir ÖLÇÜM: `dt`/`dd` satırı olarak yazıldığında
                  yanındaki açıklama cümlesiyle aynı ağırlıkta okunuyordu.
                  Kendi kutusunda, kendi ölçeğinde. */}
              <div className="persona-budget">
                <span className="persona-budget-label">Aylık kira aralığı</span>
                <span className="persona-budget-value">
                  {formatBudgetRange(profile.minMonthlyBudget, profile.maxMonthlyBudget)}
                </span>
              </div>
            </div>

            {profile.categoryOrder.length > 0 && (
              <div className="persona-criteria">
                <span className="pcard-label">Öncelik sıran</span>
                {/* Sıra numarası GÖRÜNÜR: birinci kriterin skora katkısı
                    sonuncunun katıyken, liste bunu yalnızca soldan sağa
                    dizilimle anlatıyordu. */}
                <ol className="criteria-chips">
                  {profile.categoryOrder.slice(0, 5).map((code, index) => {
                    const meta = CATEGORY_VISUALS[code];
                    return (
                      <li key={code} className="criteria-chip">
                        <span className="criteria-chip-rank">{index + 1}</span>
                        {meta && <img src={meta.icon} alt="" />}
                        {meta?.label ?? code}
                      </li>
                    );
                  })}
                  {profile.categoryOrder.length > 5 && (
                    <li className="criteria-chip criteria-chip--more">
                      +{profile.categoryOrder.length - 5}
                    </li>
                  )}
                </ol>
              </div>
            )}
          </div>
        ) : (
          <div className="pcard-body">
            <div className="empty-state">
              <span className="empty-state-icon" aria-hidden="true">👤</span>
              <p className="empty-state-title">Profil bulunamadı</p>
              <p className="empty-state-text">
                Skorlama için önce yaşam tarzını ve bütçeni belirlemen gerekiyor.{' '}
                <Link to="/onboarding">Onboarding&apos;i tamamla</Link>
              </p>
            </div>
          </div>
        )}

        <footer className="pcard-foot">
          <Link className="btn-secondary btn-sm" to="/onboarding">
            Persona / kira aralığı değiştir
          </Link>
        </footer>
      </article>

      {/* Anchor sayacı başlığa taşındı: "1 / 3" bilgisi haritanın ALTINDA,
          iki paragraf metnin arasında duruyordu ve kullanıcı kaç yer daha
          ekleyebileceğini görmek için kaydırmak zorundaydı. */}
      <AnchorPanel usedCount={anchors.length} />

      <RoutesPanel />
    </section>
  );
}

function ProfileHero({
  name,
  email,
  personaName,
}: {
  name: string;
  email: string | undefined;
  personaName: string | undefined;
}) {
  // Baş harfler — profil fotoğrafı diye bir kavram yok, ama boş bir daire
  // "yüklenemedi" gibi okunur. İki harf kimliği taşımaya yeter.
  const initials =
    name
      .split(' ')
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toLocaleUpperCase('tr-TR') ?? '')
      .join('') || (email?.[0]?.toLocaleUpperCase('tr-TR') ?? '?');

  return (
    <header className="profile-hero">
      <span className="profile-avatar" aria-hidden="true">{initials}</span>

      <div className="profile-hero-text">
        <h1>{name || 'Profil'}</h1>
        <p className="profile-hero-meta">
          {email}
          {personaName && (
            <>
              {' · '}
              <span className="profile-hero-persona">{personaName}</span>
            </>
          )}
        </p>
      </div>
    </header>
  );
}

function formatBudgetRange(
  minMonthlyBudget: number | null,
  maxMonthlyBudget: number | null,
) {
  if (minMonthlyBudget != null && maxMonthlyBudget != null) {
    return `${minMonthlyBudget.toLocaleString('tr-TR')} ₺ – ${maxMonthlyBudget.toLocaleString('tr-TR')} ₺`;
  }

  if (minMonthlyBudget != null) {
    return `${minMonthlyBudget.toLocaleString('tr-TR')} ₺ ve üzeri`;
  }

  if (maxMonthlyBudget != null) {
    return `${maxMonthlyBudget.toLocaleString('tr-TR')} ₺'ye kadar`;
  }

  return 'Girilmedi';
}
