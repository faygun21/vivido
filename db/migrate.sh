#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
#  Vivido — şema uygulayıcı
#
#  NEDEN VAR:
#  docker-entrypoint-initdb.d betikleri YALNIZCA konteyner ilk kez
#  açıldığında çalışır. Şema sonradan değişirse tek seçenek volume'ü
#  silmek olurdu (pnpm infra:reset) — ve tüm veri giderdi.
#  6.000 konut + 28.000 POI'yi her kolon eklemede yeniden yüklemek
#  kabul edilemez. Bu betik yalnızca HENÜZ UYGULANMAMIŞ dosyaları
#  çalıştırır; veriye dokunmaz.
#
#  KULLANIM:
#      pnpm db:migrate
#      docker compose exec -T postgis bash /db/migrate.sh
#
#  YENİ ŞEMA DEĞİŞİKLİĞİ NASIL EKLENİR:
#      1. db/schema/00N_aciklayici_ad.sql dosyasını oluştur
#         → N, mevcut EN BÜYÜK numaradan bir fazla olmalı.
#           Aynı numarayı ikinci kez kullanma; betik reddeder.
#      2. Yalnızca DEĞİŞİKLİĞİ yaz (ALTER TABLE …), 001'i düzenleme
#      3. pnpm db:migrate
#
#  ⚠ Uygulanmış bir dosyayı sonradan DÜZENLEME. Çalışan veritabanları
#    o değişikliği görmez; yalnızca sıfırdan kurulanlar görür — ve iki
#    makine sessizce farklı şemaya sahip olur. Betik bunu checksum ile
#    yakalar ve uyarır.
#
#  YENİDEN ADLANDIRMA: bir dosyanın adı değişir ama içeriği aynı kalırsa
#  betik bunu checksum'dan tanır ve defterdeki adı günceller — dosyayı
#  İKİNCİ KEZ UYGULAMAZ. Numara düzeltmeleri bu sayede tüm makinelerde
#  kendiliğinden çözülür.
# ══════════════════════════════════════════════════════════════════════

set -euo pipefail

# `--baseline`: mevcut şemayı "uygulanmış" kabul edip defteri doldurur.
# İNSAN KARARIDIR, otomatik çalışmaz — sebebi aşağıda.
BASELINE_ONAY=0
[ "${1:-}" = "--baseline" ] && BASELINE_ONAY=1

SCHEMA_DIR="${SCHEMA_DIR:-/db/schema}"
DB_USER="${POSTGRES_USER:-vivido}"
DB_NAME="${POSTGRES_DB:-vivido}"

psql_q() { psql -v ON_ERROR_STOP=1 -q -U "$DB_USER" -d "$DB_NAME" "$@"; }
psql_v() { psql -v ON_ERROR_STOP=1 -tA -U "$DB_USER" -d "$DB_NAME" "$@"; }

if [ ! -d "$SCHEMA_DIR" ]; then
  echo "✗ Şema klasörü bulunamadı: $SCHEMA_DIR" >&2
  exit 1
fi

# Dosyalar ada göre sıralı uygulanır — bu yüzden numara öneki zorunlu.
mapfile -t FILES < <(find "$SCHEMA_DIR" -maxdepth 1 -name '*.sql' -type f | sort)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "✗ $SCHEMA_DIR içinde .sql dosyası yok." >&2
  exit 1
fi

# ─── Çakışan numara koruması ───
#
# Sıralama ada göre yapılıyor. İki dosya aynı numarayı taşırsa aralarındaki
# sıra numaraya değil, adın geri kalanına göre belirlenir — yani rastlantısal.
# Biri diğerinin yarattığı tabloya bağlıysa sıra sessizce yanlış olur ve
# hata yalnızca SIFIRDAN kurulan makinelerde çıkar. Depoda üç tane 004
# birikmişti; bu kapı onu tekrarlatmıyor.
COPYA=$(for f in "${FILES[@]}"; do basename "$f" | grep -oE '^[0-9]+'; done | sort | uniq -d)
if [ -n "$COPYA" ]; then
  echo "✗ Aynı numarayı taşıyan birden fazla şema dosyası var:" >&2
  for n in $COPYA; do
    echo "    $n →" >&2
    for f in "${FILES[@]}"; do
      case "$(basename "$f")" in "$n"_*) echo "        $(basename "$f")" >&2 ;; esac
    done
  done
  echo "  Numaralar benzersiz olmalı. Dosyayı yeniden adlandır;" >&2
  echo "  içeriği değişmediği sürece betik bunu tanır ve yeniden uygulamaz." >&2
  exit 2
fi

# ─── Defter tablosu ───
LEDGER_VAR=$(psql_v -c "SELECT to_regclass('public.schema_migrations') IS NOT NULL;")

