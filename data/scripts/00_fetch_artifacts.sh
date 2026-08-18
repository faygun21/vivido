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
#            gh auth login  ile giriş yapmış olmalısın (private repo).

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
for required in osrm/foot/cankaya.osrm osrm/car/cankaya.osrm cankaya.mbtiles seed.sql; do
  if [ -e "$DEST/$required" ]; then
    echo "  ✓ $required"
  else
    echo "  ✗ $required EKSİK"
  fi
done

echo
echo "✓ Bitti. Şimdi routing servislerini başlatabilirsin:"
echo "    docker compose --profile dev --profile routing up -d"
