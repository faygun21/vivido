# Mevcut Durum — Çalışır Sistem ve Yapılan Değişiklikler

> **Tarih:** 2026-08-23 · **Branch:** `yazilim`
>
> Bu doküman projenin bugün **gerçekten** hangi noktada olduğunu anlatır ve
> yol boyunca bulunan/düzeltilen hataları kaydeder. Plan dokümanlarının
> iddiası değil, çalıştırılıp doğrulanmış durum yazılıdır.
>
> İlgili: [00-KAPSAM](00-KAPSAM.md) · [01-PROJE-PLANI](01-PROJE-PLANI.md) ·
> [02-KARARLAR](02-KARARLAR.md) · [03-HAFTA-2-PLANI](03-HAFTA-2-PLANI.md) ·
> [deploy/README](../deploy/README.md)

---

## 1. Tek cümleyle

Kullanıcı kayıt olup **e-postasına gelen kodla** hesabını doğrulayabiliyor,
şifresini sıfırlayabiliyor, **misafir olarak** kayıtsız gezebiliyor, persona
seçip bütçesini girebiliyor, **sokaklı/binalı gerçek Çankaya haritasını**
gezebiliyor ve anchor ekleyip sürükle-bırakla sıralayabiliyor — hepsi ekibin
ortak kullandığı **https://vividoapp.xyz** adresinde canlı.

---

## 2. İki ortam

| | Yerel (herkes, her gün) | Staging (ortak) |
|---|---|---|
| Adres | `localhost:5173` | **https://vividoapp.xyz** |
| Veritabanı | Kendi Docker PostGIS'i | Sunucudaki tek DB |
| E-posta | `console` — kod terminalde, **kimlik bilgisi gerekmez** | `smtp` — gerçek Gmail |
| Ne için | Kod yazmak, hızlı döngü | Entegrasyon, demo, mobil (M1) |