psql_q -c "
CREATE TABLE IF NOT EXISTS schema_migrations (
  filename   text PRIMARY KEY,
  checksum   text        NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE schema_migrations IS
  'db/schema altindaki hangi dosyalarin uygulandigi. db/migrate.sh yonetir.';"

# ─── Baseline — ARTIK OTOMATİK DEĞİL ───
#
# ⚠️ BU DAL BİR KEZ VERİ KAYBINA RAMAK KALA BİR HATAYA SEBEP OLDU.
#
# Eskiden: defter yoksa ve şema varsa, betik "initdb.d hepsini çalıştırmıştır"
# varsayıp TÜM dosyaları uygulanmış işaretliyordu. Ama initdb.d yalnızca
# konteyner İLK AÇILDIĞI ANDA var olan dosyaları çalıştırır. Sonradan eklenen
# şema dosyaları hiç uygulanmadığı hâlde "uygulandı" diye deftere yazılıyordu.
#
# Staging'de tam olarak bu oldu: `004_add_profile_names.sql` ve
# `005_add_profile_category_order.sql` konteyner açıldıktan SONRA kopyalandı.
# Baseline ikisini de uygulanmış saydı; veritabanında `first_name`,
# `last_name` sütunları ve `user_profile_category_order` tablosu YOKTU ama
# defter "var" diyordu. Profil kodu çalışma anında patlayacaktı ve sebebi
# hiçbir logda görünmeyecekti — K-01'in uyardığı sessiz şema kayması.
#
# Baseline, geçmiş hakkında bir İDDİADIR. Betik bunu bilemez; yalnızca insan
# doğrulayıp söyleyebilir. O yüzden artık açık bayrak istiyor.
if [ "$LEDGER_VAR" != "t" ]; then
  SEMA_VAR=$(psql_v -c "SELECT to_regclass('public.properties') IS NOT NULL;")
  if [ "$SEMA_VAR" = "t" ] && [ "$BASELINE_ONAY" -eq 0 ]; then
    echo "✗ Şema var ama defter yok." >&2
    echo >&2
    echo "  Bu veritabanı migrate.sh'ten önce kurulmuş. Dosyaların GERÇEKTEN" >&2
    echo "  uygulanıp uygulanmadığını betik bilemez; körü körüne 'uygulandı'" >&2
    echo "  demek şemayı sessizce eksik bırakır." >&2
    echo >&2
    echo "  Şemanın güncel olduğundan EMİNSEN:" >&2
    echo "      docker compose exec -T postgis bash /db/migrate.sh --baseline" >&2
    echo >&2
    echo "  Emin değilsen — en temizi sıfırdan kurmak:" >&2
    echo "      pnpm infra:reset && pnpm db:migrate      (DİKKAT: veri gider)" >&2
    exit 3
  fi

  if [ "$SEMA_VAR" = "t" ]; then
    echo "▸ --baseline verildi: mevcut şema uygulanmış kabul ediliyor."
    for f in "${FILES[@]}"; do
      base=$(basename "$f")
      sum=$(md5sum "$f" | cut -d' ' -f1)
      psql_q -c "INSERT INTO schema_migrations (filename, checksum)
                 VALUES ('$base', '$sum') ON CONFLICT (filename) DO NOTHING;"
      echo "  = $base (baseline)"
    done
    echo "✓ Baseline tamam."
    exit 0
  fi
fi

# ─── Uygulama döngüsü ───
UYGULANAN=0
DEGISMIS=0

for f in "${FILES[@]}"; do
  base=$(basename "$f")
  sum=$(md5sum "$f" | cut -d' ' -f1)
  kayitli=$(psql_v -c "SELECT checksum FROM schema_migrations WHERE filename = '$base';")

  # ─── Yeniden adlandırma tespiti ───
  #
  # Dosya defterde bu adla yok, ama AYNI CHECKSUM başka bir adla kayıtlı →
  # içerik değişmemiş, yalnızca ad değişmiş. Yeniden uygulamak "tablo zaten
  # var" ile patlardı; doğru davranış defterdeki adı güncellemek.
  #
  # Bu olmadan numara düzeltmesi yapılamazdı: dosya adını değiştirdiğim an
  # ekipteki 7 makinenin ve staging'in defteri onu "yeni dosya" sanıp
  # yeniden çalıştırmaya kalkardı. Böylece herkes tek `pnpm db:migrate` ile
  # kendiliğinden hizalanıyor.
  if [ -z "$kayitli" ]; then
    eski_ad=$(psql_v -c "SELECT filename FROM schema_migrations
                         WHERE checksum = '$sum'
                           AND filename NOT IN (SELECT filename FROM schema_migrations WHERE filename = '$base')
                         LIMIT 1;")
    if [ -n "$eski_ad" ]; then
      psql_q -c "UPDATE schema_migrations SET filename = '$base' WHERE filename = '$eski_ad';"
      echo "  ↻ $eski_ad → $base (yeniden adlandırma, tekrar uygulanmadı)"
      continue
    fi
  fi

  if [ -n "$kayitli" ]; then
    if [ "$kayitli" != "$sum" ]; then
      echo "  ⚠ $base — UYGULANDIKTAN SONRA DEĞİŞTİRİLMİŞ"
      echo "      Bu veritabanı eski halini içeriyor. Değişikliği yeni bir"
      echo "      dosyaya (ALTER TABLE …) taşı, yoksa makineler ayrışır."
      DEGISMIS=$((DEGISMIS + 1))
    else
      echo "  = $base"
    fi
    continue
  fi

  echo "  + $base uygulanıyor…"
  psql_q -f "$f"
  psql_q -c "INSERT INTO schema_migrations (filename, checksum) VALUES ('$base', '$sum');"
  UYGULANAN=$((UYGULANAN + 1))
done

echo
if [ "$UYGULANAN" -eq 0 ]; then
  echo "✓ Şema güncel — uygulanacak yeni dosya yok."
else
  echo "✓ $UYGULANAN dosya uygulandı."
fi

if [ "$DEGISMIS" -gt 0 ]; then
  echo "⚠ $DEGISMIS dosya uygulandıktan sonra değiştirilmiş — yukarıya bak."
  exit 2
fi
