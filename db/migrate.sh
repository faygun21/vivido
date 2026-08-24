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
#      1. db/schema/003_aciklayici_ad.sql dosyasını oluştur
#      2. Yalnızca DEĞİŞİKLİĞİ yaz (ALTER TABLE …), 001'i düzenleme
#      3. pnpm db:migrate
#
#  ⚠ Uygulanmış bir dosyayı sonradan DÜZENLEME. Çalışan veritabanları
#    o değişikliği görmez; yalnızca sıfırdan kurulanlar görür — ve iki
#    makine sessizce farklı şemaya sahip olur. Betik bunu checksum ile
#    yakalar ve uyarır.
# ══════════════════════════════════════════════════════════════════════

set -euo pipefail

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

# ─── İlk kurulum tespiti (baseline) ───
#
# Konteyner ilk açıldığında docker-entrypoint-initdb.d, db/schema
# içindeki TÜM .sql dosyalarını zaten çalıştırmıştır — ama defter o
# sırada yoktu. Bu durumda dosyaları yeniden çalıştırmak "tablo zaten
# var" hatası verir. Onun yerine hepsini "uygulanmış" olarak işaretleriz.
if [ "$LEDGER_VAR" != "t" ]; then
  SEMA_VAR=$(psql_v -c "SELECT to_regclass('public.properties') IS NOT NULL;")
  if [ "$SEMA_VAR" = "t" ]; then
    echo "▸ Mevcut şema bulundu, defter yok → baseline alınıyor."
    echo "  (initdb.d bu dosyaları zaten çalıştırmış, yeniden çalıştırılmayacak.)"
    for f in "${FILES[@]}"; do
      base=$(basename "$f")
      sum=$(md5sum "$f" | cut -d' ' -f1)
      psql_q -c "INSERT INTO schema_migrations (filename, checksum)
                 VALUES ('$base', '$sum') ON CONFLICT (filename) DO NOTHING;"
      echo "  = $base (baseline)"
    done
    echo "✓ Baseline tamam — şema güncel."
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
