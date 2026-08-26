#!/usr/bin/env bash
#
# Vivido — adlı sokakları veritabanına yükler (konut adresi için).
#
# NE YAPAR
#   1. data/artifacts/cankaya.osm.pbf içinden ADI OLAN yol parçalarını
#      osm2pgsql ile `osm_streets` ara tablosuna çıkarır
#   2. Ara tablodan şemadaki `streets` tablosuna aktarır
#
# NE YAPMAZ
#   Planetiler, OSRM, POI çıkarımı, sentetik konut üretimi — hiçbiri tekrar
#   koşmaz. Bu adım tek başına birkaç dakika sürer, ~1 GB'lık boru hattının
#   yeniden koşulmasına GEREK YOKTUR.
#
# ⚠️ Her şey `etl` konteynerinden çalışır, `postgis`ten değil: `postgis`
# yalnızca ./db ve ./data/artifacts mount ediyor, /work/data/scripts orada
# YOK. `etl` ise ./data'yı /work/data'ya bağlıyor ve psql taşıyor — 04'ün
# dokümante edilmiş deseni de bu (README §6, docs/04-MEVCUT-DURUM §6).
#
# ÖN KOŞULLAR
#   · docker compose --profile etl build etl     (bir kez)
#   · pnpm infra:up                              (postgis ayakta)
#   · pnpm db:migrate                            (009_add_streets.sql uygulanmış)
#   · data/artifacts/cankaya.osm.pbf mevcut      (00_fetch_artifacts.sh)
#
# Kullanım:  ./data/scripts/05_load_streets.sh
#
# Bu adım ATLANABİLİR: `streets` boş kalırsa API adres alanını NULL döner ve
# arayüz mahalle adına düşer. Hata görünmez, sadece sokak adı yazmaz.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PBF="data/artifacts/cankaya.osm.pbf"

if [ ! -f "$PBF" ]; then
  echo "✗ $PBF yok."
  echo "  ./data/scripts/00_fetch_artifacts.sh ile indir."
  exit 1
fi

etl() {
  # `</dev/null`: stdin tüketen bir komut betiğin geri kalanını yutmasın.
  # Bu, K-13'te sekiz deploy'u sessizce no-op yapan hatanın ta kendisiydi.
  docker compose --profile etl run --rm -T etl "$@" </dev/null
}

echo "▸ 1/3 · Şema kontrolü — streets tablosu var mı?"
# db:migrate atlanmışsa osm2pgsql sorunsuz koşar, merge adımı
# "relation streets does not exist" ile patlardı. Sebebi burada söylemek
# psql'in ham hatasından çok daha anlaşılır.
if ! etl psql -tAc "SELECT to_regclass('public.streets')" | tr -d '\r' | grep -qx 'streets'; then
  echo "✗ streets tablosu yok — şema güncel değil."
  echo "  pnpm db:migrate"
  exit 1
fi

echo "▸ 2/3 · osm2pgsql — adlı yollar osm_streets'e çıkarılıyor..."
# --output=flex + kendi style dosyamız. YALNIZCA `osm_streets` tablosuna
# dokunur; osm_pois / osm_buildings olduğu gibi kalır (bkz. lua başlığı).
etl osm2pgsql \
  --output=flex \
  --style /work/data/lua/vivido_streets.lua \
  "/work/$PBF"

echo "▸ 3/3 · Şema tablosuna aktarılıyor..."
etl psql -v ON_ERROR_STOP=1 -f /work/data/scripts/05_merge_streets_into_schema.sql

echo
echo "✓ Bitti. Doğrulama — Kızılay çevresindeki en yakın sokak:"
etl psql -tAc \
  "SELECT name FROM streets
    ORDER BY geom <-> ST_SetSRID(ST_MakePoint(32.8541, 39.9208), 4326)
    LIMIT 1"
