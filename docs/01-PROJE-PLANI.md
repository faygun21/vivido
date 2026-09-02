# Vivido — Kiralık Ev Bulma, Skorlama ve Ziyaret Rotası
### Web + Mobil · Başarsoft Stajyer Projesi · Daraltılmış Uygulama Planı

---

## 1. Context — Neden yeniden planlıyoruz?

İlk plan (isochrone, günlük yaşam senaryoları, 8 domain, konut karşılaştırma, zaman avantajı, kaydedilmiş aramalar) stajyer ekip için fazla kapsamlıydı. Ekip kapsamı **gerçekten teslim edilebilir** bir çekirdeğe indirdi ve **bir mobil uygulama** ekledi.

**Yeni ürün tek cümleyle:** Kullanıcı web'de personasını ve düzenli gittiği yerleri girer, sistem ona uygun kiralık evleri skorlayıp gerekçesiyle gösterir, seçtiği evleri gezmek için en kısa rotayı üretir; mobil uygulama bu rotayı navigasyonla yürütür.

**İki uygulama, tek backend, tek veritabanı.** Web karar verme aracı, mobil saha aracıdır.

**Değişen ne:** isochrone, çok modlu ulaşım, toplu taşıma/GTFS, günlük senaryolar, konut karşılaştırma matrisi, zaman avantajı hesabı, kaydedilmiş aramalar — **hepsi kapsam dışı**. Yerine gelen: **anchor öncelik sıralaması**, **bütçe skoru**, **TSP ziyaret rotası**, **mobil navigasyon**.

---

## 2. Kapsam Sözleşmesi

> Bu liste **kapalıdır**. Yeni özellik istekleri `backlog/v2.md`'ye yazılır, sprint'e alınmaz.

### 2.1 Web uygulaması — 7 gereksinim

| # | Gereksinim |
|---|---|
| **W1** | Kullanıcı kaydolur / giriş yapar |
| **W2** | Hazır **persona** listesinden birini seçer (6 arketip) ve aylık **kira bütçesini** girer |
| **W3** | Varsayılan görünüm: personaya göre **uygunluk skoru yüksek kiralık evler** harita + listede |
| **W4** | Kullanıcı **düzenli gittiği yerleri (anchor)** ekler ve **önem sırasına dizer**; skor bu sıraya göre yeniden hesaplanır |
| **W5** | Her ev için **tek bir 0–100 skor** gösterilir; liste yüksek skorluların yanı sıra **düşük skorluları da içerir** |
| **W6** | Her ev için **skorun gerekçe tablosu**: neden uygun / neden uygun değil, satır satır puan katkısıyla |
| **W7** | Kullanıcı 2–8 ev seçer → sistem **en kısa ziyaret rotasını** üretir (açık TSP) → rota kaydedilir |

### 2.2 Mobil uygulama — 5 gereksinim

| # | Gereksinim |
|---|---|
| **M1** | Giriş yapar (web ile aynı hesap) |
| **M2** | Web'de oluşturulmuş **kayıtlı rotaları** listeler |
| **M3** | Rota seçilir → harita üzerinde **rota çizgisi + numaralı ev durakları** |
| **M4** | **Adım listeli navigasyon**: manevra kartı ("200 m sonra sağa dönün") + canlı GPS takibi + otomatik adım ilerlemesi + rotadan sapma uyarısı |
| **M5** | Her durakta **ev skor kartı** görüntülenir, **"ziyaret ettim"** işaretlenir |

### 2.3 Kapsam dışı (v1'de yapılmayacak)
Isochrone · toplu taşıma / GTFS · bisiklet modu · günlük yaşam senaryoları · konut karşılaştırma matrisi · zaman avantajı · kaydedilmiş aramalar · satılık konut · sesli navigasyon · mobilde arama/filtreleme/rota oluşturma · gerçek ilan verisi · offline çalışma · gerçek zamanlı trafik.

---

## 3. Teknoloji Yığını

