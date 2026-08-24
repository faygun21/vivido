-- ══════════════════════════════════════════════════════════════════════
--  Vivido — osm2pgsql ham çıktısını şema tablolarına aktarır
--
--  NEDEN GEREKLİ
--  osm2pgsql'in flex `define_table` çağrısı, verilen ada sahip tabloyu
--  DÜŞÜRÜP YENİDEN YARATIR. Lua doğrudan `pois` / `buildings` yazdığında
--  db/schema/001_initial.sql'deki tanımlar siliniyordu:
--    · `id bigserial PRIMARY KEY`  → kayboluyor
--    · `category_code` → poi_categories FK'sı → kayboluyor
--    · `idx_poi_cat` indeksi → kayboluyor
--  Sonuç: gen_properties.py "column b.id does not exist" ile duruyor,
--  properties.building_id ve property_poi_access.poi_id FK'ları kuruluyor.
--
--  Bu, docs/02-KARARLAR.md K-01'in açıkça uyardığı "iki şema kaynağı"
--  durumudur. Çözüm: ETL ara tablolara (`osm_pois`, `osm_buildings`)
--  yazar, şemadaki gerçek tablolar burada doldurulur. Doğruluk kaynağı
--  db/schema/*.sql olarak KALIR.
--
--  Kullanım (osm2pgsql'den HEMEN SONRA):
--    docker compose exec -T postgis psql -U vivido -d vivido \
--      -v ON_ERROR_STOP=1 -f /work/data/scripts/04_merge_osm_into_schema.sql
-- ══════════════════════════════════════════════════════════════════════

\set ON_ERROR_STOP on

BEGIN;

-- ─── Şema tablolarını 001_initial.sql'deki haliyle geri kur ───
-- osm2pgsql bunları düşürmüş olabilir; düşürmediyse de yeniden kurmak
-- güvenli çünkü içerikleri tamamen ETL'den geliyor.

DROP TABLE IF EXISTS property_poi_access CASCADE;
DROP TABLE IF EXISTS pois CASCADE;
DROP TABLE IF EXISTS buildings CASCADE;

CREATE TABLE pois (
  id            bigserial PRIMARY KEY,
  osm_id        bigint,
  osm_type      char(1),                -- 'n' node | 'w' way | 'r' relation
  name          text,
  category_code text NOT NULL REFERENCES poi_categories(code),
  geom          geometry(Point, 4326) NOT NULL,
  data_version  text NOT NULL
);
CREATE INDEX idx_poi_geom ON pois USING GIST (geom);
CREATE INDEX idx_poi_cat  ON pois (category_code);

CREATE TABLE buildings (
  id           bigserial PRIMARY KEY,
  osm_id       bigint,
  geom         geometry(Polygon, 4326) NOT NULL,
  levels       smallint,
  data_version text NOT NULL
);
CREATE INDEX idx_bld_geom ON buildings USING GIST (geom);

CREATE TABLE property_poi_access (
  property_id   bigint NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  category_code text   NOT NULL REFERENCES poi_categories(code),
  poi_id        bigint NOT NULL REFERENCES pois(id),
  duration_min  numeric(5,1) NOT NULL,
  distance_m    integer NOT NULL,
  data_version  text NOT NULL,
  PRIMARY KEY (property_id, category_code)
);
CREATE INDEX idx_ppa_prop ON property_poi_access USING BRIN (property_id);

-- ─── Ham çıktıyı aktar ───

INSERT INTO pois (osm_id, osm_type, name, category_code, geom, data_version)
SELECT osm_id, osm_type, name, category_code, geom, data_version
FROM osm_pois;

INSERT INTO buildings (osm_id, geom, levels, data_version)
SELECT osm_id, geom, levels, data_version
FROM osm_buildings;

COMMIT;

-- ─── Özet ───
SELECT 'pois' AS tablo, count(*) AS satir FROM pois
UNION ALL
SELECT 'buildings', count(*) FROM buildings;
