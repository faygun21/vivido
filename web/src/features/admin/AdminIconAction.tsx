import {
  useEffect,
  useId,
  useLayoutEffect,
  useRef,
  useState,
  type FocusEvent as ReactFocusEvent,
  type PointerEvent as ReactPointerEvent,
  type ReactNode,
} from 'react';
import { createPortal } from 'react-dom';

/**
 * Tabloda tek bir satır eylemi: ikon düğmesi + üzerine gelince beliren ipucu.
 *
 * Neden metin değil ikon: kullanıcı listesinde satır başına dört adede kadar
 * eylem vardı ("Detay", "Elle doğrula", "Admin yap", "Pasifleştir") ve dolu
 * metin düğmeleri satırın YARISINI kaplıyordu — asıl içerik olan ad ve
 * e-posta sıkışıp taşıyordu. Ad her zaman görünmeli; eylem adı yalnızca
 * kullanıcı o eylemle ilgilendiğinde.
 *
 * İpucu neden `position: fixed` ve portal ile gövdeye taşınıyor:
 * `.admin-table-wrap` dar ekranda tabloyu kendi kabında kaydırabilmek için
 * `overflow-x: auto` taşıyor ve bu, `overflow-y`yi de kırpar hâle getiriyor.
 * Satırın içine yerleştirilen mutlak konumlu bir ipucu tablonun kenarında
 * KESİLİRDİ; en sağdaki düğmede de yatay kaydırma tetiklerdi.
 */

/**
 * İlk ipucu için bekleme. Fareyi tablonun üzerinden geçiren birine anında
 * ipucu göstermek, ekranı takip edilemeyen bir yanıp sönmeye çevirir.
 */
const HOVER_DELAY_MS = 320;

/**
 * "Sıcak" pencere: bir ipucu kapandıktan sonra bu süre boyunca bir sonraki
 * ipucu BEKLEMEDEN açılır. Yan yana duran dört ikonu tek tek okumak için her
 * seferinde baştan beklemek gerekmesin — işletim sistemi araç çubukları da
 * böyle davranır.
 */
const WARM_MS = 900;

/** İpucunun ekran kenarına bırakacağı en küçük boşluk. */
const EDGE_GAP = 8;

/** Düğme ile ipucu arasındaki boşluk. */
const ANCHOR_GAP = 8;

/** Yukarıda bu kadar yer kalmadıysa ipucu düğmenin ALTINA geçer. */
const FLIP_THRESHOLD = 52;

/** Son ipucunun kapandığı an — "sıcak pencere" bunun üzerinden hesaplanır. */
let lastShownAt = 0;

/**
 * Eylemin sonucunun ağırlığı. Renk yalnızca ÜZERİNE GELİNCE beliriyor:
 * dinlenme hâlinde dört renkli ikon, satırın kendi içeriğinden daha çok
 * dikkat çekerdi (aynı gerekçeyle rozetler de tonlu, dolu değil).
 */
type ActionIntent = 'neutral' | 'accent' | 'ok' | 'danger';

interface AdminIconActionProps {
  /** İpucunda ve ekran okuyucuda görünen ad. */
  label: string;
  icon: ReactNode;
  onClick: () => void;
  /**
   * Doluysa düğme basılamaz ve ipucu SEBEBİ yazar.
   *
   * Yerel `disabled` özniteliği bilerek kullanılmıyor: pasif bir düğme fare
   * olaylarını hiç üretmez, dolayısıyla ipucu da açılmaz — kullanıcı yalnızca
   * adı silik bir ikon görür ve neden basamadığını öğrenemezdi.
   */
  disabledReason?: string | null;
  intent?: ActionIntent;
  /** Açık/kapalı durumu olan eylemler için (Detay). */
  active?: boolean;
}