| Katman | Seçim | Not |
|---|---|---|
| Backend | **.NET 10 · ASP.NET Core Web API** | Başarsoft'un ana yığını |
| ORM / Geospatial | EF Core 10 + **NetTopologySuite** | `Point`, `LineString` native |
| Veritabanı | **PostgreSQL 16 + PostGIS 3.4** | GiST indeks, `ST_DWithin`, KNN `<->` |
| Cache | ~~Redis 7~~ | ⛔ **KESİLDİ** — 3 haftalık plan skor cache'ini çıkardı. Servis compose'da duruyor, kod kullanmıyor |
| Routing | **OSRM**, 2 profil: `foot` + `car` | `/table` matris · `/route` manevra · `/trip` yedek |
| TSP çözücü | **Held-Karp** (kendi kodumuz, C#) | n ≤ 8 için kesin optimum, <1 ms. Kod tarafında güvenlik payı olarak n ≤ 16'ya kadar çalışıyor, ürün W7 gereği 2-8 ev seçimiyle sınırlı |
| Tile | **Planetiler → mbtiles → tileserver-gl** | Public OSM tile **kullanılmaz** |
| Web | **React 19 + TS + Vite + MapLibre GL JS** | TanStack Query + Zustand. *(Plan React 18 diyordu, gerçek sürüm 19'a çıktı)* |
| Mobil | **Flutter** (`maplibre_gl`, `dio`, `go_router`) | ⚠️ [K-08](02-KARARLAR.md#k-08) ile değişti — Expo/RN terk edildi |
| Paylaşılan kod | `packages/shared` — TS tipleri | Doğruluk kaynağı; Dart modelleri onu **yansıtır** (K-08) |
| Veri | OpenStreetMap (Geofabrik) + **sentetik kiralık konut** | Pilot: Ankara **Çankaya'nın tamamı** |
| Test | xUnit + Testcontainers · Vitest · ~~Playwright~~ | Skorlama için altın veri seti. Testcontainers ve Vitest kullanımda; Playwright **planlandı, henüz kurulmadı**; altın veri seti/`Golden`-`Invariant` testleri de henüz yazılmadı (bkz. [04-MEVCUT-DURUM §8](04-MEVCUT-DURUM.md)) |
| CI | GitHub Actions | 4 workflow. **Deploy otomasyonu henüz yok** |
| Dağıtım | Docker Compose + **Caddy** (otomatik HTTPS), tek sunucu | [K-11](02-KARARLAR.md#k-11) · [`deploy/README.md`](../deploy/README.md) |

---

## 4. Sistem Mimarisi

### 4.1 Karar: tek monolit API, iki istemci

```
                 ┌──────────────────┐        ┌──────────────────┐
                 │   WEB (React)    │        │ MOBİL (Flutter)  │
                 │  ev bul · skorla │        │ rota gez · naviga│
                 │  rota oluştur    │        │  syon            │
                 └────────┬─────────┘        └────────┬─────────┘
                          │      packages/shared      │
                          │  (TS tipleri + client)    │
                          └────────────┬──────────────┘
                                       │ HTTPS · JWT
                          ┌────────────▼──────────────┐
                          │   Vivido.Api (.NET 10)       │
                          │  Auth · Profile · Anchors │
                          │  Properties · Scoring     │
                          │  Routes (TSP + steps)     │
                          └──┬──────────┬─────────┬───┘
                             │          │         │
                  ┌──────────▼──┐  ┌────▼────┐  ┌─▼──────────┐
                  │  PostGIS    │  │  Redis  │  │ OSRM ×2    │
                  │  (tek DB)   │  │ (cache) │  │ foot · car │
                  └─────────────┘  └─────────┘  └────────────┘
                                       ┌────────────────────┐
                                       │ tileserver-gl      │
                                       │ (altlık harita)    │
                                       └────────────────────┘
```

**Neden monolit:** 12 endpoint, tek veritabanı, iki istemci. Mikroservis burada sadece maliyet üretir.

### 4.2 Proje yapısı

```
basarsoft/
├── api/
│   └── src/
│       ├── Vivido.Api/              → Controller, auth, Swagger
│       ├── Vivido.Application/      → Use-case handler, DTO, validation
│       ├── Vivido.Domain/           → Entity
│       ├── Vivido.Infrastructure/   → EF Core, OsrmClient, Redis
│       ├── Vivido.Scoring/          → ★ SAF skorlama motoru (I/O YOK)
│       └── Vivido.RouteOptimization/→ ★ SAF TSP çözücü — Held-Karp (I/O YOK)
├── web/                           → React + Vite
├── mobile/                        → Flutter (K-08)
├── packages/shared/               → TS tipleri + üretilmiş API istemcisi
├── data/
│   ├── scripts/                   → 01_download.sh … 06_seed_db.sh
│   ├── lua/                       → vivido_pois.lua (osm2pgsql flex)
│   └── gen/                       → gen_properties.py
├── db/schema/                     → 001_initial.sql …
└── docker-compose.yml
```

> **Değişmez kural:** `Vivido.Scoring` **hiçbir I/O yapmaz**. Girdi `ScoringInput`, çıktı `ScoreResult`. Bu sayede skorlama motoru veritabanı olmadan, milisaniyelerde, yüzlerce vaka ile test edilebilir.
>
> Aynı kural `Vivido.RouteOptimization` için de geçerli (2026-08-28'de `Vivido.Scoring`'ten ayrıldı — rota sıralama konut skorlamasıyla ilgisiz bir alan, aynı projede durması "SAF SKORLAMA motoru" tanımını bulanıklaştırıyordu).

### 4.3 Docker Compose servisleri

| Servis | Port | Not |
|---|---|---|
| `postgis` | 5432 | postgis/postgis:16-3.4 |
| `redis` | 6379 | Compose'da duruyor ama **hiç devreye alınmadı** — 3 haftalık plan skor cache'ini Redis'ten çıkardı (bkz. §3, [04-MEVCUT-DURUM §8](04-MEVCUT-DURUM.md)) |
| `api` | 5000 | .NET 10 |
| `web` | 5173 | Vite dev server |
| `osrm-foot` | 5001 | `--algorithm mld` |
| `osrm-car` | 5002 | `--algorithm mld` |
| `tileserver` | 8080 | tileserver-gl + `cankaya.mbtiles` |
| `pgadmin` | 5050 | `--profile dev` |

---

## 5. Veri Modeli (PostGIS)

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- ═══ KULLANICI & PROFİL ═══
CREATE TABLE users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         citext UNIQUE NOT NULL,
  password_hash text NOT NULL,
  display_name  text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE personas (                   -- 6 sabit arketip (seed)
  code            text PRIMARY KEY,       -- 'student' | 'family_kids' | …
  display_name_tr text NOT NULL,
  description_tr  text NOT NULL,
  icon            text
);

CREATE TABLE persona_category_weights (   -- ★ 6 persona × 10 kategori
  persona_code  text NOT NULL REFERENCES personas(code),
  category_code text NOT NULL REFERENCES poi_categories(code),
  weight        numeric(4,3) NOT NULL CHECK (weight BETWEEN 0 AND 1),
  PRIMARY KEY (persona_code, category_code)
);
-- Kural: her persona için SUM(weight) = 1.000 (DQ kuralı ile doğrulanır)

CREATE TABLE user_profiles (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  persona_code  text NOT NULL REFERENCES personas(code),
  monthly_budget numeric(10,2),           -- NULL ise bütçe skoru devre dışı
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id)                        -- v1: kullanıcı başına tek profil
);

-- ★ ANCHOR — ÖNCELİK SIRASI BURADA
CREATE TABLE anchors (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id  uuid NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  label       text NOT NULL,              -- 'Hacettepe Beytepe'
  geom        geometry(Point, 4326) NOT NULL,
  mode        text NOT NULL DEFAULT 'car' CHECK (mode IN ('foot','car')),
  priority    smallint NOT NULL CHECK (priority BETWEEN 1 AND 5),
  created_at  timestamptz NOT NULL DEFAULT now()
);
-- Sıralama yeniden düzenlenirken geçici çakışmaya izin ver:
ALTER TABLE anchors ADD CONSTRAINT uq_anchor_priority
  UNIQUE (profile_id, priority) DEFERRABLE INITIALLY DEFERRED;
CREATE INDEX idx_anchor_geom ON anchors USING GIST (geom);

-- ═══ POI ═══
CREATE TABLE poi_categories (             -- ★ SKOR PARAMETRELERİNİN TEK KAYNAĞI
  code            text PRIMARY KEY,
  display_name_tr text NOT NULL,
  t_ideal_min     numeric(4,1) NOT NULL,  -- bu süreye kadar 100 puan
  t_half_min      numeric(4,1) NOT NULL,  -- bu sürede 50 puan
  t_cutoff_min    numeric(4,1) NOT NULL,  -- ötesi 0 puan
  search_radius_m integer NOT NULL DEFAULT 2500,
  min_poi_count   smallint NOT NULL DEFAULT 5,
  active          boolean NOT NULL DEFAULT true
);

CREATE TABLE poi_tag_mapping (            -- OSM tag → kategori
  id            bigserial PRIMARY KEY,
  osm_key       text NOT NULL,
  osm_value     text NOT NULL,
  category_code text NOT NULL REFERENCES poi_categories(code),
  UNIQUE (osm_key, osm_value, category_code)
);

CREATE TABLE pois (
  id            bigserial PRIMARY KEY,
  osm_id        bigint,
  osm_type      char(1),
  name          text,
  category_code text NOT NULL REFERENCES poi_categories(code),
  geom          geometry(Point, 4326) NOT NULL,
  data_version  text NOT NULL
);
CREATE INDEX idx_poi_geom ON pois USING GIST (geom);
CREATE INDEX idx_poi_cat  ON pois (category_code);

-- ═══ İDARİ SINIR & BİNA ═══
CREATE TABLE neighborhoods (
  id           bigserial PRIMARY KEY,
  name         text NOT NULL,
  geom         geometry(MultiPolygon, 4326) NOT NULL,
  rent_index   numeric(5,3) NOT NULL DEFAULT 1.000,  -- 1.00 = Çankaya ort.
  data_version text NOT NULL
);
CREATE INDEX idx_nb_geom ON neighborhoods USING GIST (geom);

CREATE TABLE buildings (                  -- sentetik ev üretiminin tabanı
  id           bigserial PRIMARY KEY,
  osm_id       bigint,
  geom         geometry(Polygon, 4326) NOT NULL,
  levels       smallint,
  data_version text NOT NULL
);
CREATE INDEX idx_bld_geom ON buildings USING GIST (geom);

-- ═══ KİRALIK KONUTLAR (sentetik) ═══
CREATE TABLE properties (
  id              bigserial PRIMARY KEY,
  external_ref    text UNIQUE NOT NULL,   -- 'SYN-000001'
  geom            geometry(Point, 4326) NOT NULL,
  building_id     bigint REFERENCES buildings(id),
  neighborhood_id bigint NOT NULL REFERENCES neighborhoods(id),
  monthly_rent    numeric(10,2) NOT NULL,
  deposit         numeric(10,2),
  area_m2         smallint NOT NULL,
  room_count      text NOT NULL,          -- '1+0' … '4+1'
  floor_no        smallint,
  total_floors    smallint,
  building_age    smallint,
  has_elevator    boolean NOT NULL DEFAULT false,
  has_parking     boolean NOT NULL DEFAULT false,
  is_furnished    boolean NOT NULL DEFAULT false,
  pets_allowed    boolean NOT NULL DEFAULT false,
  rent_per_m2     numeric(8,2) GENERATED ALWAYS AS
                    (monthly_rent / NULLIF(area_m2,0)) STORED,
  is_synthetic    boolean NOT NULL DEFAULT true,
  data_version    text NOT NULL
);
CREATE INDEX idx_prop_geom   ON properties USING GIST (geom);
CREATE INDEX idx_prop_filter ON properties (monthly_rent, area_m2, room_count);

-- ═══ ERİŞİM MATRİSİ (precompute — gecelik/tek seferlik) ═══
CREATE TABLE property_poi_access (
  property_id   bigint NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  category_code text   NOT NULL REFERENCES poi_categories(code),
  poi_id        bigint NOT NULL REFERENCES pois(id),
  duration_min  numeric(5,1) NOT NULL,    -- YÜRÜME süresi
  distance_m    integer NOT NULL,
  data_version  text NOT NULL,
  PRIMARY KEY (property_id, category_code)   -- yalnızca EN YAKIN POI saklanır
);
CREATE INDEX idx_ppa_prop ON property_poi_access USING BRIN (property_id);

-- ═══ SKOR CACHE ═══
CREATE TABLE score_cache (
  property_id     bigint NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  profile_id      uuid   NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  scoring_version text   NOT NULL,
  total_score     numeric(5,2) NOT NULL,
  breakdown       jsonb  NOT NULL,        -- gerekçe tablosu satırları
  computed_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (property_id, profile_id, scoring_version)
);

-- ═══ ZİYARET ROTALARI ═══
CREATE TABLE routes (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name          text NOT NULL,
  start_geom    geometry(Point, 4326) NOT NULL,
  start_label   text,
  mode          text NOT NULL DEFAULT 'car',
  total_distance_m integer NOT NULL,
  total_duration_s integer NOT NULL,
  geometry      geometry(LineString, 4326) NOT NULL,   -- tam rota çizgisi
  steps         jsonb NOT NULL,           -- OSRM manevra adımları (bacak bazlı)
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_route_user ON routes (user_id, created_at DESC);

CREATE TABLE route_stops (
  route_id     uuid NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
  seq          smallint NOT NULL,         -- TSP'nin belirlediği sıra, 1..8
  property_id  bigint NOT NULL REFERENCES properties(id),
  score_snapshot numeric(5,2),            -- rota kurulduğu andaki skor
  leg_distance_m integer,                 -- önceki duraktan bu durağa
  leg_duration_s integer,
  visited_at   timestamptz,               -- mobilde "ziyaret ettim"
  PRIMARY KEY (route_id, seq)
);
```

**Tahmini boyutlar:** `pois` ~28.000 / 15 MB · `properties` 6.000 / 3 MB · `property_poi_access` 60.000 / 4 MB · `buildings` ~70.000 / 150 MB · toplam **~250 MB**.

---

## 6. ⭐ Skorlama Algoritması

> Projenin kalbi. `Vivido.Scoring` projesinde, saf ve I/O'suz.

### 6.1 Üst düzey formül

```
Skor = 0.70 × YaşamSkoru + 0.30 × BütçeSkoru          (bütçe girilmişse)
Skor = YaşamSkoru                                      (bütçe girilmemişse)

YaşamSkoru = 0.50 × POISkoru + 0.50 × AnchorSkoru      (anchor varsa)
YaşamSkoru = POISkoru                                   (anchor yoksa → W3 varsayılan görünüm)
```

**50/50 gerekçesi:** POI skoru *"evin çevresi nasıl?"*, anchor skoru *"ev senin hayatına göre nerede?"* sorusunu ölçer. İkisi farklı ve eşit önemde sorulardır. Katsayılar `scoring_params` tablosunda tutulur, kodda sabit değildir.

### 6.2 POI bileşeni

**Adım A — kategori alt skoru (plato + üstel bozunum):**

```
        ┌ 100                                          , t ≤ t_ideal
s_c(t) =┤ 100 · 0.5^((t − t_ideal)/(t_half − t_ideal))  , t_ideal < t < t_cutoff
        └ 0                                            , t ≥ t_cutoff
```

Erişilebilirlik algısı doğrusal değildir: 2 dk ile 4 dk arası hissedilmez, 12 dk ile 20 dk arası ciddidir. Parametreler doğrudan anlamlıdır — *"4 dakikaya kadar tam puan, 10 dakikada yarı puan"* — bu da kalibrasyonu ekip için tartışılabilir kılar.

| Kategori | `t_ideal` | `t_half` | `t_cutoff` |
|---|---|---|---|
| `market` Market / süpermarket | 4 | 10 | 25 |
| `pharmacy` Eczane | 4 | 9 | 22 |
| `transit` Toplu taşıma durağı | 5 | 11 | 25 |
| `food` Kafe & restoran | 5 | 12 | 25 |
| `park` Park & yeşil alan | 5 | 12 | 28 |
| `gym` Spor salonu | 7 | 15 | 35 |
| `school` İlkokul / ortaokul | 6 | 13 | 30 |
| `health` ASM / hastane | 8 | 16 | 35 |
| `bank` Banka / ATM | 6 | 14 | 30 |
| `pet` Veteriner & köpek parkı | 8 | 18 | 40 |

*(Tüm süreler **yürüme**, OSRM `foot` profili.)*

**Adım B — persona ağırlık matrisi** (her satır toplamı 1.000):

| Persona | market | pharmacy | transit | food | park | gym | school | health | bank | pet |
|---|---|---|---|---|---|---|---|---|---|---|
| `student` Öğrenci | 0.14 | 0.06 | **0.22** | 0.20 | 0.07 | 0.11 | 0.00 | 0.05 | 0.10 | 0.05 |
| `family_kids` Çocuklu aile | 0.18 | 0.10 | 0.12 | 0.05 | 0.14 | 0.04 | **0.25** | 0.09 | 0.03 | 0.00 |
| `pet_owner` Evcil hayvan sahibi | 0.16 | 0.08 | 0.12 | 0.12 | **0.20** | 0.05 | 0.00 | 0.05 | 0.02 | **0.20** |
| `elderly` Yaşlı / emekli | **0.22** | **0.22** | 0.14 | 0.05 | 0.12 | 0.02 | 0.00 | 0.18 | 0.05 | 0.00 |
| `remote_worker` Uzaktan çalışan | 0.18 | 0.07 | 0.07 | **0.22** | 0.16 | 0.13 | 0.00 | 0.06 | 0.06 | 0.05 |
| `car_free` Araçsız kullanıcı | 0.20 | 0.10 | **0.30** | 0.12 | 0.08 | 0.05 | 0.00 | 0.08 | 0.07 | 0.00 |

**Adım C — birleştirme: CES, ağırlıklı toplam değil**

> ⚠️ **Bu bölüm orijinal plandır, motorun çalışan hâli değil.** Gerçek
> `ScoringEngine` (v1.1) tam CES yerine daha basit bir **"zayıf halka
> cezası"** çarpanı kullanıyor — aynı amaca (bir kategorinin çok kötü
> olması toplamı telafi edilemez şekilde düşürsün) hizmet ediyor ama
> aşağıdaki `ρ = −0.5` formülüyle birebir aynı değil. Ayrıca motor bir
> **yumuşak tavan** (soft ceiling) ve **yoğunluk bonusu** da uyguluyor,
> ikisi de bu bölümde yok. Güncel davranış ve ölçülmüş etkisi için
> [04-MEVCUT-DURUM §5.14](04-MEVCUT-DURUM.md#514-🟠-skor-motoru-ayrıştırmıyor--medyan-938-listenin-tamamı-100)
> ve kod: `api/src/Vivido.Scoring/ScoringEngine.cs`.

Ağırlıklı toplamın kusuru: *bir kategori sıfır olsa bile toplam iyi çıkabilir.* Metrosu ve otobüsü olmayan bir ev, `car_free` kullanıcısı için marketleri iyi diye 72 alabilir — bu saçmadır.

```
POISkoru = ( Σ_c  w_c · s_c^ρ )^(1/ρ)     ,  ρ = −0.5
s_c alt sınırı = 1  (0 değil — bölme hatası ve tek sıfırın her şeyi öldürmesi engellenir)
```

`ρ = −0.5` **sınırlı ikame** demektir: kategoriler birbirinin yerini kısmen tutar, tamamen tutmaz. Aynı `car_free` örneği CES ile **13.9** verir, 72.3 değil.

> **Kural:** *Altyapı eksikliği telafi edilemez (CES). Kullanıcı tercihi telafi edilebilir (ağırlıklı toplam).* Bu yüzden kategoriler CES ile, anchor'lar ağırlıklı toplamla birleşir.

### 6.3 ⭐ Anchor bileşeni — öncelik sırası nasıl ağırlığa çevrilir?

Kullanıcı anchor'ları 1..n sırasına dizer. Bu sıra ağırlığa dönüşmeli.

**Aday 1 — ters sıra ağırlığı:** `w_i = (n−i+1) / Σ`
**Aday 2 — geometrik azalan:** `w_i = 0.5^(i−1) / Σ`

| n | Ters sıra w₁ | Geometrik w₁ |
|---|---|---|
| 2 | 0.667 | 0.667 |
| 3 | 0.500 | 0.571 |
| 4 | 0.400 | 0.533 |
| 5 | 0.333 | 0.516 |

**Seçim: geometrik.** Ters sırada, listeye **önemsiz bir 5. anchor eklemek 1. anchor'ın ağırlığını 0.667'den 0.333'e yarıya düşürür** — kullanıcının "bu benim en önemli yerim" beyanını bozar. Geometrikte `w₁` her zaman **0.50–0.667** bandında kalır ve şu özdeşlik sağlanır:

```
w₁ ≈ w₂ + w₃ + … + wₙ
"En önemli yer, diğerlerinin toplamı kadar ağırlık taşır."
```

**Anchor mesafe → puan:**

```
a_j = 100 · 0.5^((T_j − T_free)/T_half)   , T_j > T_free
    = 100                                  , T_j ≤ T_free
    = 0                                    , T_j > T_cutoff

mode = car  → T_free = 10 dk,  T_half = 15 dk,  T_cutoff = 60 dk
mode = foot → T_free =  8 dk,  T_half = 12 dk,  T_cutoff = 45 dk

AnchorSkoru = Σ_j  w_j · a_j          (ağırlıklı toplam)
```

**Somut örnek — 3 anchor'lı bir öğrenci:**

| Sıra | Anchor | Mod | Süre | `a_j` | `w_j` | Katkı |
|---|---|---|---|---|---|---|
| 1 | Hacettepe Beytepe | araç | 22 dk | 57.4 | 0.571 | 32.8 |
| 2 | Spor salonu | yürüme | 9 dk | 94.4 | 0.286 | 27.0 |
| 3 | Aile evi | araç | 35 dk | 31.5 | 0.143 | 4.5 |
| | | | | | | **AnchorSkoru = 64.3** |

Kullanıcı sırayı değiştirirse (spor salonunu 1. yaparsa) skor **80.6**'ya çıkar — sıralamanın gerçekten sonucu değiştirdiği burada görülür.

### 6.4 Bütçe bileşeni

`r = aylık_kira / kullanıcı_bütçesi`

```
        ┌ 100                              , r ≤ 0.70
B(r) = ┤ 100 − 40 · (r − 0.70)/0.30       , 0.70 < r ≤ 1.00
        └ 60 · 0.5^((r − 1.00)/0.10)       , r > 1.00
```

| `r` | Anlamı | `B` |
|---|---|---|
| 0.60 | Bütçenin çok altında | 100 |
| 0.85 | Rahat | 80 |
| 1.00 | Tam bütçe sınırı | 60 |
| 1.10 | %10 aşım | 30 |
| 1.20 | %20 aşım | 15 |
| 1.30 | %30 aşım | 7.5 |

**Asimetri kasıtlı:** bütçenin altında kalmak lineer ödüllendirilir, üstüne çıkmak **her %10'da yarılanarak** cezalandırılır. Kira ödenemiyorsa evin ne kadar güzel olduğu önemsizdir.

### 6.5 ⭐ Gerekçe tablosu (W6) — açıklanabilirlik

**Tasarım kuralı: tablodaki tüm katkıların toplamı, gösterilen skora birebir eşit olmalıdır.** CES doğrusal olmadığı için, doğrusal katkılar ile CES sonucu arasındaki fark **açık bir satır** olarak gösterilir. Bu, "toplamı tutmayan tablo" problemini çözer.

**Katkı formülleri:**
```
POI kategorisi katkısı  = 0.70 × 0.50 × w_c × s_c   = 0.35 × w_c × s_c
CES düzeltmesi          = 0.35 × (POISkoru − Σ w_c·s_c)     ← negatif
Anchor katkısı          = 0.35 × w_j × a_j
Bütçe katkısı           = 0.30 × B
Kayıp (neden uygun değil) = maks_katkı − gerçek_katkı
```

**Dolu örnek — Öğrenci personası, Kurtuluş'ta bir daire, bütçe 20.000 ₺, kira 18.500 ₺:**

| Kriter | Ölçülen | Hedef | Alt skor | Ağırlık | **Katkı** | Kayıp | Durum |
|---|---|---|---|---|---|---|---|
| Toplu taşıma durağı | 4.0 dk yürüme | ≤5 dk | 100 | 0.22 | **+7.70** | 0.00 | ✅ Güçlü |
| Kafe & restoran | 3.8 dk | ≤5 dk | 100 | 0.20 | **+7.00** | 0.00 | ✅ Güçlü |
| Market | 3.2 dk | ≤4 dk | 100 | 0.14 | **+4.90** | 0.00 | ✅ Güçlü |
| Banka / ATM | 6.0 dk | ≤6 dk | 100 | 0.10 | **+3.50** | 0.00 | ✅ Güçlü |
| Spor salonu | 11.0 dk | ≤7 dk | 70.7 | 0.11 | +2.72 | 1.13 | ⚠️ Orta |
| Eczane | 5.5 dk | ≤4 dk | 81.2 | 0.06 | +1.71 | 0.39 | ✅ İyi |
| Park & yeşil alan | 14.0 dk | ≤5 dk | 41.0 | 0.07 | +1.00 | 1.45 | ❌ Zayıf |
| ASM / hastane | 19.0 dk | ≤8 dk | 38.6 | 0.05 | +0.68 | 1.07 | ❌ Zayıf |
| Veteriner / köpek parkı | 22.0 dk | ≤8 dk | 37.9 | 0.05 | +0.66 | 1.09 | ❌ Zayıf |
| *CES dengesizlik düzeltmesi* | — | — | — | — | **−2.38** | 2.38 | ⚠️ Dengesiz |
| **① Hacettepe Beytepe** | 22 dk araç | ≤10 dk | 57.4 | 0.571 | **+11.47** | **8.52** | ❌ **En büyük kayıp #2** |
| **② Spor salonu (anchor)** | 9 dk yürüme | ≤8 dk | 94.4 | 0.286 | **+9.45** | 0.56 | ✅ Güçlü |
| **③ Aile evi** | 35 dk araç | ≤10 dk | 31.5 | 0.143 | +1.58 | 3.43 | ❌ Zayıf |
| **Bütçe uyumu** | 18.500 / 20.000 ₺ | ≤%70 | 70.0 | 0.30 | **+21.00** | **9.00** | ⚠️ **En büyük kayıp #1** |
| | | | | | **= 71.0** | **29.0** | |

**UI'da nasıl bölünür:**
- **"Neden uygun"** — katkısı en yüksek 4 satır: Bütçe (+21.0), Hacettepe (+11.5), Spor anchor (+9.5), Toplu taşıma (+7.7)
- **"Neden uygun değil"** — kaybı en yüksek 4 satır: Bütçe (−9.0), Hacettepe (−8.5), Aile evi (−3.4), CES dengesizliği (−2.4)
- Bir satır **her iki listede de** görünebilir (Bütçe gibi) — bu doğrudur: "21 puan kazandırdı ama 9 puan da kaybettirdi."

### 6.6 Sınır durumları

| Durum | Davranış |
|---|---|
| Anchor yok | `YaşamSkoru = POISkoru`; gerekçe tablosunda anchor satırları görünmez; katkılar `0.70 × w_c × s_c` olur |
| Bütçe girilmemiş | `Skor = YaşamSkoru`; bütçe satırı yerine bilgi notu |
| Kategoride hiç POI yok (`t_cutoff` içinde) | `s_c = 0`, satır "❌ Bu kategoride yakında hiç yer yok" olarak gösterilir |
| Kategoride bölgede <5 POI (`min_poi_count`) | Kategori **devre dışı**, ağırlığı diğerlerine oransal dağıtılır, tabloda "veri yetersiz" notu |
| Anchor'a rota bulunamıyor | `a_j = 0` + uyarı; skoru sıfırlamaz |
| Skor aralığı | Her aşamada `clamp(0, 100)`; toplam her zaman `[0, 100]` |

### 6.7 Skor cache ve geçersizleştirme

`score_cache` PK'sı `scoring_version` içerir. Profil, persona, bütçe veya anchor yazan **her** use-case sonunda tek noktadan `IScoreCacheInvalidator.Invalidate(profileId)` çağrılır. İkinci emniyet olarak `anchors` ve `user_profiles` üzerinde DB trigger.

> **Bilinen tuzak:** anchor sıralaması değişti ama liste eski skorları gösteriyor. E2E testi: profil değiştir → liste skoru ile detay skoru **eşit olmalı**.

---

## 7. Rota Optimizasyonu (W7)

### 7.1 Problem
Başlangıç noktası sabit, 2–8 ev, dönüş yok → **açık TSP (open TSP, fixed start)**.

### 7.2 Çözüm: Held-Karp (kesin), OSRM `/trip` yedek

```
1. OSRM /table ile (1 başlangıç + n ev) × (1 + n) süre matrisi al   [car profili]
   GET {osrm-car}/table/v1/driving/{lon,lat};{lon,lat};…?annotations=duration

2. Held-Karp dinamik programlama ile açık TSP'yi KESİN çöz
   Karmaşıklık O(n²·2ⁿ) → n=8 için 64 × 256 = 16.384 işlem → < 1 ms

3. Bulunan sırayla OSRM /route çağır — geometri ve manevralar için
   GET {osrm-car}/route/v1/driving/{sıralı koordinatlar}
       ?steps=true&geometries=geojson&overview=full&annotations=duration,distance

4. routes + route_stops tablolarına yaz
```

**Neden `/trip` değil ana çözüm:** OSRM `/trip` sezgisel (farthest-insertion) çalışır, optimum garanti etmez. `n ≤ 8` için kesin optimum ücretsizdir — "en kısa rota" iddiasını sezgisele bırakmayın. `/trip` yalnızca Held-Karp'ta beklenmedik hata olursa yedek olarak kullanılır:
`{osrm-car}/trip/v1/driving/{coords}?source=first&roundtrip=false`

**Neden maks 8 ev:** (a) Held-Karp 2ⁿ ile büyür — n=12'de 590K işlem, n=15'te 7.4M; (b) bir günde 8 evden fazlası gerçekçi değil; (c) `/table` istek boyutu makul kalır.

### 7.3 Saklanan rota yapısı

```jsonc
{
  "id": "b3f1…", "name": "Cumartesi turu",
  "start": { "lat": 39.9208, "lon": 32.8541, "label": "Kızılay Meydanı" },
  "mode": "car",
  "totalDistanceM": 14280, "totalDurationS": 2160,
  "geometry": { "type": "LineString", "coordinates": [[32.854,39.920], …] },
  "stops": [
    { "seq": 1, "propertyId": 4312, "score": 78.4,
      "legDistanceM": 2100, "legDurationS": 330, "visitedAt": null,
      "property": { "rent": 18500, "areaM2": 95, "roomCount": "2+1",
                    "neighborhood": "Kurtuluş" } }
  ],
  "legs": [
    { "seq": 1, "steps": [
      { "distance": 210, "duration": 34, "name": "Atatürk Bulvarı",
        "maneuver": { "type": "turn", "modifier": "right",
                      "location": [32.8551, 39.9195] },
        "geometry": { "type": "LineString", "coordinates": [ … ] } }
    ]}
  ]
}
```

Mobil uygulama **yalnızca bu payload'ı** tüketir; navigasyon için ikinci bir API çağrısına ihtiyaç duymaz.

---

## 8. Mobil Navigasyon Tasarımı (M4)

### 8.1 OSRM manevra → Türkçe metin

| `type` | `modifier` | Türkçe metin |
|---|---|---|
| `depart` | — | "Yola çıkın" |
| `turn` | `left` / `right` | "Sola / Sağa dönün" |
| `turn` | `slight left` / `slight right` | "Hafif sola / sağa dönün" |
| `turn` | `sharp left` / `sharp right` | "Keskin sola / sağa dönün" |
| `turn` | `straight` | "Düz devam edin" |
| `new name` | * | "{yol adı} üzerinde devam edin" |
| `continue` | * | "Devam edin" |
| `merge` | `left` / `right` | "Soldan / sağdan katılın" |
| `on ramp` | * | "Bağlantı yoluna girin" |
| `off ramp` | * | "Çıkışı kullanın" |
| `fork` | `left` / `right` | "Yol ayrımında sola / sağa" |
| `end of road` | `left` / `right` | "Yol sonunda sola / sağa dönün" |
| `roundabout` | `exit: N` | "Göbekten {N}. çıkışı kullanın" |
| `rotary` | `exit: N` | "Meydandan {N}. çıkışı kullanın" |
| `arrive` | — | "Hedefe ulaştınız" |

Eşleme `mobile/src/navigation/maneuverText.ts` içinde **saf fonksiyon**; bilinmeyen kombinasyon için güvenli varsayılan `"Devam edin"`.

### 8.2 Adım durum makinesi

`mobile/src/navigation/stepMachine.ts` — **saf, I/O'suz, test edilebilir**:

```
Girdi:  { steps[], routeLine, currentPosition, currentStepIndex }
Çıktı:  { activeStepIndex, distanceToManeuverM, offRoute, arrivedAtStop }

Kurallar:
1. Kullanıcı konumu rota çizgisine izdüşürülür (nearest point on line).
2. Aktif adımın manevra noktasına kalan mesafe hesaplanır.
3. Kalan mesafe < 15 m → bir sonraki adıma geç.
4. Rota çizgisine dik mesafe > 50 m ve bu 3 ardışık konum güncellemesinde
   sürüyorsa → offRoute = true (tek seferlik GPS sıçraması sayılmaz).
5. Durak noktasına mesafe < 30 m → arrivedAtStop = true (ziyaret onayı sor).
```

Saf olduğu için CI'da **kaydedilmiş GPS iz fixture'ları** ile test edilir — telefon gerekmez.

### 8.3 Konum takibi

```ts
Location.watchPositionAsync({
  accuracy: Location.Accuracy.High,   // ~10 m; Highest pili hızlı tüketir
  distanceInterval: 10,               // her 10 m'de bir güncelleme
  timeInterval: 3000                  // en fazla 3 sn'de bir
}, onPositionUpdate)
```

- İzin: `expo-location` **foreground** izni yeterli — arka plan konumu **kapsam dışı** (ek izin, store incelemesi ve pil maliyeti getirir).
- Ekran açık kalsın: `expo-keep-awake`.
- Pil notu: `Accuracy.High` + 10 m aralık ≈ saatte %8–12 pil. Navigasyon ekranından çıkınca `watchPosition` **mutlaka** durdurulur (`useEffect` cleanup) — en sık yapılan hata budur.

### 8.4 Mobil ekran akışı

```
[Giriş]
   └→ [Rota Listesi]          rotalar: ad, tarih, ev sayısı, toplam süre
        └→ [Rota Detayı]      harita + rota çizgisi + numaralı 1..n durak
             │                 alt sheet: sıralı ev listesi (skor rozeti ile)
             ├→ [Ev Kartı]    skor + gerekçe tablosu özeti + "ziyaret ettim"
             └→ [Navigasyon]  üst kart: manevra ikonu + metin + kalan mesafe
                              harita: kullanıcı konumu + rota + sıradaki durak
                              alt: kalan süre/mesafe + "sonraki adım" listesi
                              rotadan sapınca: kırmızı bant + "Rotayı yeniden hesapla"
```

---

## 9. ⭐ Veri Elde Etme Rehberi

> Bu bölüm ekibin en çok ihtiyaç duyacağı kısımdır: **ne gerekli, nereden, nasıl.**

### 9.0 Çankaya sınırı

Çankaya kaba bbox (W,S,E,N): **`32.70, 39.70, 33.00, 39.95`**
Kesin sınır için OSM ilçe relation'ı kullanılmalıdır. Relation ID'yi **kendiniz bulun** (sabit kabul etmeyin, değişebilir):

```bash
curl "https://nominatim.openstreetmap.org/search?q=Çankaya,Ankara&format=json&polygon_geojson=1&limit=3"
# Sonuçtaki osm_type=relation ve osm_id değerini not edin.
# Poligonu doğrudan GeoJSON olarak da alabilirsiniz:
curl "https://polygons.openstreetmap.fr/get_geojson.py?id=<RELATION_ID>&params=0" -o cankaya.geojson
```

### 9.1 (a) OSM ham verisi

| Ne | Nereden | Nasıl |
|---|---|---|
| Türkiye OSM ekstresi | `https://download.geofabrik.de/europe/turkey-latest.osm.pbf` (~1.3 GB) | `wget` / `curl -O` |
| Çankaya kesiti (~35 MB) | — | `osmium extract` |

```bash
wget https://download.geofabrik.de/europe/turkey-latest.osm.pbf

# Hızlı: bbox ile
osmium extract -b 32.70,39.70,33.00,39.95 turkey-latest.osm.pbf -o cankaya.osm.pbf

# Kesin: ilçe poligonu ile (tercih edilen)
osmium extract -p cankaya.geojson turkey-latest.osm.pbf -o cankaya.osm.pbf

osmium fileinfo -e cankaya.osm.pbf     # doğrulama: node/way/relation sayıları
```

**Güncellik:** Geofabrik günlük yenilenir. **Projede tek bir tarih dondurun** (`data_version = 'osm-2026-08-20'`) — veri ortasında değiştirmek tüm skorları kaydırır ve altın veri setini bozar.

### 9.2 (b) Yol ağı → OSRM (2 profil)

```bash
# Profil lua dosyaları OSRM imajının içinde gelir: /opt/foot.lua, /opt/car.lua
# Her profil AYRI klasörde build edilmelidir — aynı klasörde ezerler.

mkdir -p osrm/foot osrm/car
cp cankaya.osm.pbf osrm/foot/ && cp cankaya.osm.pbf osrm/car/

docker run -t -v "$PWD/osrm/foot:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-extract -p /opt/foot.lua /data/cankaya.osm.pbf
docker run -t -v "$PWD/osrm/foot:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-partition /data/cankaya.osrm
docker run -t -v "$PWD/osrm/foot:/data" ghcr.io/project-osrm/osrm-backend \
  osrm-customize /data/cankaya.osrm
# car için aynısını /opt/car.lua ile tekrarla
```

| | Çıktı boyutu | Build RAM | Çalışma RAM |
|---|---|---|---|
| `foot` | ~180 MB | ~2 GB | ~400 MB |
| `car` | ~150 MB | ~2 GB | ~350 MB |

Sunarken: `osrm-routed --algorithm mld --max-table-size 200 /data/cankaya.osrm`

### 9.3 (c) POI verisi

**Yöntem 1 — osm2pgsql flex (toplu, tercih edilen):** `data/lua/vivido_pois.lua` ile filtrelenir.

```bash
osm2pgsql -O flex -S data/lua/vivido_pois.lua \
  -d vivido -U vivido -H localhost cankaya.osm.pbf
```

**OSM tag → kategori eşleme tablosu** (`poi_tag_mapping` seed'i):

| OSM tag | Kategori |
|---|---|
| `shop=supermarket`, `shop=convenience`, `shop=greengrocer`, `shop=butcher` | `market` |
| `amenity=pharmacy` | `pharmacy` |
| `highway=bus_stop`, `railway=station`+`station=subway`, `railway=tram_stop`, `amenity=bus_station` | `transit` |
| `amenity=cafe`, `amenity=restaurant`, `amenity=fast_food`, `shop=bakery` | `food` |
| `leisure=park`, `leisure=garden`, `landuse=recreation_ground`, `leisure=playground` | `park` |
| `leisure=fitness_centre`, `leisure=sports_centre`, `leisure=pitch`, `leisure=swimming_pool` | `gym` |
| `amenity=school`, `amenity=kindergarten` | `school` |
| `amenity=hospital`, `amenity=clinic`, `amenity=doctors` | `health` |
| `amenity=bank`, `amenity=atm` | `bank` |
| `amenity=veterinary`, `leisure=dog_park`, `shop=pet` | `pet` |

**Yöntem 2 — Overpass API (nokta kontrol / hızlı doğrulama):**

```
[out:json][timeout:180];
area["name"="Çankaya"]["admin_level"="6"]->.a;
(
  node(area.a)["shop"="supermarket"];
  way(area.a)["shop"="supermarket"];
  node(area.a)["amenity"="pharmacy"];
);
out center;
```
Endpoint: `https://overpass-api.de/api/interpreter` (POST, `data=` gövdesinde).
⚠️ Overpass **kotalıdır** — toplu üretim için değil, doğrulama için kullanın.

### 9.4 (d) İdari sınırlar / mahalleler

OSM'de Türkiye için `boundary=administrative` + `admin_level`:

| `admin_level` | Türkiye karşılığı |
|---|---|
| 2 | Ülke |
| 4 | İl |
| **6** | **İlçe (Çankaya)** |
| 8 | Belediye / belde |
| 10 | Mahalle *(kapsama tutarsız)* |

Mahalle verisi OSM'de her yerde tam değildir. **Yedek plan:** `place=neighbourhood` / `place=suburb` node'larını çekip Voronoi ile yaklaşık mahalle poligonu üretin (`ST_VoronoiPolygons`), ilçe sınırıyla kırpın. Kira endeksi için bu yeterlidir.

```sql
-- Voronoi ile yaklaşık mahalle poligonları
SELECT (ST_Dump(ST_VoronoiPolygons(ST_Collect(geom)))).geom
FROM place_nodes WHERE place IN ('neighbourhood','suburb');
```

### 9.5 (e) Bina poligonları

`osm2pgsql` ile `building=*` etiketli way/relation'lar `buildings` tablosuna. Çankaya'da ~70.000 bina beklenir. Konut amaçlı filtre:
`building IN ('residential','apartments','house','yes','detached','dormitory')`

### 9.6 (f) ⭐ Sentetik kiralık konut verisi

**Hedef: 6.000 kayıt.** Neden bu sayı: haritada anlamlı yoğunluk verir, skor çeşitliliği için yeterlidir, ETL 2 dakikada biter, geliştirme döngüsü hızlı kalır.

**Üretim algoritması (`data/gen/gen_properties.py`, deterministik `SEED=20260817`):**

```
1. buildings'ten konut amaçlı poligonları seç
2. Her bina için daire sayısı:  n = clamp(round(levels × 2.5), 1, 30)
   levels boşsa  →  n = 4
3. Bina içinde nokta üret: ST_GeneratePoints(geom, n)
   → hiçbir konut bina dışında olamaz (DQ-01 ile zorunlu)
4. 6.000'e ulaşana kadar mahalle yoğunluğuna göre örnekle
5. Nitelikler:
   area_m2     ~ Lognormal(μ=4.55, σ=0.30) → medyan ~95 m², [35, 250] kırp
   room_count  ← alana koşullu: <50→1+0, 50-75→1+1, 75-110→2+1,
                                110-150→3+1, >150→4+1
   building_age~ Gamma(k=2, θ=8), [0, 55]
   total_floors~ binadan (levels) veya Uniform(3, 12)
   floor_no    ~ Uniform(0, total_floors)
   has_elevator← total_floors ≥ 5 ise %85, değilse %15
   pets_allowed~ Bernoulli(0.35)
6. Kira modeli:
   ln(rent_m2) = β0 + β1·ln(area) + β2·age + β3·elevator + β4·parking
                 + β5·furnished + ln(neighborhood_rent_index) + ε
   ε ~ N(0, 0.14)
   monthly_rent = rent_m2 × area_m2, en yakın 250 ₺'ye yuvarla
   deposit = monthly_rent × Uniform(1, 2)
```

**Kalibrasyon — kira gerçekçiliği nereden:**

| Kaynak | Ne verir | URL |
|---|---|---|
| TÜİK Konut Fiyat Endeksi | İl bazında fiyat seviyesi ve trend | `data.tuik.gov.tr` |
| TÜFE — "Konut kirası" alt kalemi | Kira seviyesi ve yıllık artış | `data.tuik.gov.tr` |
| TCMB EVDS | Konut fiyat endeksi zaman serisi | `evds2.tcmb.gov.tr` |
| Emlak platformlarının **kamuya açık mahalle ortalama sayfaları** | Mahalle bazlı ₺/m² referansı | Yalnızca **okuyup not alın** |

⚠️ **İlan scrape etmeyin.** Kullanım şartları ihlali ve staj projesinde gereksiz risk. Yalnızca kamuya açık **özet istatistikleri** referans alın; `β0` sabitini bunlarla ±%15 içinde kalibre edin.

**Dürüstlük kuralı:** `properties.is_synthetic = true` ve web + mobilde her yerde **"Sentetik veri"** rozeti. Bu, "veriniz gerçek değil" eleştirisini baştan keser.

### 9.7 (g) Harita tile'ları

```bash
# Planetiler (Java 21 gerekli)
wget https://github.com/onthegomap/planetiler/releases/latest/download/planetiler.jar
java -Xmx4g -jar planetiler.jar \
  --osm-path=cankaya.osm.pbf \
  --output=cankaya.mbtiles \
  --force
# Çıktı: ~120 MB, süre ~3-6 dk

# Sunma
docker run -p 8080:8080 -v "$PWD:/data" maptiler/tileserver-gl \
  --mbtiles cankaya.mbtiles
```

**Stil dosyası:** açık kaynak OSM Bright / Positron stilleri (`github.com/openmaptiles/*-gl-style`). Stil JSON'daki tile URL'sini kendi `tileserver`'ınıza çevirin.

### 9.8 (h) Erişim matrisi (precompute)

```
Her konut × 10 kategori için EN YAKIN POI'nin yürüme süresi:
1. PostGIS ön-eleme: KNN ile kategori başına en yakın 5 aday
   ORDER BY pois.geom <-> p.geom LIMIT 5
2. OSRM /table (foot) ile bu 5 adayın gerçek yürüme süreleri
3. En küçüğü property_poi_access'e yaz
Toplam: 6.000 × 10 = 60.000 satır, ~90 saniye
```

### 9.9 (i) Veri kalitesi kontrolleri

```sql
-- DQ-01: Her konut kendi binasının içinde mi? (beklenen: 0)
SELECT count(*) FROM properties p JOIN buildings b ON p.building_id = b.id
WHERE NOT ST_Within(p.geom, b.geom);

-- DQ-02: Her aktif kategoride yeterli POI var mı? (beklenen: boş)
SELECT c.code, count(p.id) FROM poi_categories c
LEFT JOIN pois p ON p.category_code = c.code
WHERE c.active GROUP BY c.code, c.min_poi_count
HAVING count(p.id) < c.min_poi_count;

-- DQ-03: Persona ağırlıkları 1.000 topluyor mu? (beklenen: boş)
SELECT persona_code, ROUND(SUM(weight),3) FROM persona_category_weights
GROUP BY persona_code HAVING ROUND(SUM(weight),3) <> 1.000;

-- DQ-04: Erişim matrisi tam mı? (beklenen: 60000)
SELECT count(*) FROM property_poi_access;

-- DQ-05: Kira dağılımı makul mü? (₺/m² çeyreklikleri gözle kontrol)
SELECT percentile_cont(ARRAY[0.1,0.25,0.5,0.75,0.9])
       WITHIN GROUP (ORDER BY rent_per_m2) FROM properties;

-- DQ-06: Anchor öncelikleri 1..n kesintisiz mi? (beklenen: boş)
SELECT profile_id FROM anchors GROUP BY profile_id
HAVING max(priority) <> count(*);
```

`severity=error` (DQ-01, 02, 03, 06) başarısızsa **ETL durur**, veri yayınlanmaz.

### 9.10 (j) Lisans ve atıf

OSM verisi **ODbL 1.0** lisanslıdır. Yükümlülükler:
- Haritanın üzerinde **görünür atıf**: `© OpenStreetMap katkıcıları`
- Türetilmiş veritabanı (bizim `pois`, `buildings`, `neighborhoods`) dağıtılırsa ODbL ile paylaşılmalıdır
- Sentetik konut verisi bizim ürünümüzdür, ODbL kapsamında değildir — ama bina geometrisinden türetildiği için **ODbL'e tabi türev** sayılabilir; iç proje olduğu sürece sorun yok, dağıtılacaksa lisansı belirtin
- Web'de MapLibre `attributionControl`, mobilde harita köşesinde sabit atıf metni

---

## 10. API Tasarımı

`/api/v1` · JSON · JWT Bearer · hata formatı **RFC 7807 problem+json**

| Metot | Path | Ne yapar | Web | Mobil |
|---|---|---|---|---|
| POST | `/auth/register` | Kayıt | ✔ | — |
| POST | `/auth/login` | Giriş → access + refresh | ✔ | ✔ |
| POST | `/auth/refresh` | Token yenileme | ✔ | ✔ |
| GET | `/personas` | 6 arketip + açıklamaları | ✔ | — |
| GET | `/profile` | Aktif profil (persona + bütçe) | ✔ | ✔ |
| PUT | `/profile` | Persona ve bütçe güncelle | ✔ | — |
| GET | `/profile/anchors` | Anchor listesi (öncelik sıralı) | ✔ | — |
| POST | `/profile/anchors` | Anchor ekle | ✔ | — |
| DELETE | `/profile/anchors/{id}` | Anchor sil | ✔ | — |
| **PUT** | **`/profile/anchors/order`** | **Öncelik sırasını topluca güncelle** | ✔ | — |
| **GET** | **`/properties`** | Skorlanmış kiralık ev arama (bbox + filtre + sayfalama) | ✔ | — |
| **GET** | **`/properties/{id}/score`** | Skor + **gerekçe tablosu** | ✔ | ✔ |
| **POST** | **`/routes`** | 2–8 ev + başlangıç → TSP + rota üret & kaydet | ✔ | — |
| **GET** | **`/routes`** | Kullanıcının kayıtlı rotaları | ✔ | ✔ |
| **GET** | **`/routes/{id}`** | Rota detayı (geometri + adımlar + duraklar) | ✔ | ✔ |
| DELETE | `/routes/{id}` | Rota sil | ✔ | ✔ |
| **PATCH** | **`/routes/{id}/stops/{seq}`** | `visited: true` işaretle | — | ✔ |
| GET | `/health/ready` | Sağlık (DB, OSRM, tileserver) | — | — |

**Anchor sıralama (W4'ün kalbi):**
```jsonc
PUT /api/v1/profile/anchors/order
{ "order": ["a3f…", "b71…", "c92…"] }   // dizideki index+1 = priority
// → DEFERRABLE constraint sayesinde tek transaction'da güvenle yazılır
// → yanıt sonrası score_cache profil bazında invalidate edilir
```

**Ev arama:**
```
GET /api/v1/properties?bbox=32.80,39.86,32.90,39.93
    &minRent=10000&maxRent=25000&roomCount=2%2B1,3%2B1
    &sort=score_desc&includeLowScores=true&page=1&limit=30
```
```jsonc
{
  "items": [{
    "id": 4312, "lat": 39.8891, "lon": 32.8543,
    "monthlyRent": 18500, "areaM2": 95, "roomCount": "2+1",
    "neighborhood": "Kurtuluş", "isSynthetic": true,
    "score": { "total": 71.0, "band": "good",
               "topStrength": "Toplu taşıma 4 dk",
               "topWeakness": "Bütçenin %93'ü" }
  }],
  "page": 1, "totalPages": 12, "totalCount": 347,
  "scoreDistribution": { "excellent": 24, "good": 118, "fair": 145, "poor": 60 }
}
```

**Gerekçe tablosu yanıtı** — §6.5'teki tablonun satırları:
```jsonc
GET /api/v1/properties/4312/score
{
  "propertyId": 4312, "total": 71.0, "band": "good",
  "rows": [
    { "kind": "poi", "code": "transit", "label": "Toplu taşıma durağı",
      "measured": "4.0 dk yürüme", "target": "≤5 dk",
      "subScore": 100, "weight": 0.22,
      "contribution": 7.70, "loss": 0.00, "status": "strong" },
    { "kind": "ces_adjustment", "label": "Dengesizlik düzeltmesi",
      "contribution": -2.38, "loss": 2.38, "status": "warning" },
    { "kind": "anchor", "priority": 1, "label": "Hacettepe Beytepe",
      "measured": "22 dk araç", "target": "≤10 dk",
      "subScore": 57.4, "weight": 0.571,
      "contribution": 11.47, "loss": 8.52, "status": "weak" },
    { "kind": "budget", "label": "Bütçe uyumu",
      "measured": "18.500 / 20.000 ₺", "target": "≤%70",
      "subScore": 70.0, "weight": 0.30,
      "contribution": 21.00, "loss": 9.00, "status": "warning" }
  ],
  "strengths": ["budget", "anchor:1", "anchor:2", "transit"],
  "weaknesses": ["budget", "anchor:1", "anchor:3", "ces_adjustment"],
  "scoringVersion": "1.0.0"
}
```
> **Değişmezlik:** `Σ rows[].contribution == total` (±0.05). Bu bir birim testidir.

---

## 11. Web UI Tasarımı

### 11.1 Sayfalar

> ⚠️ **Aşağıdaki tablo orijinal plandır.** Gerçek uygulama (`web/src/app/router.tsx`)
> farklı bir yapıya evrildi: ayrı bir landing sayfası yok (`/` doğrudan
> `/auth/login`'e yönleniyor), onboarding tek sayfa değil `/lifestyle` →
> `/preferences` → `/budget` → `/onboarding` şeklinde ayrı rotalara bölündü,
> ve **ev detayı ile rota oluşturma ayrı sayfa değil** — `PropertyDetailPanel`
> ve `RouteBuilderPanel` olarak `/explore` içine panel şeklinde gömüldü.
> Plandan sonra eklenen, bu tabloda hiç olmayan iki sayfa da var: `/favorites`
> ve `/admin`. Gerçek route listesi:
>
> | Gerçek route | Karşılığı |
> |---|---|
> | `/auth/login`, `/auth/register`, `/auth/verify-email`, `/auth/forgot-password` | Kimlik doğrulama |
> | `/lifestyle`, `/preferences`, `/budget`, `/onboarding` | Persona/kriter/bütçe akışı (plandaki tek `/onboarding` yerine 4 ayrı adım) |
> | `/explore` | Ana ekran — harita + liste + **ev detayı + rota oluşturma panelleri de burada** |
> | `/favorites` | Favoriler (plan dışı eklendi) |
> | `/profile` | Persona, bütçe, anchor yönetimi |
> | `/admin` | Yönetim ekranı (plan dışı eklendi) |

Orijinal plan tablosu (referans için korunuyor):

| Route | Sayfa |
|---|---|
| `/` | Landing — kısa tanıtım + "Başla" |
| `/auth/login`, `/auth/register` | Giriş / kayıt |
| `/onboarding` | 3 adım: **persona seç** → **bütçe gir** → **anchor ekle & sırala** |
| `/explore` | **Ana ekran** — harita + skorlanmış ev listesi + filtreler |
| `/property/:id` | Ev detayı + **gerekçe tablosu** |
| `/route/new` | Seçili evler + başlangıç noktası → rota önizleme → kaydet |
| `/routes` | Kayıtlı rotalar |
| `/profile` | Persona, bütçe, anchor yönetimi |

### 11.2 Ana ekran (`/explore`) layout

```
┌──────────────────────────────────────────────────────────────┐
│ Vivido   [Persona: Öğrenci ▾]  Bütçe: 20.000 ₺   [Profil] [Çıkış]│
├────────────────┬─────────────────────────────────────────────┤
│ FİLTRELER      │                                             │
│ Kira: ──●───── │                MapLibre haritası            │
│ m²:   ──●───── │       skor bandına göre renkli noktalar     │
│ Oda: [2+1][3+1]│       ● 85+  ● 70-84  ● 55-69  ● <55        │
│                │                                             │
│ ANCHOR'LAR ⇅   │      seçili evler → numaralı pin            │
│ ①Hacettepe  ✕  │                                             │
│ ②Spor salonu✕  ├─────────────────────────────────────────────┤
│ ③Aile evi   ✕  │  SONUÇLAR (347)      [Skor ▾] [Kira] [m²]   │
│ [+ Yer ekle]   │  ┌───────────────────────────────────────┐  │
│                │  │ 78 │ Kurtuluş · 2+1 · 95 m²           │  │
│ ☑ Düşük skorlu │  │ ●● │ 18.500 ₺   ✓ Metro 4dk           │  │
│   evleri göster│  │    │            ✗ Bütçenin %93'ü  [+] │  │
│                │  └───────────────────────────────────────┘  │
│ SEÇİLENLER (3) │  … (sonsuz kaydırma / sayfalama)            │
│ [Rota Oluştur] │                                             │
└────────────────┴─────────────────────────────────────────────┘
```

**Anchor paneli (W4):** sürükle-bırak ile sıralanır (`dnd-kit`). Sıra bırakıldığı anda `PUT /profile/anchors/order` çağrılır.

> ⚠️ **Planla gerçek davranış burada ayrıştı.** Bu satır aslen "sıra
> değişince tüm liste skorları yeniden hesaplanır" diyordu — **W4'ün
> tanımı da bu**. Ama motor anchor'ları hâlâ skor formülüne almıyor
> (bkz. §9 uyarı kutusu, [04-MEVCUT-DURUM §4.2](04-MEVCUT-DURUM.md)).
> `PUT /profile/anchors/order` bunun yerine **anchor koridoru** cache'ini
> geçersiz kılıyor — yani sıra değişince evlerin *skoru* değil,
> *hangi evlerin listelendiği* (coğrafi koridor) değişiyor. Skoru
> gerçekten yeniden hesaplatan işlem, anchor sırası değil **kategori/kriter
> önceliği** sıralamasıdır (`/preferences`, `PUT /profile`). **W4 bu haliyle
> tam karşılanmıyor** — kalan borç olarak izleniyor.

**Düşük skorluları gösterme (W5):** varsayılan **açık**. Liste skora göre azalan sıralı; skor bandı renk şeridi ile gösterilir. Ayrıca sonuç başlığında `scoreDistribution` mini çubuğu — kullanıcı kaç ev hangi bantta görür.

### 11.3 Gerekçe tablosu UI (W6)

```
┌─ Bu ev size neden 71 puan aldı? ────────────────────────────┐
│                                                             │
│  ✅ NEDEN UYGUN                    ❌ NEDEN UYGUN DEĞİL      │
│  ─────────────────────            ──────────────────────    │
│  Bütçe uyumu        +21.0         Bütçe uyumu        −9.0   │
│  Hacettepe Beytepe  +11.5         Hacettepe Beytepe  −8.5   │
│  Spor salonu (①②)   +9.5          Aile evi           −3.4   │
│  Toplu taşıma       +7.7          Denge cezası       −2.4   │
│                                                             │
│  [ Tüm kriterleri göster ▾ ]                                │
│  ┌────────────────────┬──────────┬───────┬───────┬────────┐ │
│  │ Kriter             │ Ölçülen  │ Hedef │ Puan  │ Katkı  │ │
│  ├────────────────────┼──────────┼───────┼───────┼────────┤ │
│  │ Toplu taşıma durağı│ 4.0 dk   │ ≤5 dk │ 100   │ +7.70  │ │
│  │ Kafe & restoran    │ 3.8 dk   │ ≤5 dk │ 100   │ +7.00  │ │
│  │ …                  │          │       │       │        │ │
│  ├────────────────────┴──────────┴───────┴───────┼────────┤ │
│  │ TOPLAM                                        │  71.0  │ │
│  └───────────────────────────────────────────────┴────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 11.4 Harita render

6.000 nokta MapLibre'da GeoJSON olarak sorunsuz çizilir, ama zoom uzakken karmaşıklaşır:

| Zoom | Render |
|---|---|
| `z < 13` | `cluster: true`, `clusterRadius: 55` — küme rozetinde ev sayısı |
| `z ≥ 13` | Tekil noktalar, skor bandına göre renk, seçilenler numaralı pin |

Vector tile (MVT) **gerekmez** — 6.000 nokta bunu haklı çıkarmaz. Bu, ilk plandan sadeleşen bir karardır.

---

## 12. Kurulum (Setup)

### 12.1 Gerekli araçlar

| Araç | Sürüm | Not |
|---|---|---|
| .NET SDK | **10.0** | `dotnet --list-sdks` |
| Node.js | **22 LTS** veya 24 | `node -v` |
| pnpm | **11.x** | `corepack enable` |
| Docker Desktop | güncel | Windows'ta **WSL2 backend** açık olmalı |
| Java | **21** (Temurin) | Yalnızca Planetiler için |
| osmium-tool | 1.16+ | WSL/Ubuntu: `sudo apt install osmium-tool` |
| Flutter SDK | güncel stable | `flutter doctor` — mobil için (K-08) |
| Android Studio + SDK | güncel | Flutter APK derlemesi için zorunlu (~10 GB) |

### 12.2 Donanım

| Rol | RAM | Boş disk | Not |
|---|---|---|---|
| **ETL makinesi** (bir kişi, bir kez) | 16 GB | 40 GB | OSRM build + Planetiler |
| **Geliştirme makinesi** | 8 GB | 15 GB | Hazır artefaktları çalıştırır |

> **Kritik pratik:** ETL **tek makinede bir kez** yapılır; çıktılar (`osrm/foot/*`, `osrm/car/*`, `cankaya.mbtiles`, `seed.sql` — toplam ~1 GB) ortak bir paylaşıma (NAS / Drive / şirket içi depo) konur. Diğerleri indirip çalıştırır. Herkesin 8 GB'lık makinesinde `osrm-extract` çalıştırmak **OOM ile çöker** ve iki gün kaybettirir.

### 12.3 İlk çalıştırma sırası

```bash
# 0) Depo
git clone <repo> && cd basarsoft
cp .env.example .env

# 1) Veri artefaktlarını indir (ETL'i tekrar çalıştırmak yerine)
./data/scripts/00_fetch_artifacts.sh      # ~1 GB → data/artifacts/

# 2) Altyapıyı ayağa kaldır
docker compose --profile dev up -d postgis redis osrm-foot osrm-car tileserver

# 3) Şema + seed
#    ⭐ ŞEMAYI SADECE migrate.sh KURAR. `docker-entrypoint-initdb.d`
#    mount'u kaldırıldı (K-12) — bu adım ATLANAMAZ.
pnpm db:migrate

#    ETL çıktısı — yalnızca VERİ içerir (pg_dump --data-only),
#    şemayı yeniden yaratmaya çalışmaz:
psql -h localhost -U vivido -d vivido -f data/artifacts/seed.sql

# 4) API
dotnet run --project api/src/Vivido.Api          # → http://localhost:5000/swagger

# 5) Web
pnpm install && pnpm --filter web dev          # → http://localhost:5173

# 6) Mobil (ayrı terminal)
cd mobile && flutter run                       # K-08: Flutter
```

**Sağlık kontrolü:**
```bash
curl http://localhost:5000/health/ready        # {"db":"ok","osrm":"ok","tiles":"ok"}
curl "http://localhost:5001/route/v1/foot/32.85,39.92;32.86,39.93"   # OSRM foot
curl http://localhost:8080/data/v3.json        # tileserver — YOL 'v3', 'cankaya' DEĞİL
```

### 12.4 ⚠️ ~~Mobil kurulumun en büyük tuzağı~~ — GEÇERSİZ

> **Bu bölüm [K-08](02-KARARLAR.md#k-08) ile geçersiz kaldı.** Mobil taraf
> Expo/React Native'den **Flutter**'a geçti; `@maplibre/maplibre-react-native`,
> Expo Go / dev client ayrımı ve EAS Build akışı gündemden düştü.
> Flutter native modülleri doğrudan APK'ya derler.
>
> Bedeli açıkça yazılmıştı: **Android SDK yerel kurulum zorunlu (~10 GB)** —
> K-07'nin kaçındığı maliyet artık ödeniyor.
>
> Güncel mobil kurulum: `flutter doctor` yeşil olmalı, sonra
> `cd mobile && flutter run`.

### 12.4b ⚠️ Üretim derlemesinin en büyük tuzağı — harita boş çiziliyor

**Bu, K-08'in yerini aldığı tuzaktan daha sinsi ve HÂLÂ GEÇERLİ.**

MapLibre GeoJSON ayrıştırmayı ve karo çizimini bir web worker'da yapar.
Worker yüklenemezse **hiçbir veri katmanı çizilmez** — ama arka plan rengi,
+/− kontrolü ve atıf ana iş parçacığında olduğu için çalışmaya devam eder.
Harita "var" görünür, bomboştur ve **hata fırlatmaz**; konsol tertemiz kalır.

İki ayrı sebebi var, ikisi de yaşandı:

| Nerede | Sebep | Düzeltme |
|---|---|---|
| `pnpm dev` | Vite'ın bağımlılık ön-derleyicisi worker'ı bozuyor | `vite.config.ts` → `optimizeDeps.exclude: ['maplibre-gl']` |
| `vite build` | MapLibre 6 worker adını çalışma anında kuruyor; Vite 8/Rolldown statik olarak göremiyor ve parçayı çıktıya hiç eklemiyor | `CankayaMap.tsx` → `?worker&url` + `setWorkerUrl()` |

Ayrıntı: [04-MEVCUT-DURUM §5.5](04-MEVCUT-DURUM.md).

> **Ders:** üretim derlemesi (`vite build`) en az bir kez gerçekten
> sunulmadan "web çalışıyor" denemez. Bu hata haftalarca fark edilmedi
> çünkü herkes yalnızca `pnpm dev` kullanıyordu.

### 12.5 Yaygın kurulum hataları

| Hata | Neden | Çözüm |
|---|---|---|
| `osrm-extract` "Killed" | RAM yetersiz | ETL'i 16 GB makinede yap; `.wslconfig` içinde `memory=12GB` |
| `docker compose` yavaş / disk dolu | WSL2 disk büyümesi | `wsl --shutdown` + `diskpart` compact; Docker "Clean up" |
| `ERROR: extension "postgis" is not available` | Yanlış imaj | `postgis/postgis:16-3.4` kullanın, `postgres:16` değil |
| MapLibre haritası boş, kontroller çalışıyor | Worker yüklenmemiş | §12.4b — dev'de `optimizeDeps.exclude`, üretimde `setWorkerUrl` |
| `Location request timed out` | Emülatörde GPS yok | Android Studio → Extended Controls → Location → GPX iz yükleyin |
| Türkçe karakterli yol hatası | `Masaüstü` klasörü | Depoyu `C:\dev\vivido` gibi ASCII bir yola klonlayın |
| OSRM `/table` "too many locations" | `--max-table-size` düşük | `--max-table-size 200` ile başlatın |
| Yeni tablo/kolon DB'de yok | `pnpm db:migrate` çalıştırılmadı | Şemayı **yalnızca** migrate.sh kurar ([K-12](02-KARARLAR.md#k-12)) |
| `migrate.sh` exit 2 — aynı numaralı dosyalar | İki şema dosyası aynı öneki taşıyor | En büyük numaradan bir fazlasını al; yeniden adlandırma güvenli (K-12) |
| `migrate.sh` exit 3 — defter yok | DB migrate.sh'ten önce kurulmuş | Şema güncelse `bash /db/migrate.sh --baseline`, değilse `pnpm infra:reset` |
| `migrate.sh: bad interpreter` | Dosya CRLF ile kaydedilmiş | `.gitattributes` `*.sh`'ı LF'e zorlar — dosyayı LF olarak yeniden kaydedin |
| Git Bash'te `C:/Program Files/Git/db/migrate.sh: No such file` | Git Bash konteyner içi mutlak yolları Windows yoluna çevirir | `MSYS_NO_PATHCONV=1` verin, ya da PowerShell'den `pnpm db:migrate` çalıştırın |

---

## 13. Test Edilebilir Gereksinimler

> Her gereksinim **ölçülebilir** bir kabul kriteriyle eşleşir. Bu tablo Hafta 1'de dondurulur.

### 13.1 Kabul kriterleri

**AK-W2 · Persona ve bütçe seçimi**
```
Given kayıt olmuş ve onboarding'de olan bir kullanıcıyım
When  "Öğrenci" personasını seçip bütçeye 20.000 girerim ve kaydederim
Then  /profile GET yanıtı persona_code="student", monthly_budget=20000 döner
 And  ana ekrana yönlendirilirim
 And  liste boş değildir (en az 1 skorlanmış ev gelir)
```

**AK-W3 · Varsayılan yüksek skorlu görünüm**
```
Given persona seçilmiş, henüz anchor eklenmemiş
When  /explore ekranını açarım
Then  liste skora göre azalan sıralıdır (items[i].score >= items[i+1].score)
 And  ilk sayfadaki evlerin en az %60'ının skoru ≥ 65'tir
 And  her ev kartında sayısal skor ve renk bandı görünür
```

**AK-W4 · Anchor sıralamasının skoru değiştirmesi** ← *en kritik test*
```
Given 3 anchor eklemiş bir öğrenciyim (① Üniversite ② Spor salonu ③ Aile evi)
 And  4312 numaralı evin skoru 71.0
When  sürükle-bırak ile spor salonunu 1. sıraya taşırım
Then  PUT /profile/anchors/order çağrılır ve 200 döner
 And  3 saniye içinde liste yeniden yüklenir
 And  4312'nin yeni skoru eskisinden EN AZ 5 puan farklıdır
 And  gerekçe tablosunda spor salonunun ağırlığı 0.571'e yükselmiştir
```

**AK-W5 · Düşük skorlu evlerin de listelenmesi**
```
Given "Düşük skorlu evleri göster" işaretli
When  arama yaparım
Then  sonuçlar arasında skoru < 55 olan en az 1 ev vardır
 And  scoreDistribution alanı 4 bandın da sayısını döner
When  işareti kaldırırım
Then  skoru < 55 olan hiç ev dönmez
```

**AK-W6 · Gerekçe tablosu tutarlılığı** ← *değişmezlik testi*
```
Given herhangi bir ev ve profil kombinasyonu
When  GET /properties/{id}/score çağrılır
Then  rows[].contribution toplamı total'a ±0.05 içinde eşittir
 And  "güçlü" listesi en az 3, "zayıf" listesi en az 1 satır içerir
 And  her satırda measured, target, subScore, weight, contribution doludur
 And  anchor satırları öncelik sırasına göre sıralıdır
```

**AK-W7 · Rota optimizasyonu**
```
Given 5 ev seçtim ve başlangıç noktası olarak Kızılay'ı belirledim
When  "Rota Oluştur" derim
Then  POST /routes 200 döner, 5 saniye içinde
 And  route_stops 5 satır içerir, seq 1..5 kesintisizdir
 And  toplam süre, aynı evlerin SEÇİM SIRASIYLA gezilmesinden
      küçük veya eşittir (optimizasyon gerçekten çalışıyor)
 And  geometry bir LineString'dir ve boş değildir
 And  steps her bacak için en az 1 manevra içerir
```

**AK-M2/M3 · Mobil rota görüntüleme**
```
Given web'de oluşturulmuş bir rotam var ve mobilde giriş yaptım
When  rota listesinden birini seçerim
Then  harita rotanın tamamını kapsayacak şekilde otomatik yakınlaşır
 And  numaralı duraklar (1..n) doğru sırada görünür
 And  alt listede her ev için skor rozeti görünür
```

**AK-M4 · Navigasyon adım ilerlemesi**
```
Given navigasyon başlatılmış ve mock GPS izi oynatılıyor
When  kullanıcı bir manevra noktasına 15 m'den yaklaşır
Then  aktif adım bir sonrakine geçer
 And  üst kartta yeni manevra metni Türkçe görünür
 And  kalan mesafe azalarak güncellenir
When  kullanıcı rota çizgisinden 50 m'den fazla saparsa (3 ardışık konum)
Then  "Rotadan çıktınız" uyarısı görünür
```

**AK-M5 · Ziyaret işaretleme**
```
Given bir durağa 30 m'den yakınım
When  "Ziyaret ettim" derim
Then  PATCH /routes/{id}/stops/{seq} çağrılır
 And  durak listede ✓ ile işaretlenir
 And  web'de aynı rota açıldığında ✓ görünür (aynı veritabanı)
```

### 13.2 Skorlama için altın veri seti

`tests/golden/scores.json` — **elle hesaplanmış** referans vakalar:
- 10 konut × 6 persona × 3 anchor senaryosu (anchor yok / 2 anchor / 4 anchor) = **180 vaka**
- Her vaka: girdi (erişim süreleri, anchor süreleri, kira, bütçe) + beklenen toplam skor (±0.5)
- Motor saf ve I/O'suz olduğu için **180 vaka < 1 saniyede** koşar
- Dosya **CODEOWNERS ile korunur** — geliştirici testi geçirmek için beklenen değeri değiştiremez

**Değişmezlik testleri (her zaman doğru olmalı):**

| # | Değişmezlik |
|---|---|
| I1 | Skor her zaman `[0, 100]` |
| I2 | Bir kategorinin süresi azalırsa skor artmalı veya aynı kalmalı (monotonluk) |
| I3 | Tüm alt skorlar 100 ve bütçe rahatsa → toplam 100 |
| I4 | `Σ rows[].contribution == total` (±0.05) |
| I5 | Anchor sırası değişince skor değişmeli (aynı kalmamalı — sıra gerçekten etkili) |
| I6 | Aynı girdi iki kez → bit-bit aynı çıktı |
| I7 | Anchor listesi boşken skor = POISkoru (bütçesiz) |
| I8 | Persona ağırlıkları toplamı 1.000 (her persona için) |

### 13.3 Rota ve navigasyon testleri

| Ne | Nasıl |
|---|---|
| TSP doğruluğu | Held-Karp çıktısı, n ≤ 6 için **brute force** ile karşılaştırılır — birebir aynı olmalı |
| TSP performansı | n=8 için < 5 ms (birim test, `Stopwatch`) |
| OSRM entegrasyonu | WireMock ile kaydedilmiş yanıtlar — CI'da gerçek OSRM gerekmez |
| Manevra çevirisi | Tüm `type × modifier` kombinasyonları tablo testi; bilinmeyen → "Devam edin" |
| Adım durum makinesi | Kaydedilmiş GPS iz fixture'ları (`traces/*.json`) → beklenen adım geçişleri; **telefon gerekmez** |
| Mobil GPS mock | Android emülatörde GPX iz oynatma; iOS Simulator → Debug → Location → Custom |
| E2E web | Playwright: kayıt → persona → anchor sırala → ev seç → rota oluştur |

---

## 14. Fazlandırma (8 hafta)

| Hafta | Backend | Web | Mobil | Veri | Milestone |
|---|---|---|---|---|---|
| **1** | Solution iskeleti, EF Core + NTS, ilk migration, health check, **OpenAPI taslağı** | Vite + TS + Tailwind iskeleti, router, MapLibre "hello map" | **Dev client kurulumu** (§12.4) — bu hafta bitmeli | PBF indir, osmium extract, PostGIS ayağa kalksın | **M1** İskelet + kontratlar |
| **2** | Auth (JWT), `/personas`, `/profile`, `/profile/anchors` CRUD + `order` | Onboarding (persona + bütçe + anchor), anchor sürükle-bırak paneli | Giriş ekranı + mock rota listesi | POI eşleme + `pois` doldurma, `buildings`, mahalle poligonları | **M2** Profil & anchor |
| **3** | **`Vivido.Scoring` motoru** — decay, CES, anchor ağırlığı, bütçe, gerekçe satırları | `/explore` harita + liste + filtreler (mock skorla) | Rota listesi + rota detay haritası (mock veriyle) | **6.000 sentetik konut** + kira kalibrasyonu + DQ kuralları | **M3** Skor motoru |
| **4** | Erişim matrisi job'ı, `GET /properties` (skorlu), `GET /properties/{id}/score` | **Gerçek API'ye geçiş**, gerekçe tablosu UI, skor bandı renkleri | Ev skor kartı ekranı | Erişim matrisi üretimi, tile build (Planetiler) | **M4** ⭐ **İlk gerçek demo:** persona seç → skorlu evler → gerekçe tablosu |
| **5** | **TSP (Held-Karp)** + `POST /routes` + OSRM `/route steps=true` + rota CRUD | Ev seçimi, başlangıç noktası seçici, rota önizleme, kaydet | Rota detayı gerçek veriyle, numaralı duraklar | Redis cache, DQ raporu | **M5** Rota oluşturma |
| **6** | `PATCH /stops/{seq}` ziyaret, rate limiting, hata standardizasyonu | `/routes` sayfası, düşük skorlu gösterme, `scoreDistribution` çubuğu | **Navigasyon ekranı** — manevra kartı + `expo-location` + adım durum makinesi | Kalibrasyon turu, "vitrin" verileri | **M6** ⭐ **Navigasyon çalışıyor** |
| **7** | Performans (sorgu optimizasyonu, N+1), cache isabet ayarı | Responsive, boş/hata durumları, erişilebilirlik | Rotadan sapma, ziyaret işaretleme, pil optimizasyonu | ETL tam yeniden koşu + dondurma | **M7** Özellik dondurma |
| **8** | Bug fix + regresyon | Bug fix + cilalama | Bug fix + gerçek cihaz testi | Demo verisi kilidi | **M8** Dokümantasyon + sunum |

### 14.1 MVP çekirdeği (kesilemez)
**W2** persona + bütçe · **W3** skorlu varsayılan liste · **W4** anchor sıralama · **W6** gerekçe tablosu · **W7** TSP rota · **M3** rota görüntüleme · **M4** navigasyon

### 14.2 Kesme sırası (plan sarkarsa)
1. `pet` ve `bank` kategorileri düşer (10 → 8 kategori)
2. Persona 6 → 4 (`pet_owner`, `remote_worker` düşer)
3. Anchor maks 5 → 3
4. Rotadan sapma tespiti düşer (navigasyon yine çalışır)
5. Redis cache düşer (doğrudan DB'den okunur)
6. `/routes` web sayfası düşer (rota oluşturulur, sadece mobilde listelenir)

---

## 15. Riskler

| # | Risk | Ol./Etki | Erken uyarı | Azaltma |
|---|---|---|---|---|
| ~~**R1**~~ | ~~MapLibre RN Expo Go'da çalışmıyor~~ → **KAPANDI**: [K-08](02-KARARLAR.md#k-08) ile Flutter'a geçildi, dev client kavramı kalmadı | — | — | Yerine gelen risk R1b |
| **R1b** | **Üretim derlemesinde harita boş çiziliyor** — worker parçası çıktıya girmiyor, hata da fırlatmıyor | Orta / Yüksek | `vite build` çıktısı sunulunca harita boş | **GERÇEKLEŞTİ ve düzeltildi** (§12.4b). Ders: üretim derlemesi en az bir kez gerçekten sunulmadan "web çalışıyor" denmez |
| **R2** | **Skorlama "sihirli sayı çorbası"na döner**, kimse 71'i açıklayamaz | Yüksek / Kritik | Hafta 4'te "skorlar yanlış hissettiriyor" | Tüm parametreler **DB'de** (`poi_categories`, `persona_category_weights`), kodda sabit yok · **altın veri seti** Hafta 4'ten itibaren kilit · `Σ contribution == total` değişmezlik testi · gerekçe tablosu Hafta 4'te zorunlu |
| **R3** | **Sentetik kira verisi inandırıcı değil**; sunumda "bu fiyatlar saçma" eleştirisi | Orta / Yüksek | Hafta 3 demosunda ₺/m² dağılımı sapıyor | `ST_Within` %100 DQ kuralı · `β0` TÜİK/TCMB ile ±%15 kalibre · mahalle kira endeksi ekip dışı birine "makul mü" diye gösterilir · her yerde **"Sentetik veri" rozeti** |
| **R4** | **Anchor sıralaması skoru anlamlı değiştirmiyor** → W4 demoda etkisiz kalır | Orta / Yüksek | Hafta 4'te sırayı değiştirince skor 1-2 puan oynuyor | Geometrik ağırlık (0.5ⁱ⁻¹) seçildi — ters sıradan çok daha keskin · **I5 değişmezlik testi** bunu koruma altına alır · demo için sıralamaya duyarlı "vitrin evleri" önceden seçilir |
| **R5** | **ETL herkesin makinesinde çalıştırılmaya kalkılır** → OOM, kayıp günler | Orta / Orta | Hafta 1-2'de "Killed" logları | ETL **tek makinede bir kez**; artefaktlar paylaşımdan indirilir (§12.2) · `00_fetch_artifacts.sh` ilk gün hazır olmalı |
| **R6** | **Skor cache tutarsızlığı** — anchor değişti, liste eski skoru gösteriyor | Orta / Orta | Aynı ev listede 71, detayda 78 | `score_cache` PK'sında `scoring_version` · tek noktadan `IScoreCacheInvalidator.Invalidate(profileId)` · DB trigger ikinci emniyet · E2E testi: liste skoru == detay skoru |
| **R7** | **Kapsam yeniden şişer** — "bir de isochrone koyalım" | Orta / Yüksek | Sprint ortasında planda olmayan issue | §2 kapsam sözleşmesi README'nin ilk bölümü · yeni istek `backlog/v2.md`'ye, sprint'e alınmaz · Hafta 4 ve 6 demolarında yalnız sözleşmedeki maddeler |
| **R8** | **Navigasyon gerçek cihazda test edilmiyor**, sadece emülatörde çalışıyor | Orta / Yüksek | Hafta 7'ye kadar kimse arabada denemedi | Hafta 6 sonunda **zorunlu saha testi**: Çankaya'da gerçek bir rotayı arabayla gez, ekran kaydı al · bu kayıt demo yedeği de olur |
| **R9** | **Demo günü sistem çöker** (sunucu, ağ, GPS) | Düşük / Kritik | — | Demo ortamı Hafta 8 başında dondurulur · `pg_dump` yedeği · **tam akışın ekran kaydı videosu** hazır · sunum makinesinde `localhost` yedeği · mobil için önceden kaydedilmiş GPS izi |

---

## 16. Doğrulama — "Çalışıyor" nasıl kanıtlanır?

```bash
# Uçtan uca kurulum
docker compose --profile dev up -d
dotnet run --project api/src/Vivido.Api
pnpm --filter web dev
curl http://localhost:5000/health/ready        # {"db":"ok","osrm":"ok","tiles":"ok"}

# Test kapıları
dotnet test                                    # birim + entegrasyon
dotnet test --filter Category=Golden           # 180 altın vaka < 1 sn
dotnet test --filter Category=Invariant        # I1-I8
pnpm --filter web test                         # Vitest
pnpm --filter web test:e2e                     # Playwright
pnpm --filter mobile test                      # stepMachine + maneuverText

# Veri kapıları
psql -f db/checks/dq.sql                       # DQ-01..06, hepsi boş dönmeli
```

**Elle ürün doğrulaması (sunumdan önce):**
1. Aynı evi 6 farklı persona ile aç → skorlar **anlamlı şekilde farklı** olmalı
2. Anchor sırasını değiştir → skor ve liste sırası **gözle görülür** şekilde değişmeli
3. Gerekçe tablosundaki katkıları elle topla → gösterilen skora eşit olmalı
4. 5 evle rota kur → aynı evleri seçim sırasıyla gezmekten **kısa** olmalı
5. Rotayı telefonda gerçekten gez → adımlar doğru zamanda ilerlemeli

---

## 17. Bu Planın Dört Kritik Kararı

1. **Anchor sırası → ağırlık dönüşümü geometriktir** (`0.5ⁱ⁻¹`, normalize). Ters sıra ağırlığı yerine seçildi: listeye önemsiz bir anchor eklemek, 1. anchor'ın ağırlığını seyreltmemeli. `w₁ ≈ Σ(w₂..wₙ)` özdeşliği kullanıcının "en önemli" beyanını birebir karşılar.

2. **Kategoriler CES ile, anchor'lar ağırlıklı toplamla birleşir.** Kural: *altyapı eksikliği telafi edilemez, kullanıcı tercihi telafi edilebilir.* Metrosuz ev, araçsız kullanıcı için 13.9 puan alır — 72.3 değil.

3. **Gerekçe tablosunun satır katkıları toplamı skora birebir eşittir** (CES düzeltmesi açık bir satır olarak). Bu, açıklanabilirliğin omurgasıdır ve I4 değişmezlik testiyle korunur.

4. **Açık TSP kesin çözülür** (Held-Karp, <1 ms), OSRM `/trip` yalnızca yedektir. n ≤ 8'de kesin optimum ücretsizdir — "en kısa rota" iddiası sezgisele bırakılmaz.

---

## 18. İlk Adımlar

1. Depo iskeleti: `api/ web/ mobile/ packages/shared/ data/ db/ docker-compose.yml`
2. `db/schema/001_initial.sql` — §5'teki DDL
3. `api/openapi.yaml` — §10'daki endpoint sözleşmesi
4. .NET solution (5 proje) + Vite web + ~~Expo mobil (dev client ile!)~~ **Flutter mobil** ([K-08](02-KARARLAR.md#k-08) ile değişti)
5. `data/scripts/01_download.sh` … `06_seed_db.sh`
6. `data/lua/vivido_pois.lua` — POI tag eşlemesi
7. `docker-compose.yml` — 8 servis
8. README'nin ilk bölümü = **§2 kapsam sözleşmesi**
