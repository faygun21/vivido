#!/usr/bin/env bash
#
# Vivido — veri artefaktlarını indirir.
#
# ETL (OSRM grafikleri, harita tile'ları, seed SQL) TEK MAKİNEDE BİR KEZ
# çalıştırılır ve çıktılar GitHub Release'e yüklenir. Bu betik onları indirir.
#
# Kendi makinende `osrm-extract` çalıştırma — 16 GB RAM ister, 8 GB'lık
# makinede OOM ile çöker ve iki gün kaybettirir.
#
# Kullanım:  ./data/scripts/00_fetch_artifacts.sh [SÜRÜM]
#            `gh auth login` ile giriş yapmış olmalısın — betik aşağıda
#            `gh auth status` ile bunu zorunlu tutuyor.

set -euo pipefail

VERSION="${1:-data-v1}"
REPO="${VIVIDO_REPO:-faygun21/vivido}"
DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/../artifacts" && pwd)"

echo "▸ Depo   : $REPO"
echo "▸ Sürüm  : $VERSION"
echo "▸ Hedef  : $DEST"
echo

if ! command -v gh >/dev/null 2>&1; then
  echo "✗ GitHub CLI (gh) bulunamadı."
  echo "  winget install --id GitHub.cli -e"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "✗ GitHub'a giriş yapılmamış."
  echo "  gh auth login"
  exit 1
fi

mkdir -p "$DEST"

echo "▸ İndiriliyor (~1 GB, birkaç dakika sürebilir)..."
gh release download "$VERSION" --repo "$REPO" --dir "$DEST" --clobber

echo
echo "▸ Arşivler açılıyor..."
cd "$DEST"
for archive in *.tar.gz; do
  [ -e "$archive" ] || continue
  echo "  → $archive"
  tar -xzf "$archive"
done

echo
echo "▸ Kontrol:"
# NOT: `cankaya.osrm` diye bir dosya YOKTUR. OSRM `cankaya.osrm.*` uzantılı
# ~26 dosya üretir; `osrm-routed /data/cankaya.osrm` bunu TABAN AD olarak
# kullanır. Bu yüzden zincirin SON adımının (osrm-customize) çıktısını
# kontrol ediyoruz — varsa extract + partition + customize tamamlanmış demektir.
for required in \
  osrm/foot/cankaya.osrm.cell_metrics \
  osrm/car/cankaya.osrm.cell_metrics \
  cankaya.mbtiles \
  seed.sql; do
  if [ -e "$DEST/$required" ]; then
    echo "  ✓ $required"
  else
    echo "  ✗ $required EKSİK"
  fi
done

echo
echo "✓ Bitti. Sıradaki adımlar:"
echo
echo "  1) Servisler:"
echo "     docker compose --profile dev --profile routing up -d"
echo
echo "  2) Veriyi yükle (seed.sql /seed altına mount edili):"
echo "     docker compose exec -T postgis psql -U vivido -d vivido -f /seed/seed.sql"
echo "     # Git Bash kullanıyorsan komutun başına MSYS_NO_PATHCONV=1 ekle"
echo
echo "  3) Doğrula:  pnpm db:check      # 6/6 PASS bekleniyor"
