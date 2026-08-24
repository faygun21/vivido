-- ══════════════════════════════════════════════════════════════════════
--  Vivido — başlangıç şeması
--
--  Kaynak: docs/01-PROJE-PLANI.md §5 (Veri Modeli)
--  Kapsam: habi-v2-3-hafta-plan.md (daraltılmış MVP)
--
--  Bu dosya docker-compose.yml tarafından /docker-entrypoint-initdb.d'ye
--  mount edilir ve konteyner İLK KEZ açıldığında alfabetik sırayla çalışır.
--  Zaten dolu bir volume'de TEKRAR ÇALIŞMAZ — değişiklik sonrası:
--      pnpm infra:reset       (DİKKAT: volume'ü siler, veri gider)
--
--  Sıralama kuralı: referans veren tablo, referans alınandan SONRA gelir.
--  (Plan dokümanındaki DDL bu sırayı bozuyordu — persona_category_weights
--   henüz var olmayan poi_categories'e bakıyordu. Burada düzeltildi.)
-- ══════════════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS postgis;   -- geometri tipleri, GiST, KNN
CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS citext;    -- büyük/küçük harf duyarsız e-posta


-- ══════════════════════════════════════════════════════════════════════
--  1. POI KATEGORİLERİ — skor parametrelerinin TEK kaynağı
--
--  t_ideal / t_half / t_cutoff kodda sabit DEĞİLDİR; Vivido.Scoring
--  bunları girdi olarak alır. Kalibrasyon = bu tablodaki satırları
--  değiştirmek, kod değiştirmek değil.
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE poi_categories (
  code            text PRIMARY KEY,
  display_name_tr text NOT NULL,
  t_ideal_min     numeric(4,1) NOT NULL,  -- bu süreye kadar 100 puan
  t_half_min      numeric(4,1) NOT NULL,  -- bu sürede 50 puan
  t_cutoff_min    numeric(4,1) NOT NULL,  -- ötesi 0 puan
  search_radius_m integer      NOT NULL DEFAULT 2500,
  min_poi_count   smallint     NOT NULL DEFAULT 5,
  active          boolean      NOT NULL DEFAULT true,

  -- Bozunum formülü t_half > t_ideal varsayar; sıfıra bölme olmasın.
  CONSTRAINT ck_poi_cat_esikler CHECK (t_ideal_min < t_half_min
                                   AND t_half_min  < t_cutoff_min)
);

COMMENT ON TABLE poi_categories IS
  'Skorlama eşikleri. 3 haftalık planda 10 kategoriden 8''e indirildi (pet + bank kesildi).';


-- OSM etiketi → kategori eşlemesi. ETL (osm2pgsql) bunu okur.
CREATE TABLE poi_tag_mapping (
  id            bigserial PRIMARY KEY,
  osm_key       text NOT NULL,
  osm_value     text NOT NULL,
  category_code text NOT NULL REFERENCES poi_categories(code),
  UNIQUE (osm_key, osm_value, category_code)
);


-- ══════════════════════════════════════════════════════════════════════
--  2. PERSONA VE AĞIRLIKLAR
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE personas (
  code            text PRIMARY KEY,       -- 'student' | 'family_kids' | …
  display_name_tr text NOT NULL,
  description_tr  text NOT NULL,
  icon            text
);

CREATE TABLE persona_category_weights (
  persona_code  text NOT NULL REFERENCES personas(code)       ON DELETE CASCADE,
  category_code text NOT NULL REFERENCES poi_categories(code) ON DELETE CASCADE,
  weight        numeric(4,3) NOT NULL CHECK (weight BETWEEN 0 AND 1),
  PRIMARY KEY (persona_code, category_code)
);

-- ⚠ Değişmez kural (I8 / DQ-03): her persona için SUM(weight) = 1.000
-- Tek satırlık CHECK ile ifade edilemez (satırlar arası kısıt) — bu yüzden
-- db/checks/dq.sql içinde error seviyesinde kapı olarak denetlenir.
COMMENT ON TABLE persona_category_weights IS
  'Her persona icin agirlik toplami 1.000 olmalidir — DQ-03 ile denetlenir.';


-- ══════════════════════════════════════════════════════════════════════
--  3. KULLANICI, PROFİL, ANCHOR
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         citext UNIQUE NOT NULL,
  password_hash text NOT NULL,
  display_name  text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Refresh token saklama.
-- NOT: Plan dokümanının §5 DDL'inde bu tablo YOK, ama §10'da
-- POST /auth/refresh endpoint'i var. Sunucu tarafında saklanmadan
-- refresh token iptal edilemez (çıkış yapınca token yaşamaya devam eder).
-- Bu yüzden eklendi — Hafta 1 Gün 2 auth işi buna bağlı.
CREATE TABLE refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  text NOT NULL UNIQUE,   -- ham token ASLA saklanmaz
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_user ON refresh_tokens (user_id, expires_at DESC);

CREATE TABLE user_profiles (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES users(id)     ON DELETE CASCADE,
  persona_code   text NOT NULL REFERENCES personas(code),
  monthly_budget numeric(10,2) CHECK (monthly_budget IS NULL OR monthly_budget > 0),
                 -- NULL → bütçe skoru devre dışı, Skor = YaşamSkoru
  updated_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id)                    -- v1: kullanıcı başına tek profil
);

-- ★ ANCHOR — W4'ün kalbi. Öncelik sırası burada tutulur.
CREATE TABLE anchors (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  label      text NOT NULL,                       -- 'Hacettepe Beytepe'
  geom       geometry(Point, 4326) NOT NULL,
  mode       text NOT NULL DEFAULT 'car' CHECK (mode IN ('foot','car')),

  -- 3 haftalık planda üst sınır 5'ten 3'e indirildi ("Anchor maks 5 → 3").
  -- Ağırlık formülü (geometrik 0.5^(i-1)) değişmedi; sadece tavan düştü.
  priority   smallint NOT NULL CHECK (priority BETWEEN 1 AND 3),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Yeniden sıralama tek transaction'da yapılır ve ARA ADIMDA çakışma olur
-- (① ile ② yer değiştirirken anlık olarak iki tane ② bulunur).
-- DEFERRABLE olmasaydı sürükle-bırak her seferinde patlardı.
ALTER TABLE anchors ADD CONSTRAINT uq_anchor_priority
  UNIQUE (profile_id, priority) DEFERRABLE INITIALLY DEFERRED;

CREATE INDEX idx_anchor_geom    ON anchors USING GIST (geom);
CREATE INDEX idx_anchor_profile ON anchors (profile_id, priority);


-- ══════════════════════════════════════════════════════════════════════
--  4. OSM TÜREVİ VERİ — ETL doldurur (şu an boş)
-- ══════════════════════════════════════════════════════════════════════
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

CREATE TABLE neighborhoods (
  id           bigserial PRIMARY KEY,
  name         text NOT NULL,
  geom         geometry(MultiPolygon, 4326) NOT NULL,
  rent_index   numeric(5,3) NOT NULL DEFAULT 1.000,  -- 1.00 = Çankaya ortalaması
  data_version text NOT NULL
);
CREATE INDEX idx_nb_geom ON neighborhoods USING GIST (geom);

CREATE TABLE buildings (                -- sentetik konut üretiminin tabanı
  id           bigserial PRIMARY KEY,
  osm_id       bigint,
  geom         geometry(Polygon, 4326) NOT NULL,
  levels       smallint,
  data_version text NOT NULL
);
CREATE INDEX idx_bld_geom ON buildings USING GIST (geom);


-- ══════════════════════════════════════════════════════════════════════
--  5. KİRALIK KONUTLAR — sentetik (data/gen/gen_properties.py üretir)
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE properties (
  id              bigserial PRIMARY KEY,
  external_ref    text UNIQUE NOT NULL,           -- 'SYN-000001'
  geom            geometry(Point, 4326) NOT NULL,
  building_id     bigint REFERENCES buildings(id),
  neighborhood_id bigint NOT NULL REFERENCES neighborhoods(id),
  monthly_rent    numeric(10,2) NOT NULL CHECK (monthly_rent > 0),
  deposit         numeric(10,2),
  area_m2         smallint NOT NULL CHECK (area_m2 > 0),
  room_count      text     NOT NULL,              -- '1+0' … '4+1'
  floor_no        smallint,
  total_floors    smallint,
  building_age    smallint,
  has_elevator    boolean NOT NULL DEFAULT false,
  has_parking     boolean NOT NULL DEFAULT false,
  is_furnished    boolean NOT NULL DEFAULT false,
  pets_allowed    boolean NOT NULL DEFAULT false,
  rent_per_m2     numeric(8,2) GENERATED ALWAYS AS
                    (monthly_rent / NULLIF(area_m2, 0)) STORED,

  -- Dürüstlük kuralı: veri sentetiktir ve UI'da her yerde rozetlenir.
  is_synthetic    boolean NOT NULL DEFAULT true,
  data_version    text NOT NULL
);
CREATE INDEX idx_prop_geom   ON properties USING GIST (geom);
CREATE INDEX idx_prop_filter ON properties (monthly_rent, area_m2, room_count);


-- ══════════════════════════════════════════════════════════════════════
--  6. ERİŞİM MATRİSİ — precompute, ETL'de bir kez doldurulur
--
--  PK (property_id, category_code): kategori başına YALNIZCA en yakın POI
--  saklanır. Skorlama zaten en yakını kullanır; hepsini tutmak 60.000 yerine
--  milyonlarca satır demek olurdu.
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE property_poi_access (
  property_id   bigint NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  category_code text   NOT NULL REFERENCES poi_categories(code),
  poi_id        bigint NOT NULL REFERENCES pois(id),
  duration_min  numeric(5,1) NOT NULL,     -- OSRM foot profili — YÜRÜME süresi
  distance_m    integer      NOT NULL,
  data_version  text         NOT NULL,
  PRIMARY KEY (property_id, category_code)
);
-- BRIN yeterli: tablo property_id sırasıyla toplu yazılır, güncellenmez.
CREATE INDEX idx_ppa_prop ON property_poi_access USING BRIN (property_id);


-- ══════════════════════════════════════════════════════════════════════
--  7. SKOR CACHE
--
--  scoring_version PK'nın parçası: formül değişince eski satırlar
--  otomatik olarak "başka bir sürüm" olur, yanlışlıkla okunmaz.
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE score_cache (
  property_id     bigint NOT NULL REFERENCES properties(id)     ON DELETE CASCADE,
  profile_id      uuid   NOT NULL REFERENCES user_profiles(id)  ON DELETE CASCADE,
  scoring_version text   NOT NULL,
  total_score     numeric(5,2) NOT NULL CHECK (total_score BETWEEN 0 AND 100),
  breakdown       jsonb  NOT NULL,          -- gerekçe tablosu satırları (W6)
  computed_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (property_id, profile_id, scoring_version)
);
CREATE INDEX idx_score_profile ON score_cache (profile_id, scoring_version);


-- ══════════════════════════════════════════════════════════════════════
--  8. ZİYARET ROTALARI (W7 / M2 / M3 / M4)
-- ══════════════════════════════════════════════════════════════════════
CREATE TABLE routes (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name             text NOT NULL,
  start_geom       geometry(Point, 4326) NOT NULL,
  start_label      text,
  mode             text NOT NULL DEFAULT 'car' CHECK (mode IN ('foot','car')),
  total_distance_m integer NOT NULL,
  total_duration_s integer NOT NULL,
  geometry         geometry(LineString, 4326) NOT NULL,  -- tam rota çizgisi
  steps            jsonb   NOT NULL,        -- OSRM manevra adımları (bacak bazlı)
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_route_user ON routes (user_id, created_at DESC);

CREATE TABLE route_stops (
  route_id       uuid     NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
  seq            smallint NOT NULL CHECK (seq BETWEEN 1 AND 8),  -- Held-Karp sınırı
  property_id    bigint   NOT NULL REFERENCES properties(id),
  score_snapshot numeric(5,2),              -- rota kurulduğu andaki skor
  leg_distance_m integer,                   -- önceki duraktan bu durağa
  leg_duration_s integer,
  visited_at     timestamptz,               -- mobilde "ziyaret ettim" (M5)
  PRIMARY KEY (route_id, seq),

  -- Aynı ev bir rotaya iki kez eklenmesin (TSP çıktısı zaten permütasyondur).
  UNIQUE (route_id, property_id)
);
