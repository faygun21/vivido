# Mevcut Durum — Çalışır Sistem ve Yapılan Değişiklikler

> **Tarih:** 2026-08-20 · **Branch:** `femre/w2-temel-akis-ve-harita`
>
> Bu doküman projenin bugün **gerçekten** hangi noktada olduğunu anlatır ve
> yol boyunca bulunan/düzeltilen hataları kaydeder. Plan dokümanlarının
> iddiası değil, çalıştırılıp doğrulanmış durum yazılıdır.
>
> İlgili: [00-KAPSAM](00-KAPSAM.md) · [01-PROJE-PLANI](01-PROJE-PLANI.md) ·
> [02-KARARLAR](02-KARARLAR.md) · [03-HAFTA-2-PLANI](03-HAFTA-2-PLANI.md)

---

## 1. Tek cümleyle

Kullanıcı kayıt olup giriş yapabiliyor, 4 personadan birini seçip bütçesini
girebiliyor, **sokaklı/binalı gerçek Çankaya haritasını** gezebiliyor ve harita
üzerine tıklayarak en fazla 3 anchor ekleyip sürükle-bırakla sıralayabiliyor.
Veritabanında **6.000 sentetik konut** ve **48.000 satırlık erişim matrisi**
gerçek OSRM yürüme süreleriyle hazır bekliyor.

---

## 2. Çalıştırma

### 2.1 Bir kere: veri artefaktlarını edin