export function AdminIconAction({
  label,
  icon,
  onClick,
  disabledReason,
  intent = 'neutral',
  active,
}: AdminIconActionProps) {
  const buttonRef = useRef<HTMLButtonElement>(null);
  const timer = useRef(0);
  const [anchor, setAnchor] = useState<DOMRect | null>(null);
  const reasonId = useId();

  const disabled = Boolean(disabledReason);

  function openTip() {
    const el = buttonRef.current;
    if (el) setAnchor(el.getBoundingClientRect());
  }

  function closeTip() {
    window.clearTimeout(timer.current);
    setAnchor((current) => {
      if (current) lastShownAt = Date.now();
      return null;
    });
  }

  function handleEnter(event: ReactPointerEvent<HTMLButtonElement>) {
    // Dokunmatikte "üzerine gelme" diye bir şey yok; parmakla dokunulduğunda
    // ipucu açmak, eylemin kendisiyle yarışan bir gölge katman yaratır.
    if (event.pointerType === 'touch') return;
    window.clearTimeout(timer.current);
    if (Date.now() - lastShownAt < WARM_MS) openTip();
    else timer.current = window.setTimeout(openTip, HOVER_DELAY_MS);
  }

  function handleFocus(event: ReactFocusEvent<HTMLButtonElement>) {
    // Yalnızca KLAVYE odağında, ve beklemeden: odak kasıtlı bir seçimdir.
    // `:focus-visible` süzgeci olmasaydı fareyle her tıklama düğmeye odak
    // verdiği için tıklayan kişiye artık okumadığı ipucu geri gelirdi.
    if (event.target.matches(':focus-visible')) openTip();
  }

  useEffect(() => () => window.clearTimeout(timer.current), []);

  // İpucunun yeri açıldığı andaki dikdörtgene sabitlenmiş durumda; sayfa
  // kayar veya pencere boyutlanırsa düğmesinden kopar.
  useEffect(() => {
    if (!anchor) return;
    const hide = () => {
      lastShownAt = Date.now();
      setAnchor(null);
    };
    window.addEventListener('scroll', hide, true);
    window.addEventListener('resize', hide);
    return () => {
      window.removeEventListener('scroll', hide, true);
      window.removeEventListener('resize', hide);
    };
  }, [anchor]);

  return (
    <>
      <button
        ref={buttonRef}
        type="button"
        className={`admin-icon-btn admin-icon-btn--${intent}${active ? ' is-active' : ''}`}
        aria-label={label}
        aria-pressed={active}
        aria-disabled={disabled || undefined}
        aria-describedby={disabled ? reasonId : undefined}
        onPointerEnter={handleEnter}
        onPointerLeave={closeTip}
        onFocus={handleFocus}
        onBlur={closeTip}
        onClick={() => {
          if (!disabled) onClick();
        }}
      >
        {icon}
        {/* Sebep ipucundan BAĞIMSIZ olarak da erişilebilir olmalı: ekran
            okuyucu kullanan biri düğmenin üzerine "gelmez". */}
        {disabled && (
          <span className="sr-only" id={reasonId}>
            {disabledReason}
          </span>
        )}
      </button>

      {anchor && <ActionTip anchor={anchor} text={disabledReason ?? label} />}
    </>
  );
}

/**
 * İpucu balonu.
 *
 * Konumu ölçüm sonrası boyanmadan önce (`useLayoutEffect`) yazılıyor —
 * durum güncellemesiyle yapılsaydı ilk kare yanlış yerde çizilir ve balon
 * gözle görülür biçimde yerine "zıplardı".
 */
function ActionTip({ anchor, text }: { anchor: DOMRect; text: string }) {
  const ref = useRef<HTMLDivElement>(null);

  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;

    const width = el.offsetWidth;
    const center = anchor.left + anchor.width / 2;

    // Ekran kenarında balon kaydırılır ama OK'u değil, büyüme noktası
    // düğmenin merkezinde kalır: balonun nereden çıktığı belirsizleşmesin.
    const left = Math.min(
      Math.max(center - width / 2, EDGE_GAP),
      Math.max(EDGE_GAP, window.innerWidth - width - EDGE_GAP),
    );

    const below = anchor.top < FLIP_THRESHOLD;

    el.style.left = `${left}px`;
    el.style.top = below
      ? `${anchor.bottom + ANCHOR_GAP}px`
      : `${anchor.top - ANCHOR_GAP}px`;
    el.style.transformOrigin = `${center - left}px ${below ? '0' : '100%'}`;
    el.dataset.below = below ? 'true' : 'false';
  }, [anchor]);

  return createPortal(
    // Ekran okuyucuya GİZLİ: aynı metni düğmenin `aria-label`ı zaten
    // taşıyor, balon onun yalnızca görsel karşılığı. İkisini birden
    // duyurmak her düğmeyi iki kez okuturdu.
    <div ref={ref} className="admin-tip" aria-hidden="true">
      {text}
    </div>,
    document.body,
  );
}
