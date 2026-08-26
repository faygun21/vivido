-- ══════════════════════════════════════════════════════════════════════
--  Vivido — osm2pgsql sokak çıktısını şema tablosuna aktarır
--
--  04_merge_osm_into_schema.sql ile aynı gerekçe (K-01): osm2pgsql ara
--  tabloya yazar, şemadaki gerçek tablo BURADA doldurulur. Böylece
--  `db/schema/012_add_streets.sql` tek doğruluk kaynağı olarak kalır ve
--  osm2pgsql `streets` tablosunu düşürüp PK/indeksini yok edemez.
--
--  Kullanım (osm2pgsql'den HEMEN SONRA):
--    docker compose exec -T postgis psql -U vivido -d vivido \
--      -v ON_ERROR_STOP=1 -f /work/data/scripts/05_merge_streets_into_schema.sql
--
--  Bunu doğrudan çağırmak yerine ./data/scripts/05_load_streets.sh
--  kullanmak daha kolay — o betik osm2pgsql adımını da yapıyor.
-- ══════════════════════════════════════════════════════════════════════

\set ON_ERROR_STOP on

BEGIN;

-- Tekrar çalıştırılabilir olmalı: ETL yeniden koşulduğunda sokaklar
-- ikizlenmesin. `streets` tamamen ETL çıktısı olduğu için TRUNCATE güvenli —
-- kullanıcı verisi taşımıyor ve hiçbir tablo ona FK vermiyor.
TRUNCATE streets RESTART IDENTITY;

INSERT INTO streets (osm_id, name, geom, data_version)
SELECT osm_id, name, geom, data_version
FROM osm_streets;

COMMIT;

-- ─── Özet ───
-- Beklenen: birkaç bin satır, birkaç yüz farklı sokak adı. Sıfır çıkarsa
-- lua filtresi ya da .osm.pbf kesiti yanlış demektir.
SELECT count(*) AS sokak_parcasi, count(DISTINCT name) AS farkli_ad FROM streets;