Harita karoları, OSRM grafları ve OSM kesiti **git'e girmez** — GitHub Release
üzerinden dağıtılır (dosya başına 100 MB'lık GitHub limiti ve depo şişmesi).

```powershell
cd C:\dev\vivido
.\data\scripts\00_fetch_artifacts.sh     # data/artifacts/ altına açar
```

İndirilenler:

| Dosya | Boyut | Ne işe yarar |
|---|---|---|
| `cankaya.mbtiles` | 4.2 MB | Sokak / bina / su karoları |
| `osrm/foot/` | 38 MB | Yürüme süreleri (skorlamanın temeli) |
| `osrm/car/` | 28 MB | Araç rotası (Hafta 3, TSP) |
| `cankaya.osm.pbf` | 4.8 MB | Ham kesit — ETL'i yeniden koşmak isteyen için |
| `seed.sql` | ~12 MB | POI + bina + mahalle + konut + erişim matrisi |

### 2.2 Ortam dosyaları

```powershell
copy .env.example .env
copy web\.env.example web\.env
```

> ⚠️ **Vite `.env` dosyasını `web/` altından okur, depo kökünden DEĞİL.**
> Kökteki `.env` içindeki `VITE_*` satırları web'e etki etmez. İki dosya da lazım.

### 2.3 Altyapı ve veri

```powershell
pnpm install
pnpm infra:up                                   # postgis + redis + pgadmin
docker compose --profile routing up -d tileserver osrm-foot osrm-car

# Veriyi yükle (şema konteyner ilk açılışta kendiliğinden kuruluyor).
# /seed → data/artifacts/  (docker-compose.yml'de mount edili)
docker compose exec -T postgis psql -U vivido -d vivido -v ON_ERROR_STOP=1 -f /seed/seed.sql

pnpm db:check                                   # 6/6 PASS görmelisin
```

### 2.4 Uygulama

```powershell
pnpm dev:api      # → http://localhost:5000/swagger
pnpm dev:web      # → http://localhost:5173
```

### 2.5 Doğrulama

| Adres | Beklenen |
|---|---|
| http://localhost:5000/health/ready | `Healthy` |
| http://localhost:8080/data/v3.json | TileJSON, 15 vektör katmanı |
| http://localhost:5001/route/v1/foot/32.85,39.92;32.86,39.93 | `{"code":"Ok",...}` |
| http://localhost:5173/auth/register | Kayıt formu |

Akış: **kayıt ol → persona seç + bütçe gir → Kaydet → harita** ·
Anchor eklemek için üst menüden **Profil**.

---

## 3. Şu an ne çalışıyor, ne çalışmıyor

### ✅ Çalışıyor

| Alan | Durum |
|---|---|
| `POST /auth/register` · `login` · `refresh` | Rotasyonlu, `problem+json` |
| `POST /auth/verify-email` · `resend-verification` | 6 haneli kod, 15 dk, 5 deneme ([K-09](02-KARARLAR.md#k-09)) |
| `POST /auth/forgot-password` · `reset-password` | Kodla sıfırlama, tüm oturumlar iptal |
| Web + mobil: **misafir modu** | Kayıtsız harita gezintisi ([K-10](02-KARARLAR.md#k-10)) |
| Web + mobil: parola tekrar alanı | Uyuşmazlıkta form gönderilmez |
| `GET /personas` | 4 persona, veritabanından, **korumalı** |
| `GET/PUT /api/v1/profile` | Upsert, profil yoksa 404 `PROFILE_NOT_FOUND` |
| `GET/POST/DELETE /profile/anchors` | Maks 3, 4.'sü 422 `ANCHOR_LIMIT_EXCEEDED` |
| `PUT /profile/anchors/order` | Tek transaction, 4 maddelik doğrulama |
| Web: giriş / kayıt / onboarding / profil | Gerçek API'ye bağlı (MSW kapalı) |
| Web: Çankaya haritası | Sokak, bina, su, yeşil alan, etiketler + 124 mahalle |
| Web: anchor paneli | Haritaya tıkla → ekle, dnd-kit ile sırala |
| Veri: 6.000 konut + 48.000 erişim matrisi | OSRM foot süreleriyle |
| DQ kapıları | **6/6 PASS** |

### ❌ Henüz yok

| Eksik | Kimde (bkz. [03-HAFTA-2-PLANI](03-HAFTA-2-PLANI.md)) |
|---|---|
| `Vivido.Scoring` motoru — **hâlâ sıfır `.cs` dosyası** | BE-1 + BE-2 |
| `GET /properties` · `GET /properties/{id}/score` | BE-3 + BE-4 |
| `Property` / `PoiCategory` / `Neighborhood` EF entity'leri | BE-3 |
| Haritada konut noktaları, filtreler, gerekçe tablosu | FE-1 + FE-2 |
| Rota / TSP / mobil | Hafta 3 |

> **Önemli:** 6.000 konut veritabanında ama **web'de görünmüyor** — onları
> ekrana getirecek zincir (entity → skor motoru → `GET /properties` → harita
> katmanı) henüz yazılmadı.

---

## 4. Bulunan ve düzeltilen hatalar

Bunlar plan sapması değil, **gerçek hatalardı**. Hepsi doğrulanarak düzeltildi.

### 4.1 🔴 `Persona` entity'sinin birincil anahtarı yoktu → API tamamen çalışmıyordu

`personas` tablosunun PK'sı `code` (text). EF'in varsayılan konvansiyonu `Id`
adlı bir özellik arıyor, bulamayınca **tüm model doğrulaması** patlıyordu:

```
The entity type 'Persona' requires a primary key to be defined.
```

Bu, veritabanına giden **her** sorguyu 500'e düşürüyordu — `register` dahil.
Yani `yazilim` branch'inde API hiç çalışmıyordu.

**Düzeltme:** `VividoDbContext`'te `entity.HasKey(e => e.Code)`.

### 4.2 🔴 osm2pgsql şema tablolarını eziyordu

`data/lua/vivido_pois.lua` doğrudan `pois` ve `buildings` adlarına yazıyordu.
osm2pgsql'in flex `define_table` çağrısı **verilen addaki tabloyu düşürüp
yeniden yaratır**, dolayısıyla `001_initial.sql`'deki tanımlar siliniyordu:

- `id bigserial PRIMARY KEY` → kayboluyor
- `category_code` → `poi_categories` yabancı anahtarı → kayboluyor
- `idx_poi_cat` indeksi → kayboluyor

Sonuç: `gen_properties.py` `column b.id does not exist` ile duruyordu ve
`properties.building_id` / `property_poi_access.poi_id` FK'ları kurulamıyordu.

Bu, [02-KARARLAR K-01](02-KARARLAR.md)'in açıkça uyardığı *"iki şema kaynağı"*
durumunun ta kendisi.

**Düzeltme:** lua artık `osm_pois` / `osm_buildings` **ara tablolarına** yazıyor;
yeni [`data/scripts/04_merge_osm_into_schema.sql`](../data/scripts/04_merge_osm_into_schema.sql)
şemadaki gerçek tabloları kurup dolduruyor. Doğruluk kaynağı `db/schema/*.sql`
olarak **kalıyor**.

> ⚠️ ETL sırasında osm2pgsql'den **hemen sonra** bu SQL çalıştırılmalı.

### 4.3 🔴 Kira kalibrasyonu ~5 kat yüksekti → bütçe skoru işlevsizdi

`gen_properties.py` içinde `beta0 = 5.2` idi. Sonuç: medyan **978 ₺/m²**,
95 m² daire ≈ **93.000 ₺/ay**. Oysa [01-PROJE-PLANI §6.5](01-PROJE-PLANI.md)'teki
dolu örnek 95 m² için **18.500 ₺** ve §13.1'deki öğrenci bütçesi **20.000 ₺**.

Etkisi kozmetik değil: her ev için `r = kira/bütçe > 5` → `B(r) ≈ 0`. Bütün
evler aynı bütçe puanını alıyordu, skorlama ayrışmıyordu. 20.000 ₺ bütçeyle
6.000 evden **2 tanesi** uygundu.

**Düzeltme:** `beta0 = 3.68`.

```
hedef: 95 m² → ~195 ₺/m²
ln(195) = 5.273 ;  beta1·ln(95) = 0.35 × 4.554 = 1.594
beta0 = 5.273 − 1.594 ≈ 3.68
```

| | Önce | Sonra |
|---|---|---|
| Medyan ₺/m² | 978 | **214** |
| Medyan aylık kira | ~93.000 ₺ | **20.250 ₺** |
| 20.000 ₺ ile uygun ev | 2 | **2.953 (%49)** |
| Tam bütçe puanı alan (`r ≤ 0.70`) | ~0 | **%22** |

> ⚠️ **DQ-02 ve DQ-05 bu hatayı yakalayamaz.** İkisi de *göreli* kontrol
> (mahalle medyanının 0.3–3 katı); tekdüze ölçek hatası görünmez. DQ-05'in
> tanımı zaten "gözle kontrol" ve kimse bakmamıştı.

### 4.4 🟠 Erişim matrisi kuş uçuşu hesaplıyordu

`02_build_access_matrix.py` şunu kullanıyordu:

```sql
ROUND(ST_DistanceSphere(p.geom, poi.geom) / 72.0, 1) AS duration_min
```

Bu kuş uçuşu mesafe ÷ sabit hız. [§9.8](01-PROJE-PLANI.md) ise OSRM `foot`
profilinden **gerçek yürüme süresi** istiyor. Ürünün tüm iddiası *"bu ev markete
4 dakika"* üzerine kurulu; kuş uçuşu binaları, vadileri ve yaya geçidi olmayan
bulvarları yok sayar. Ayrıca KNN `LIMIT 5` ön-elemesi anlamsızdı — aynı metrikle
tekrar minimum alınıyordu.

**Düzeltme:** Script OSRM `/table` kullanacak şekilde yeniden yazıldı. Konut
başına **tek** `/table` çağrısı (1 kaynak + 8 kategori × 5 aday = 41 koordinat),
`--max-table-size 200` sınırının çok altında.

Ölçülen fark:

| Kategori | Kuş uçuşu | OSRM | Oran |
|---|---|---|---|
| transit | 3.6 dk | 4.9 dk | 1.36× |
| market | 6.7 dk | 9.5 dk | 1.42× |
| pharmacy | 5.8 dk | 8.3 dk | 1.43× |
| health | 10.8 dk | 13.8 dk | 1.28× |

Ortalama **1.37 kat** — eski yöntem tüm süreleri ~%37 kısa gösteriyordu, yani
bütün skorlar olduğundan yüksek çıkacaktı.

### 4.5 🟠 Vite, MapLibre'ın web worker'ını bozuyordu → harita boş çiziliyordu

Vite'ın bağımlılık ön-derleyicisi:

```
The file does not exist at .../deps/maplibre-gl-worker.mjs
```

MapLibre GeoJSON ayrıştırmayı ve karo çizimini worker'da yapar. Worker ölünce
**veri katmanları sessizce hiç çizilmez** — ama arka plan rengi, +/− kontrolü ve
atıf ana iş parçacığında olduğu için çalışmaya devam eder. Harita "var" ama boş
görünür ve **hata fırlatmaz**, bu yüzden `try/catch` de yakalamaz.
Üretim derlemesi (`vite build`) etkilenmez; sorun yalnızca dev sunucusundadır.

**Düzeltme:** `vite.config.ts` → `optimizeDeps.exclude: ['maplibre-gl']`.

### 4.6 🟡 `/api/v1/profiles` (çoğul) → sözleşme `/profile` (tekil) diyordu

`ProfilesController` `[Route("api/v1/[controller]")]` kullanıyordu; sınıf adı
`ProfilesController` olduğu için yol **çoğul** oluyordu. Web istemcisi,
`packages/shared` tipleri ve `vivido-api-sozlesmesi.md` **tekil** bekliyor —
onboarding'in `PUT /profile` çağrısı 404 alıyordu.

**Düzeltme:** `[Route("api/v1/profile")]`. `PUT` artık `UserProfile` dönüyor
(sözleşme gereği). `GET` 404'ü `problem+json` + `PROFILE_NOT_FOUND` oldu.

### 4.7 🟡 `GET /personas` korumasızdı

`[AllowAnonymous]` idi, sözleşme K-F korumalı olmasını söylüyor.
**Düzeltme:** `[Authorize]`.

### 4.8 🟠 Aynı e-posta ile ikinci hesap açılabiliyordu (boşluk farkıyla)

`users.email` sütunu `citext UNIQUE` olduğu için **büyük/küçük harf** farkı
zaten engelleniyordu. Ama `AuthController` gelen adresi hiç kırpmıyordu:

```
" ali@x.com "  →  citext karşılaştırması  →  "ali@x.com" ile EŞLEŞMEZ
```

Boşluk gerçek bir karakter; iki satır da UNIQUE kısıtını geçiyordu. Kullanıcı
kopyala-yapıştır yaptığında (adres satırının sonunda boşluk kalması çok yaygın)
farkında olmadan ikinci bir hesap açıyordu.

İkinci sorun: kontrol `AnyAsync` + `Add` şeklinde **iki ayrı adımdaydı**. İki
istek aynı anda gelirse ikisi de "kullanıcı yok" görür, ikincisi veritabanı
UNIQUE ihlaline düşer ve **500** dönerdi — oysa bu tam olarak 409.

**Düzeltme:** `NormalizeEmail` (trim) + `DbUpdateException` içindeki
`PostgresException.SqlState == "23505"` yakalanıp 409'a çevriliyor.

---

## 5. Veri boru hattı — sıfırdan çalıştırma

ETL **tek makinede bir kez** koşulur, çıktılar Release'e yüklenir
([§12.2](01-PROJE-PLANI.md)). Yeniden üretmek gerekirse sıra şudur:

```bash
# 0) Araç kutusu
docker compose --profile etl build etl

# 1) Türkiye ekstresi (~613 MB) → Çankaya kesiti (4.8 MB)
curl -L -o data/artifacts/turkey-latest.osm.pbf \
  https://download.geofabrik.de/europe/turkey-latest.osm.pbf
docker compose --profile etl run --rm etl osmium extract \
  -p /work/data/cankaya.geojson /work/data/artifacts/turkey-latest.osm.pbf \
  -o /work/data/artifacts/cankaya.osm.pbf --overwrite

# 2) POI + bina → ARA tablolara
docker compose --profile etl run --rm etl osm2pgsql -O flex \
  -S /work/data/lua/vivido_pois.lua -H postgis -U vivido -d vivido \
  /work/data/artifacts/cankaya.osm.pbf

# 3) ⚠️ ŞART: ara tablolardan şema tablolarına aktar (bkz. §4.2)
docker compose --profile etl run --rm etl psql -v ON_ERROR_STOP=1 \
  -f /work/data/scripts/04_merge_osm_into_schema.sql

# 4) Mahalleler + kira endeksleri
docker compose --profile etl run --rm etl python3 /work/data/scripts/01_load_neighborhoods.py
docker compose --profile etl run --rm etl python3 /work/data/scripts/03_update_neighborhood_rent_indexes.py

# 5) 6.000 sentetik konut
docker compose --profile etl run --rm etl python3 /work/data/gen/gen_properties.py

# 6) OSRM grafları — erişim matrisinden ÖNCE gerekli
mkdir -p data/artifacts/osrm/foot data/artifacts/osrm/car
cp data/artifacts/cankaya.osm.pbf data/artifacts/osrm/foot/
cp data/artifacts/cankaya.osm.pbf data/artifacts/osrm/car/
# her profil için: osrm-extract -p /opt/{foot|car}.lua → osrm-partition → osrm-customize
docker compose --profile routing up -d osrm-foot osrm-car

# 7) Erişim matrisi (48.000 satır, gerçek yürüme süreleri)
docker compose --profile etl run --rm etl python3 /work/data/scripts/02_build_access_matrix.py

# 8) Karolar
docker compose --profile etl run --rm planetiler --download \
  --osm-path=/data/artifacts/cankaya.osm.pbf \
  --output=/data/artifacts/cankaya.mbtiles --force

# 9) Kapılar
pnpm db:check
```

**Doğrulanmış çıktılar:** 6.239 POI · 40.706 bina · 124 mahalle ·
6.000 konut · 48.000 erişim satırı · 4.2 MB karo · DQ 6/6 PASS.

> Planetiler `--download` olmadan `lake_centerline.shp.zip does not exist`
> ile durur. ~1.4 GB yardımcı kaynak indirir (Çankaya karasal olduğu için
> haritaya bir şey katmaz ama OpenMapTiles profili varlıklarını şart koşar).

---

## 6. Tuzaklar

| Tuzak | Sonuç | Çözüm |
|---|---|---|
| `web/.env` yerine kök `.env`'i düzenlemek | `VITE_*` sessizce etkisiz | Vite `web/` altından okur, iki dosya da lazım |
| `VITE_TILE_URL=.../data/cankaya.json` | 404, harita altlıksız | Doğrusu **`/data/v3.json`** — tileserver-gl OpenMapTiles şemasını tanıyıp kaynağa `v3` diyor |
| osm2pgsql sonrası `04_merge...sql`'i atlamak | `b.id does not exist`, FK'lar yok | Adımı atlama (§4.2) |
| `pnpm db:check` sonrası konut sayısı 0 | seed yüklenmemiş | `psql -f /seed/seed.sql` |
| Git Bash'te `psql: C:/Program Files/Git/seed/... yok` | Git Bash konteyner içi yolları Windows'a çevirir | Komutun başına `MSYS_NO_PATHCONV=1` ya da PowerShell'den çalıştır |
| `dotnet ef migrations add` | CI kırılır | Yeni `db/schema/00N_*.sql` + `pnpm db:migrate` |
| `Vivido.Scoring`'e paket eklemek | Build kırılır | Girdiyi `ScoringInput` içinde taşı |
| Harita boş ama kontroller çalışıyor | Vite worker sorunu | `.vite` önbelleğini sil, `optimizeDeps.exclude` duruyor mu bak (§4.5) |
| `data/artifacts/` boş | tileserver ve OSRM başlamaz | `00_fetch_artifacts.sh` |

---

## 7. Bilinen eksikler ve teknik borç

| # | Konu | Not |
|---|---|---|
| 1 | **6.000 konutun 5.568'i farklı koordinatta** (%7 çakışma) | `gen_properties.py` `random.choices` ile **iadeli** örnekliyor ve her bina sabit `ST_PointOnSurface` merkezine sahip. [§9.6](01-PROJE-PLANI.md) `ST_GeneratePoints(geom, n)` ile bina içine dağıtmayı söylüyor — "20 daireli apartman" kavramı şu an kayıp |
| 2 | **`web/public/geo/` git'e girmiyor** | `data/*.geojson`'dan `web/scripts/sync-geo.mjs` ile üretilir; `pnpm dev`/`build` bunu otomatik çalıştırır. İki nüsha tutup ayrışmasını önlemek için |
| 3 | **`@types/geojson` doğrudan bağımlılık değil** | `CankayaMap.tsx` asgari yerel tipler tanımlıyor. pnpm-lock'u değiştirmemek için bilinçli |
| 4 | **`api/openapi.yaml` yok** | `pnpm gen:api` çalışamaz; sözleşme elle senkron (`packages/shared` + `vivido-api-sozlesmesi.md`) |
| 5 | **Skor cache yok** | Bilinçli — 3 haftalık plan Redis'i kesti. `IScoreCacheInvalidator` arayüzü bile henüz yok |
| 6 | **Test kapsamı ~0** | `Category=Golden` / `Invariant` trait'i taşıyan tek test yok; kapılar boşa çalışıyor. Playwright kurulu değil |
| 7 | **Mobil** | Expo şablonu duruyor; [K-08](02-KARARLAR.md) Flutter'a geçişi kararlaştırdı, kod yazılmadı |

---

## 8. Değişen dosyalar

**Backend**
- `Vivido.Api/ApiProblem.cs` — **yeni**, RFC 7807 üretici
- `Vivido.Api/controllers/AnchorsController.cs` — **yeni**, 4 endpoint
- `Vivido.Api/controllers/ProfilesController.cs` — yol tekil, PUT DTO döner
- `Vivido.Api/controllers/PersonasController.cs` — `[Authorize]`
- `Vivido.Infrastructure/data/VividoDbContext.cs` — `Persona.HasKey(Code)`
- `Vivido.Application/dtos/profile/AnchorContracts.cs` — **yeni**

**Web**
- `features/auth/LoginPage.tsx`, `RegisterPage.tsx`, `authFlow.ts` — gerçek formlar
- `features/anchors/AnchorPanel.tsx` — harita + dnd-kit sıralama
- `features/explore/ExplorePage.tsx`, `features/profile/ProfilePage.tsx`
- `shared/map/CankayaMap.tsx` — **yeni**, ortak harita bileşeni
- `shared/config.ts` — `TILE_URL`, `GLYPHS_URL`, atıf
- `vite.config.ts` — `optimizeDeps.exclude`
- `scripts/sync-geo.mjs` — **yeni**
- `.env.example` — **yeni**

**Veri**
- `data/lua/vivido_pois.lua` — ara tablolara yazıyor
- `data/scripts/04_merge_osm_into_schema.sql` — **yeni**
- `data/scripts/02_build_access_matrix.py` — OSRM'e geçti
- `data/gen/gen_properties.py` — `beta0` kalibrasyonu
- `data/Dockerfile.etl` — `python3-requests`