**Geliştirme staging'de yapılmaz.** Kurulum, erişim modeli ve deploy adımları:
[`deploy/README.md`](../deploy/README.md) · Karar: [K-11](02-KARARLAR.md#k-11).

---

## 3. Yerel çalıştırma

### 3.1 Bir kere: veri artefaktlarını edin

Harita karoları, OSRM grafları ve OSM kesiti **git'e girmez** — GitHub Release
üzerinden dağıtılır (dosya başına 100 MB'lık GitHub limiti ve depo şişmesi).

```powershell
cd C:\dev\vivido
.\data\scripts\00_fetch_artifacts.sh     # data/artifacts/ altına açar
```

`data-v1` release'i **yayınlandı**, betik çalışır durumda.

| Dosya | Boyut | Ne işe yarar |
|---|---|---|
| `cankaya.mbtiles` | 4.2 MB | Sokak / bina / su karoları |
| `osrm/foot/` | 38 MB | Yürüme süreleri (skorlamanın temeli) |
| `osrm/car/` | 28 MB | Araç rotası (Hafta 3, TSP) |
| `cankaya.osm.pbf` | 4.8 MB | Ham kesit — ETL'i yeniden koşmak isteyen için |
| `seed.sql` | ~14 MB | POI + bina + mahalle + konut + erişim matrisi |

### 3.2 Ortam dosyaları

```powershell
copy .env.example .env
copy web\.env.example web\.env
```

> ⚠️ **Vite `.env` dosyasını `web/` altından okur, depo kökünden DEĞİL.**
> Kökteki `.env` içindeki `VITE_*` satırları web'e etki etmez. İki dosya da lazım.

### 3.3 Altyapı, şema ve veri

```powershell
pnpm install
pnpm infra:up                                   # postgis + redis + pgadmin
docker compose --profile routing up -d tileserver osrm-foot osrm-car

pnpm db:migrate                                 # ⭐ ZORUNLU — şemayı kurar
docker compose exec -T postgis psql -U vivido -d vivido -v ON_ERROR_STOP=1 -f /seed/seed.sql

pnpm db:check                                   # 6/6 PASS görmelisin
```

> ⭐ **`pnpm db:migrate` artık atlanamaz.** Şema eskiden postgis konteyneri ilk
> açılışta `docker-entrypoint-initdb.d` ile kendiliğinden kuruluyordu; o mount
> **kaldırıldı** ([K-12](02-KARARLAR.md#k-12)). Sebebi §5.10'da.

### 3.4 Uygulama

```powershell
pnpm dev:api      # → http://localhost:5000/swagger
pnpm dev:web      # → http://localhost:5173
```

### 3.5 Doğrulama

| Adres | Beklenen |
|---|---|
| http://localhost:5000/health/ready | `Healthy` |
| http://localhost:8080/data/v3.json | TileJSON, 15 vektör katmanı |
| http://localhost:5001/route/v1/foot/32.85,39.92;32.86,39.93 | `{"code":"Ok",...}` |
| http://localhost:5173/auth/register | Kayıt formu |

Akış: **kayıt ol → e-posta kodu (API terminalinde) → doğrula → persona +
bütçe → harita**. Anchor eklemek için üst menüden **Profil**.

---

## 4. Şu an ne çalışıyor, ne çalışmıyor

### ✅ Çalışıyor

| Alan | Durum |
|---|---|
| `POST /auth/register` · `login` · `refresh` | Rotasyonlu, `problem+json` |
| `POST /auth/verify-email` · `resend-verification` | 6 haneli kod, 15 dk, 5 deneme ([K-09](02-KARARLAR.md#k-09)) |
| `POST /auth/forgot-password` · `reset-password` | Kodla sıfırlama, tüm oturumlar iptal |
| Aynı e-postayla ikinci hesap | Engelli — `citext UNIQUE` + trim + `23505` yakalama |
| `GET /personas` | 4 persona, veritabanından, **korumalı** |
| `GET/PUT /api/v1/profile` | Upsert, profil yoksa 404 `PROFILE_NOT_FOUND` |
| `GET/POST/DELETE /profile/anchors` | Maks 3, 4.'sü 422 `ANCHOR_LIMIT_EXCEEDED` |
| `PUT /profile/anchors/order` | Tek transaction, 4 maddelik doğrulama |
| Favoriler · rota iskeleti · konum arama | PR #19, #21, #22 |
| Web: **misafir modu** | Kayıtsız harita gezintisi ([K-10](02-KARARLAR.md#k-10)) |
| Web: giriş / kayıt / doğrulama / şifre sıfırlama | Gerçek API'ye bağlı (MSW kapalı) |
| Web: Çankaya haritası | Sokak, bina, su, yeşil alan, etiketler + 124 mahalle |
| Web: anchor paneli | Haritaya tıkla → ekle, dnd-kit ile sırala |
| **Staging** | https://vividoapp.xyz — HTTPS, gerçek e-posta ([K-11](02-KARARLAR.md#k-11)) |
| Veri: 6.000 konut + 48.000 erişim matrisi | OSRM foot süreleriyle |
| DQ kapıları | **6/6 PASS** |

### ❌ Henüz yok

| Eksik | Kimde (bkz. [03-HAFTA-2-PLANI](03-HAFTA-2-PLANI.md)) |
|---|---|
| `Vivido.Scoring` motoru — **hâlâ sıfır `.cs` dosyası** | BE-1 + BE-2 |
| `GET /properties` · `GET /properties/{id}/score` | BE-3 + BE-4 |
| `Property` / `PoiCategory` / `Neighborhood` EF entity'leri | BE-3 |
| Haritada konut noktaları, filtreler, gerekçe tablosu | FE-1 + FE-2 |
| **CI/CD** — staging elle deploy ediliyor | Sıradaki iş (§8.1) |
| Rota / TSP / mobil navigasyon | Hafta 3 |

> **Önemli:** 6.000 konut veritabanında ama **haritada görünmüyor** — onları
> ekrana getirecek zincir (entity → skor motoru → `GET /properties` → harita
> katmanı) henüz yazılmadı.

---

## 5. Bulunan ve düzeltilen hatalar

Bunlar plan sapması değil, **gerçek hatalardı**. Hepsi doğrulanarak düzeltildi.

### 5.1 🔴 `Persona` entity'sinin birincil anahtarı yoktu → API tamamen çalışmıyordu

`personas` tablosunun PK'sı `code` (text). EF'in varsayılan konvansiyonu `Id`
adlı bir özellik arıyor, bulamayınca **tüm model doğrulaması** patlıyordu:

```
The entity type 'Persona' requires a primary key to be defined.
```

Bu, veritabanına giden **her** sorguyu 500'e düşürüyordu — `register` dahil.

**Düzeltme:** `VividoDbContext`'te `entity.HasKey(e => e.Code)`.

### 5.2 🔴 osm2pgsql şema tablolarını eziyordu

`data/lua/vivido_pois.lua` doğrudan `pois` ve `buildings` adlarına yazıyordu.
osm2pgsql'in flex `define_table` çağrısı **verilen addaki tabloyu düşürüp
yeniden yaratır**, dolayısıyla `001_initial.sql`'deki tanımlar siliniyordu:

- `id bigserial PRIMARY KEY` → kayboluyor
- `category_code` → `poi_categories` yabancı anahtarı → kayboluyor
- `idx_poi_cat` indeksi → kayboluyor

Bu, [K-01](02-KARARLAR.md#k-01)'in açıkça uyardığı *"iki şema kaynağı"*
durumunun ta kendisi.

**Düzeltme:** lua artık `osm_pois` / `osm_buildings` **ara tablolarına** yazıyor;
[`data/scripts/04_merge_osm_into_schema.sql`](../data/scripts/04_merge_osm_into_schema.sql)
şemadaki gerçek tabloları kurup dolduruyor.

> ⚠️ ETL sırasında osm2pgsql'den **hemen sonra** bu SQL çalıştırılmalı.

### 5.3 🔴 Kira kalibrasyonu ~5 kat yüksekti → bütçe skoru işlevsizdi

`gen_properties.py` içinde `beta0 = 5.2` idi. Sonuç: medyan **978 ₺/m²**,
95 m² daire ≈ **93.000 ₺/ay**. Oysa [01-PROJE-PLANI §6.5](01-PROJE-PLANI.md)'teki
dolu örnek 95 m² için **18.500 ₺**.

Etkisi kozmetik değil: her ev için `r = kira/bütçe > 5` → `B(r) ≈ 0`. Bütün
evler aynı bütçe puanını alıyordu, skorlama ayrışmıyordu.

**Düzeltme:** `beta0 = 3.68`.

| | Önce | Sonra |
|---|---|---|
| Medyan ₺/m² | 978 | **214** |
| Medyan aylık kira | ~93.000 ₺ | **20.250 ₺** |
| 20.000 ₺ ile uygun ev | 2 | **2.953 (%49)** |

> ⚠️ **DQ-02 ve DQ-05 bu hatayı yakalayamaz.** İkisi de *göreli* kontrol
> (mahalle medyanının 0.3–3 katı); tekdüze ölçek hatası görünmez.

### 5.4 🟠 Erişim matrisi kuş uçuşu hesaplıyordu

`02_build_access_matrix.py` `ST_DistanceSphere(...) / 72.0` kullanıyordu —
kuş uçuşu mesafe ÷ sabit hız. Ürünün tüm iddiası *"bu ev markete 4 dakika"*
üzerine kurulu; kuş uçuşu binaları, vadileri ve yaya geçidi olmayan
bulvarları yok sayar.

**Düzeltme:** Script OSRM `/table` kullanacak şekilde yeniden yazıldı. Konut
başına tek `/table` çağrısı (1 kaynak + 8 kategori × 5 aday = 41 koordinat).

Ölçülen fark ortalama **1.37 kat** — eski yöntem tüm süreleri ~%37 kısa
gösteriyordu, yani bütün skorlar olduğundan yüksek çıkacaktı.

### 5.5 🟠 MapLibre worker'ı → harita boş çiziliyordu (iki ayrı hata)

**Belirti ikisinde de aynı ve sinsi:** MapLibre GeoJSON ayrıştırmayı ve karo
çizimini bir web worker'da yapar. Worker ölünce **hiçbir veri katmanı
çizilmez** — ama arka plan rengi, +/− kontrolü ve atıf ana iş parçacığında
olduğu için çalışmaya devam eder. Harita "var" görünür, bomboştur ve
**hata fırlatmaz**; tarayıcı konsolu tertemiz kalır.

**(a) Geliştirme sunucusunda.** Vite'ın bağımlılık ön-derleyicisi worker
dosyasını bozuyordu:

```
The file does not exist at .../deps/maplibre-gl-worker.mjs
```

**Düzeltme:** `vite.config.ts` → `optimizeDeps.exclude: ['maplibre-gl']`.

**(b) Üretim derlemesinde.** Bu notta önceden *"üretim derlemesi
etkilenmez"* yazıyordu — **yanlıştı.** MapLibre 6, worker dosyasının adını
çalışma anında kuruyor:

```js
new Worker(new URL(dev ? '…-worker-dev.mjs' : '…-worker.mjs',
                   import.meta.url), { type: 'module' })
```

Ad bir üçlü operatörden geldiği için **Vite 8 / Rolldown bunu statik olarak
göremiyor** ve worker parçasını çıktıya hiç eklemiyor; `dist/` içinde yalnızca
`index-*.js` + CSS oluyor.

Kimse fark etmemişti çünkü herkes `pnpm dev` ile çalışıyor — `vite build`
çıktısı ilk kez staging'de sunulunca ortaya çıktı.

**Düzeltme:** [`CankayaMap.tsx`](../web/src/shared/map/CankayaMap.tsx) — worker
`?worker&url` ile Vite'a açıkça paketletiliyor ve `setWorkerUrl()` ile
MapLibre'a veriliyor.

> Bu hata staging olmasaydı büyük ihtimalle demo günü keşfedilirdi.

### 5.6 🟡 `/api/v1/profiles` (çoğul) → sözleşme `/profile` (tekil) diyordu

`ProfilesController` `[Route("api/v1/[controller]")]` kullanıyordu; sınıf adı
çoğul olduğu için yol da çoğul oluyordu. Web istemcisi, `packages/shared`
tipleri ve `vivido-api-sozlesmesi.md` **tekil** bekliyor — onboarding'in
`PUT /profile` çağrısı 404 alıyordu.

**Düzeltme:** `[Route("api/v1/profile")]`. `GET` 404'ü `problem+json` +
`PROFILE_NOT_FOUND` oldu.

### 5.7 🟡 `GET /personas` korumasızdı

`[AllowAnonymous]` idi, sözleşme K-F korumalı olmasını söylüyor.
**Düzeltme:** `[Authorize]`.

### 5.8 🟠 Aynı e-posta ile ikinci hesap açılabiliyordu (boşluk farkıyla)

`users.email` sütunu `citext UNIQUE` olduğu için **büyük/küçük harf** farkı
zaten engelleniyordu. Ama `AuthController` gelen adresi hiç kırpmıyordu:

```
" ali@x.com "  →  citext karşılaştırması  →  "ali@x.com" ile EŞLEŞMEZ
```

Boşluk gerçek bir karakter; iki satır da UNIQUE kısıtını geçiyordu. Kullanıcı
kopyala-yapıştır yaptığında farkında olmadan ikinci hesap açıyordu.

İkinci sorun: kontrol `AnyAsync` + `Add` şeklinde **iki ayrı adımdaydı**. İki
istek aynı anda gelirse ikisi de "kullanıcı yok" görür, ikincisi UNIQUE
ihlaline düşer ve **500** dönerdi — oysa bu tam olarak 409.

**Düzeltme:** `NormalizeEmail` (trim) + `DbUpdateException` içindeki
`PostgresException.SqlState == "23505"` yakalanıp 409'a çevriliyor.

### 5.9 🟡 Dev sunucusu 5013'te açılıyordu

`launchSettings.json` `applicationUrl` değeri `http://localhost:5013` idi ve
bu dosya `ASPNETCORE_URLS`'i **ezer**. Oysa `.env.example`, `web/.env`
(`VITE_API_BASE_URL`), mobil `AppConfig` ve tüm dokümanlar `:5000` bekliyor.

Sonuç: web "Sunucuya ulaşılamadı" diyor, API ise sorunsuz ayakta — sadece
başka kapıda. Hiçbir logda görünmediği için teşhisi zor.

**Düzeltme:** `applicationUrl` 5000'e sabitlendi + dosyaya uyarı notu.

### 5.10 🔴 `migrate.sh` uygulanmamış dosyaları "uygulandı" sayıyordu

**Bugüne kadarki en tehlikeli hata** — sessizce eksik şema üretiyordu.

Betik, defter tablosu yoksa ve şema varsa *"initdb.d hepsini çalıştırmıştır"*
varsayıp **tüm dosyaları uygulanmış işaretliyordu**. Ama `initdb.d` yalnızca
konteyner **ilk açıldığı anda** var olan dosyaları çalıştırır.

Staging'de tam olarak bu oldu: `add_profile_names` ve
`add_profile_category_order` konteyner açıldıktan **sonra** kopyalandı.
Baseline ikisini de uygulanmış saydı; veritabanında `first_name`, `last_name`
sütunları ve `user_profile_category_order` tablosu **yoktu** ama defter "var"
diyordu. Profil kodu çalışma anında patlayacaktı ve sebebi hiçbir logda
görünmeyecekti — [K-01](02-KARARLAR.md#k-01)'in uyardığı sessiz şema kayması.

**Düzeltme** ([K-12](02-KARARLAR.md#k-12)):

1. `docker-entrypoint-initdb.d` mount'u **kaldırıldı** — şemanın tek
   uygulayıcısı `migrate.sh`. Çift kaynak yok, sorun yapısal olarak kapandı.
2. Otomatik baseline kaldırıldı; artık açık `--baseline` bayrağı istiyor.
   Baseline, geçmiş hakkında bir **iddiadır**; betik bunu bilemez, insan bilir.
3. **Çakışan numara koruması** — aynı numaralı iki dosya varsa `exit 2`.
4. **Yeniden adlandırma tespiti** — checksum eşleşiyorsa defterdeki ad
   güncellenir, dosya ikinci kez uygulanmaz.

4. madde sayesinde depoda birikmiş **üç adet `004`** güvenle düzeltilebildi
(`004_add_favorites` · `005_add_profile_names` ·
`006_email_dogrulama_ve_sifre_sifirlama` · `007_add_profile_category_order`);
her makine tek `pnpm db:migrate` ile kendiliğinden hizalanıyor.

### 5.11 🔴 Profil çağrısı eski staging şemasında 500 dönüyordu

K-12 gelecekteki hatalı baseline işlemini engelledi ancak daha önce yanlış
işaretlenmiş staging veritabanını kendiliğinden onarmıyordu. Defter 005 ve
007'yi uygulanmış gösterirken `first_name`, `last_name` sütunları ile
`user_profile_category_order` tablosu eksik kalabiliyordu. Sonuç olarak giriş
başarılı olsa da hemen arkasındaki `GET /api/v1/profile` çağrısı 500 dönüyordu.
Web istemcisi bütün profil hatalarını onboarding yönlendirmesine çevirdiği için
aynı arızayı gizliyor, mobil istemci ise giriş ekranında gösteriyordu.

**Düzeltme:** `009_reconcile_profile_schema.sql` eksik profil sütunlarını,
bütçe aralığını ve kategori sırası tablosunu idempotent olarak uzlaştırır.
Web artık yalnızca 404 `PROFILE_NOT_FOUND` yanıtında onboarding'e gider; 500 ve
ağ hatalarını gizlemez. CI, eski staging kaymasını kasten üretip 009'un yeniden
onarabildiğini doğrular.

---

## 6. Veri boru hattı — sıfırdan çalıştırma

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

# 3) ⚠️ ŞART: ara tablolardan şema tablolarına aktar (bkz. §5.2)
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

## 7. Tuzaklar

| Tuzak | Sonuç | Çözüm |
|---|---|---|
| `pnpm infra:up` sonrası `db:migrate`'i unutmak | Şema hiç kurulmaz, her sorgu patlar | initdb.d kaldırıldı ([K-12](02-KARARLAR.md#k-12)); `pnpm db:migrate` **zorunlu adım** |
| Var olan numarayı tekrar kullanmak (`004_...`) | `migrate.sh` **exit 2** | En büyük numaradan bir fazlasını al |
| `web/.env` yerine kök `.env`'i düzenlemek | `VITE_*` sessizce etkisiz | Vite `web/` altından okur, iki dosya da lazım |
| `VITE_TILE_URL=.../data/cankaya.json` | 404, harita altlıksız | Doğrusu **`/data/v3.json`** — tileserver-gl kaynağa `v3` diyor |
| **Harita boş ama kontroller çalışıyor** | Worker ölmüş | §5.5 — dev'de `optimizeDeps.exclude`, üretimde `setWorkerUrl` |
| osm2pgsql sonrası `04_merge...sql`'i atlamak | `b.id does not exist`, FK'lar yok | Adımı atlama (§5.2) |
| `pnpm db:check` sonrası konut sayısı 0 | seed yüklenmemiş | `psql -f /seed/seed.sql` |
| Git Bash'te `psql: C:/Program Files/Git/seed/... yok` | Git Bash konteyner içi yolları Windows'a çevirir | `MSYS_NO_PATHCONV=1` ya da PowerShell'den çalıştır |
| API 5000 yerine başka portta | Web "Sunucuya ulaşılamadı" der, API ayakta | `launchSettings.json` 5000 olmalı (§5.9) |
| `dotnet ef migrations add` | CI kırılır | Yeni `db/schema/00N_*.sql` + `pnpm db:migrate` |
| `Vivido.Scoring`'e paket eklemek | Build kırılır | Girdiyi `ScoringInput` içinde taşı |
| `data/artifacts/` boş | tileserver ve OSRM başlamaz | `00_fetch_artifacts.sh` |

---

## 8. Bilinen eksikler ve teknik borç

| # | Konu | Not |
|---|---|---|
| **1** | **CI/CD yok — en öncelikli borç** | Staging **elle** deploy ediliyor: imajlar bir makinede derlenip SSH ile aktarılıyor. Sonuç: `yazilim`'a merge edilen kod siteye **otomatik gitmiyor** ve bunu yapabilen tek makine var (bus factor 1). Bayat staging, staging olmamaktan kötüdür — yanlış bilgi verir |
| 2 | **6.000 konutun 5.568'i farklı koordinatta** (%7 çakışma) | `gen_properties.py` `random.choices` ile **iadeli** örnekliyor ve her bina sabit `ST_PointOnSurface` merkezine sahip. [§9.6](01-PROJE-PLANI.md) `ST_GeneratePoints(geom, n)` diyor — "20 daireli apartman" kavramı şu an kayıp |
| 3 | **Staging yedeği yok** | `pg_dump` cron'u kurulmadı. Biri yanlışlıkla `TRUNCATE` çekerse kullanıcı hesapları geri gelmez (konut verisi `seed.sql`'den yüklenebilir) |
| 4 | **`web/public/geo/` git'e girmiyor** | `data/*.geojson`'dan `web/scripts/sync-geo.mjs` ile üretilir; `pnpm dev`/`build` otomatik çalıştırır. İki nüsha tutup ayrışmasını önlemek için |
| 5 | **`@types/geojson` doğrudan bağımlılık değil** | `CankayaMap.tsx` asgari yerel tipler tanımlıyor. pnpm-lock'u değiştirmemek için bilinçli |
| 6 | **`api/openapi.yaml` yok** | `pnpm gen:api` çalışamaz; sözleşme elle senkron (`packages/shared` + `vivido-api-sozlesmesi.md`) |
| 7 | **Skor cache yok** | Bilinçli — 3 haftalık plan Redis'i kesti. `redis` servisi kökteki compose'da duruyor ama **kod hiç kullanmıyor**; staging'de hiç açılmıyor |
| 8 | **Test kapsamı düşük** | `Category=Golden` / `Invariant` trait'i taşıyan tek test yok; kapılar boşa çalışıyor. Playwright kurulu değil |
| 9 | **Mobil derlenmedi** | Flutter geliştirme makinesinde kurulu değil; `flutter analyze` ve `flutter test` **çalıştırılamadı**. Kod yazıldı, doğrulanmadı |
