# Mevcut Durum — Çalışır Sistem ve Yapılan Değişiklikler

> **Tarih:** 2026-08-23 (canlı belge — son güncelleme 2026-09-02) · **Branch:** `yazilim`
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

# İsteğe bağlı: konut adreslerinde sokak adı görünsün (~2 dk)
./data/scripts/05_load_streets.sh
```

> `05_load_streets.sh` **tüm ETL'i yeniden koşmaz** — yalnızca mevcut
> `cankaya.osm.pbf` kesitinden adlı yolları `streets` tablosuna aktarır.
> Atlanırsa adreste sokak adı görünmez, mahalle adı yazılır ([K-15](02-KARARLAR.md#k-15)).

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

> ### ⚠️ Bu bölüm 2026-08-25'te güncellendi
> Aşağıdaki "henüz yok" listesi 23 Ağustos'ta yazılmıştı ve **eskimişti**:
> skor motoru, `GET /properties`, EF entity'leri ve haritadaki konut
> noktaları o tarihten sonra yazıldı. Güncel durum §4.1'de.

### ✅ 2026-08-25'te eklenenler

| Alan | Durum |
|---|---|
| `Vivido.Scoring` motoru | **Yazıldı** — POI erişim sürelerinin ağırlıklı ortalaması. CES, anchor ve bütçe bileşenleri **henüz yok** |
| `GET /properties` | Bütçeye göre süzer, skorlar, azalan sıralar (sayfalama yok) |
| `GET /properties/top?limit=20` | "En uygun evler" — adres + tek satırlık gerekçe özeti + favori bayrağı |
| `GET /properties/{id}` | Adres, ev özellikleri, **satır satır gerekçe tablosu**, bütçe uyumu, favori durumu |
| `GET/POST/DELETE /profile/favorites` | Favori listesi artık konut özetini de taşıyor |
| Konut adresi | `streets` tablosu + KNN — %98,7 kapsam ([K-15](02-KARARLAR.md#k-15)) |
| Web: konut detay paneli | Gerekçe tablosu, güçlü/zayıf yönler, favori düğmesi |
| Web: "En uygun evler" paneli | Sağdan açılan sıralı liste, karta tıklayınca harita uçuyor |
| Web: profildeki favoriler | Gerçek kartlar — eskiden "Ev ID: 4213" yazıyordu |
| **E-posta doğrulama** | **Yerelde KAPATILDI** (geçici, README §2.5). Staging'de açık |

### 4.2 ✅ 2026-09-02'de eklenenler — Anchor koridoru

| Alan | Durum |
|---|---|
| `GET /properties` · `/properties/top` | Varsayılan olarak artık **anchor koridoru** uygulanıyor: kullanıcının bütçesine uyan evler, anchor'lardan oluşan coğrafi bir şeride düşenlerle sınırlanıyor. `showAll=true` ile kapatılabiliyor |
| Koridor topolojisi | **1. öncelikli (en önemli) anchor'ı merkez alan yıldız** — bacaklar 1↔2, 1↔3 şeklinde kuruluyor, 2. ve 3. anchor birbirine değil her zaman 1.'ye bağlanıyor (önceden zincir: 1↔2, 2↔3 idi, ortadaki anchor'ı yanlışlıkla "ara durak" gibi davranıyordu) |
| Bacak şekli | Her bacak için önce **yaya rotası**, olmazsa **araç rotası**, ikisi de yoksa iki ayrı **daire** — OSRM ile gerçek yol geometrisi üzerinden buffer alınıyor |
| Tek-anchor koridoru | Artık gerçek bir **daire**, önceden elipse çıkıyordu — bkz. §5.18 |
| Koridor cache | `AnchorsController` her anchor ekleme/silme/sıra değişikliğinde `PropertiesController`'ın 10 dk'lık koridor cache'ini geçersiz kılıyor (`InvalidateCorridorCache`) — anchor **skoru** etkilemiyor ama listelenen evleri anında değiştiriyor |
| Web: Anchor ekleme/listesi | "Nasıl gidiyorsun? (Araçla/Yürüyerek)" sorusu kaldırıldı — koridor hesabı zaten her bacak için kendi karar veriyor. Backend sözleşmesi değişmedi (`mode` hâlâ zorunlu alan), istemci sabit `'car'` gönderiyor |

> Bu bölüm önceki "❌ Henüz yok" listesindeki "Anchor bileşeni" maddesini kısmen güncelliyor: anchor'lar **skor formülüne** hâlâ girmiyor (AK-W4 karşılanmıyor), ama artık **listeleme/koridor** katmanında gerçek bir etkileri var. §5'e bu turda bulunan bir geometri hatası (elips) da eklendi, bkz. §5.18.

### ❌ Henüz yok

| Eksik | Not |
|---|---|
| ~~Skor kalibrasyonu~~ | **Çözüldü** — motor v1.1 (yumuşak tavan + zayıf halka + yoğunluk). Medyan 93,8 → **75,09**, tam 100 alan konut 767 → **0**. §5.14 |
| CES birleştirme (ρ = −0.5) | Tam CES yok; yerine **zayıf halka cezası** çarpanı var (aynı amaç, daha basit) |
| Anchor bileşeni (skor formülünde) | Anchor sırası **skoru** hâlâ değiştirmiyor — AK-W4 bugün karşılanmıyor. Ama 2026-09-02'den beri anchor'lar ayrı bir mekanizmayla **hangi evlerin listelendiğini** coğrafi olarak filtreliyor (bkz. §4.2, "anchor koridoru") — skora girmiyor, listelemeye giriyor |
| Bütçe bileşeni | Skora girmiyor; panelde ayrı bilgi olarak gösteriliyor ([K-16](02-KARARLAR.md#k-16)) |
| `min_poi_count` "veri yetersiz" yolu | Kategori devre dışı bırakma yok |
| Altın veri seti (72 vaka) + I1–I8 | `Category=Golden` / `Invariant` trait'i taşıyan test yok — `test:golden`/`test:invariant` script'leri şu an boş kategoriye karşı çalışıyor |
| Filtre paneli (kira / m² aralık) | Oda sayısı filtresi ve kira/m² **sıralaması** var ("En uygun evler" paneli); kira/m² için ayrı bir **aralık** (slider/min-max) filtresi hâlâ yok — bütçe aralığı profilden geliyor |
| Playwright | Kurulu değil |
| ~~Rota / TSP / mobil navigasyon~~ | **Çözüldü** — açık TSP (Held-Karp) ve OSRM rota geometrisi çalışıyor, önizle/kaydet akışı ayrıldı (§5.15–§5.17). Mobilde navigasyon ekranı da yazıldı (`navigation_page.dart`) |

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

### 5.11 🔴 Deploy sekiz kez "başarılı" dedi, siteyi bir kez bile güncellemedi

**Tarih:** 2026-08-24 · Karar: [K-13](02-KARARLAR.md#k-13)

`deploy-staging` iş akışı uzak betiği `ssh … bash -s <<SH` ile **STDIN
üzerinden** gönderiyor. Betiğin ortasındaki

```bash
docker compose -f docker-compose.prod.yml exec -T postgis bash /db/migrate.sh
```

satırı, `-T` sayesinde stdin'i konteynere aktarıyor — aktardığı stdin de
**betiğin kendisi**. Kalan satırları (`docker compose up -d`,
`docker image prune`) psql yutuyor, `bash` EOF görüp **0 ile çıkıyor**.

Görünen tablo: sekiz merge, sekiz yeşil deploy, GHCR'de sekiz yeni imaj,
sunucuda **29 saatlik konteynerler**. İmajlar `pull` ile sunucuya iniyordu
bile — sadece hiç devreye alınmıyorlardı.

**Üç arıza, tek kök neden.** Şema `008` ile `monthly_budget` düşürüldü
(migrate çalışan tek adımdı), API ise o sütunu soran eski imajda kaldı:

```
Npgsql.PostgresException 42703: column u.monthly_budget does not exist
  at Vivido.Api.Controllers.ProfilesController.GetProfile()
```

- `/api/v1/profile` ve `/profile/anchors` → **500** (haritaya yer pinleme)
- Mobil giriş → aynı 500
- "Site son değişiklikleri almıyor" → aynı sebep

**Düzeltme** (K-13): stdin tüketen her komuta `</dev/null`; `up -d` sonrası
`docker inspect` ile çalışan imajın beklenen SHA olduğu doğrulanıyor,
tutmuyorsa iş **kırmızı** oluyor.

> **Ders:** duman testi `/health/ready` 200 dönmesine bakıyordu. Site
> ayaktaydı — sadece eskiydi. **Ayakta olmak ile güncel olmak aynı şey
> değil.**

### 5.12 🟠 Mobil uygulama sunucuya değil, derleyenin bilgisayarına bağlanıyordu

`mobile/lib/core/config/app_config.dart` varsayılanı
`http://10.0.2.2:5000/api/v1` — Android emülatörünün **host loopback**
adresi. Yani APK yalnızca onu derleyen kişinin makinesindeki API'ye
ulaşıyordu; başka cihazda "sunucuya ulaşılamadı", webde açılan hesapla
giriş yok. Oysa M1'in tanımı *"web ile aynı hesap"* ([K-11](02-KARARLAR.md#k-11)).

Üstüne Android 9+ düz HTTP'yi engeller: `http://<IP>` **release APK'da
sessizce ölür**, yalnızca debug build'de çalışır.

**Düzeltme:** varsayılan `https://vividoapp.xyz/api/v1` (karolar:
`https://vividoapp.xyz/tiles`). Yerelde çalışmak isteyen ezer:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1 \
            --dart-define=TILE_BASE_URL=http://10.0.2.2:8080
```

Ayrıca `mobile/lib/core/mobile/lib/core/config/app_config.dart` ve
`mobile/lib/core/theme/mobile/lib/core/theme/app_theme.dart` silindi:
yanlışlıkla iç içe kopyalanmış, hiçbir yerden import edilmeyen ikizlerdi ve
biri **farklı bir base URL** taşıyordu — okuyan herkesi yanıltacak bir tuzak.

### 5.13 🟠 Çıkış yapılınca önceki hesabın verisi ekranda kalıyordu

**Tarih:** 2026-08-24 · Karar: [K-14](02-KARARLAR.md#k-14)

A hesabıyla eklenen anchor pinleri, çıkış yapıldıktan sonra **misafir
ekranında** ve **B hesabıyla girildiğinde** haritada görünmeye devam
ediyordu. Sunucu doğru davranıyordu; sızan şey tarayıcıdaki önbellekti.

İki sebep vardı:

1. Sorgu anahtarları (`['profile']`, `['anchors']`, `['favorites']`,
   `['routes']`) **kimliğe bağlı değildi** — herkes için aynı kutu.
2. `enabled: false` **veriyi gizlemez.** Misafirken istek atılmıyordu ama
   `useQuery` önbellekteki `data`yı döndürmeye devam ediyordu. Çıkışta
   hiçbir yerde `queryClient.clear()` de çağrılmıyordu.

**Düzeltme:** oturum deposu artık `sessionKey` taşıyor
(`user:<id>` / `guest` / `anon`); oturuma bağlı sorgular
`useSessionQuery` üzerinden yazılıyor (anahtarın sonuna kimlik eklenir,
`enabled` giriş koşuluyla VE'lenir); `SessionCacheSync` kimlik değiştiği an
önbelleği boşaltıyor. `sessionScope.test.tsx` üç senaryoyu da kilitliyor —
mekanizma kaldırıldığında üçü de kırmızıya düşüyor (doğrulandı).

Aynı PR'da: `PropertiesMapView` token'ı `localStorage.getItem('token')`
ile okuyordu, **projede öyle bir anahtar yok** (access token bellekte, K-A)
— ortak istemciye taşındı. Onboarding kaydından sonra `['profile']`
invalidate ediliyor.

### 5.14 🟠 Skor motoru ayrıştırmıyor — medyan 93,8, listenin tamamı 100

**Tarih:** 2026-08-25 · **ÇÖZÜLDÜ** (skor motoru v1.1, aynı gün)

> ### ✅ Düzeltildi — ölçümle doğrulandı
> Motor v1.1 üç şey getirdi: **yumuşak tavan** (t_ideal altında da eğim var,
> artık düz 100 değil), **zayıf halka cezası** (önemsenen en kötü kategori
> toplamı çarpan olarak kısıyor) ve **yoğunluk sinyali** (300 m'de 1 market
> ile 5 market aynı puanı vermiyor).
>
> Aynı sorgu, aynı profil (`remote_worker`, 20.000–25.000 ₺, 1.134 konut):
>
> | Ölçüm | Önce | Sonra |
> |---|---|---|
> | Medyan | 93,8 | **75,09** |
> | Skoru ≥ 85 olan | 767 (%68) | **359 (%32)** |
> | Tam 100 alan | 767 | **0** |
> | Farklı skor değeri | — | **1.036 / 1.134** |
> | "En uygun 20" aralığı | hepsi 100 | 98,55 – 99,40 |
>
> Aşağıdaki özgün kayıt, sorunun ne olduğunu ve neden önemsendiğini
> göstermek için duruyor.

**Özgün kayıt (2026-08-25, düzeltmeden önce):**

Gerekçe tablosu yazılırken ölçüldü. 20.000–25.000 ₺ bandındaki 1.134 konut
için, `remote_worker` personasıyla:

| Ölçüm | Değer |
|---|---|
| Skor aralığı | 0 – 100 |
| **Medyan** | **93,8** |
| Skoru ≥ 85 olan | 767 / 1.134 (**%68**) |
| "En uygun 20"nin skorları | 98,7 – 100 |

Dört personanın **dördünde de** ilk 20 konutun tamamı 100 alıyor ve
`topWeakness` alanı boş dönüyor (alt skoru 70'in altında satır yok).

**Sebep:** motor şu an yalnızca POI erişim sürelerinin ağırlıklı
ortalamasını alıyor. Çankaya yoğun bir ilçe; çoğu konut çoğu kategoriye
`t_ideal` içinde yürüyor, dolayısıyla neredeyse her kategori 100 puan
veriyor. Ortalama da 100'e yapışıyor.

Ayrıştırmayı sağlayacak üç şey yazılmamıştı:

- **CES birleştirme** (ρ = −0.5) — telafi edilemeyen eksikliği cezalandırır;
  düz ortalamada bir kategorinin sıfırı diğerlerinin arasında kayboluyor.
  → v1.1'de **zayıf halka cezası** olarak geldi (CES'in kendisi değil, aynı
  işi yapan daha basit bir çarpan)
- **Anchor bileşeni** — kullanıcıya özel tek gerçek ayrıştırıcı. → **HÂLÂ YOK**
- **Bütçe bileşeni** — asimetrik B(r) eğrisi. → **HÂLÂ YOK**

**Etkisi kozmetik değildi:** W5 "liste düşük skorluları da içerir" diyor ama
liste ayırt edici olmadığı için kullanıcı sıralamadan bilgi alamıyordu.

> **Gerekçe tablosu bu değişiklikten etkilenmedi** — [K-16](02-KARARLAR.md#k-16)
> sayesinde satırlar motorun kendi çıktısından üretiliyor. Motor v1.0 → v1.1
> geçişinde tabloya tek bir ekleme gerekti: zayıf halka cezası **çarpan**
> olduğu için kategori katkılarına dağıtılamıyor, ayrı bir satır olarak
> gösteriliyor (bkz. K-16'nın v1.1 notu). Formül hiçbir yerde ikinci kez
> yazılmadı.
>
> **Kalan borç:** AK-W4 ("anchor sırası skoru ≥ 5 puan değiştirir") hâlâ
> karşılanmıyor — anchor'lar skora girmiyor.

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
| Adreste sokak adı yerine sadece mahalle | `streets` tablosu boş | `./data/scripts/05_load_streets.sh` (K-15) |
| **`docker compose` postgis'i yeniden yaratıp veriyi "sildi"** | Konteynerler `name: vivido-pgdata` satırı eklenmeden ÖNCE başlatılmış; compose eski `vivido_pgdata` volume'ünden yenisine geçiyor. **Veri silinmez, öteki volume'de durur** | `docker volume ls` ile ikisini gör, `docker run --rm -v vivido_pgdata:/from:ro -v vivido-pgdata:/to alpine cp -a /from/. /to/` ile taşı |

---

## 8. Bilinen eksikler ve teknik borç

| # | Konu | Not |
|---|---|---|
| **1** | ~~CI/CD yok~~ → **kuruldu** (`deploy-staging.yml`), ilk hâlinde sessizce hiçbir şey yapmıyordu | `yazilim`'a merge → imaj derle → GHCR → migrate → `up -d` → duman testi. 2026-08-24'te bulunan stdin hatası ve çalışan imaj doğrulaması için [§5.11](#511-🔴-deploy-sekiz-kez-başarılı-dedi-siteyi-bir-kez-bile-güncellemedi) / [K-13](02-KARARLAR.md#k-13). **Kalan borç:** deploy'un doğruluğunu ölçen tek şey duman testi; "hangi commit yayında" diyen bir sürüm uç noktası yok |
| 2 | **6.000 konutun 5.568'i farklı koordinatta** (%7 çakışma) | `gen_properties.py` `random.choices` ile **iadeli** örnekliyor ve her bina sabit `ST_PointOnSurface` merkezine sahip. [§9.6](01-PROJE-PLANI.md) `ST_GeneratePoints(geom, n)` diyor — "20 daireli apartman" kavramı şu an kayıp |
| 3 | **Staging yedeği yok** | `pg_dump` cron'u kurulmadı. Biri yanlışlıkla `TRUNCATE` çekerse kullanıcı hesapları geri gelmez (konut verisi `seed.sql`'den yüklenebilir) |
| 4 | **`web/public/geo/` git'e girmiyor** | `data/*.geojson`'dan `web/scripts/sync-geo.mjs` ile üretilir; `pnpm dev`/`build` otomatik çalıştırır. İki nüsha tutup ayrışmasını önlemek için |
| 5 | **`@types/geojson` doğrudan bağımlılık değil** | `CankayaMap.tsx` asgari yerel tipler tanımlıyor. pnpm-lock'u değiştirmemek için bilinçli |
| 6 | **`api/openapi.yaml` yok** | `pnpm gen:api` çalışamaz; sözleşme elle senkron (`packages/shared` + `vivido-api-sozlesmesi.md`) |
| 7 | **Redis kullanılmıyor** | Bilinçli — 3 haftalık plan Redis'i kesti. `redis` servisi kökteki compose'da duruyor ama **kod hiç kullanmıyor**; staging'de hiç açılmıyor. Not: bu "skor cache hiç yok" demek değil — `score_cache` tablosu (DB-içi, persona+profil bazlı) `PropertyScoringService` tarafından fiilen kullanılıyor ve kategori önceliği değişince temizleniyor; iptal edilen yalnızca Redis'ti |
| 8 | **Test kapsamı düşük** | `Category=Golden` / `Invariant` trait'i taşıyan tek test yok; kapılar boşa çalışıyor. Playwright kurulu değil |
| 9 | **Mobil CI'da otomatik doğrulanıyor, yerelde hâlâ görülmedi** | `ci-mobile.yml` her push/PR'da `flutter analyze` + `flutter test` çalıştırıyor — "hiç doğrulanmadı" artık doğru değil. Ama bu makinede Flutter kurulu değil, uygulamanın gerçek cihaz/emülatörde çalıştığı burada gözlemlenmedi |

### 5.15 🔴 Staging'de rota oluşturma hiç çalışmadı — iki ayrı yapılandırma eksiği

**Tarih:** 2026-08-26 · **Düzeltildi**

Rota özelliği yerelde sorunsuz çalışıyordu; `https://vividoapp.xyz` üzerinde
"Rota Oluştur" her seferinde başarısız oluyordu. İki bağımsız sebep vardı ve
**ikisi de kod değil, `deploy/docker-compose.prod.yml`**:

**1. OSRM konteynerleri hiç başlamıyordu.** `osrm-foot` ve `osrm-car`
servisleri `profiles: ["routing"]` altındaydı ve üstünde *"Hafta 3'te rota
devreye girince açılacak"* notu duruyordu. Deploy iş akışı düz
`docker compose up -d` çalıştırıyor; profil adı verilmeyen bir servis ayağa
kalkmaz, compose ikisini de **sessizce atlıyordu**.

**2. API, OSRM'in adresini bilmiyordu.** Prod compose'da api servisine
`Routing__CarUrl` / `Routing__FootUrl` **hiç verilmemişti**. `OsrmOptions`
varsayılanı `http://localhost:5002` — konteynerin içinde `localhost` API'nin
KENDİSİ demek. İstek bağlantı reddine düşüyor, `RoutesController`
`ApiProblem.OsrmUnavailable()` ile **503** dönüyordu. Kökteki
`docker-compose.yml` bu iki satırı taşıyordu; prod dosyasına hiç geçmemişti.

**Neden hiçbir alarm çalmadı:** duman testi `/health/ready`, `/`,
`/tiles/data/v3.json` ve worker parçasına bakıyordu — hepsi 200. Site
tamamen sağlıklı görünürken yalnızca tek bir düğme çalışmıyordu.
[K-13](02-KARARLAR.md#k-13)'ün *"ayakta olmak ile çalışıyor olmak aynı şey
değil"* dersinin ikinci tekrarı.

**Düzeltme:** iki `Routing__*` satırı eklendi, `profiles: ["routing"]`
kaldırıldı ve duman testine **API konteynerinden `osrm-car`'a curl** atan
bir adım eklendi — bu sınıf arıza bir daha yeşil görünemez.

> ⚠️ Kalan ön koşul: sunucuda `./data/artifacts/osrm/{foot,car}/cankaya.osrm.*`
> bulunmalı (`data-v1` release'i). Yoksa OSRM konteyneri açılışta ölür ve rota
> yine 503 döner — duman testi artık bunu da yakalar.

### 5.16 🟠 Canlı konum hiç görünmüyordu ve rota çizgisi çizilmiyordu — aynı kök neden

**Tarih:** 2026-08-26 · **Düzeltildi**

İki ayrı belirti, tek sınıf hata: **"hazır" sanılan bir bayrağa dayanan efekt
bir kez çalışıp sessizce vazgeçiyor ve bir daha denenmiyor.**

**(a) Canlı konum.** `CankayaMap` içindeki GPS efekti `[]` bağımlılığıyla
yalnızca mount'ta çalışıyor ve `if (!map) return` ile çıkıyordu. Harita
asenkron kuruluyor (iki GeoJSON `fetch`'i), dolayısıyla mount anında `mapRef`
boş. İzin ÖNCEDEN verilmişse tarayıcı hiç sormaz, geri çağrı anında döner,
harita hazır değildir ve işaretçi **bir daha denenmeden düşer**. Kullanıcının
bildirdiği tablo tam olarak buydu: *"izin istemedi ve konumumu görmedim."*

**(b) Rota çizgisi.** `setStatus('hazir')` `setup()` sonunda **senkron**
kuruluyordu; oysa MapLibre stili asenkron yükler ve `getSource(...)` stil
yüklenene kadar `undefined` döner. `rota` kaynağına yazan efekt bu yüzden
erken çalışıp vazgeçiyordu. Rota Profil'den gelindiğinde store'da HAZIR
olduğu için efekt bir daha tetiklenmiyor ve **çizgi hiç çizilmiyordu**.

Diğer kaynaklar (`konutlar`, `pois`, `mahalleler`) kırılmıyordu çünkü
verileri React Query'den sonradan gelip efekti yeniden tetikliyor.

**Neden teşhisi zor:** duraklar ve `fitBounds` çalışıyordu — ikisi de
`getSource` istemez. Arıza "yarısı çalışıyor" gibi görünüyor, konsolda tek
satır hata yok.

**Düzeltme:**
- Konum ayrı bir kancaya taşındı (`shared/map/useUserLocation.ts`): koordinatı
  üretmek ile haritaya çizmek ayrıldı, konum önce gelse de kaybolmuyor.
  Ayrıca `timeout`, güvenli-kaynak (HTTPS) kontrolü ve izin reddi için
  kullanıcıya gösterilen açıklama eklendi (eskiden yalnızca `console.warn`).
- `status = 'hazir'` artık **stil yüklendikten sonra** kuruluyor
  (`map.isStyleLoaded()` ya da `map.once('load')`).

### 5.17 🟠 Rota kaydedilmeden önce görülemiyordu — her deneme çöp bırakıyordu

**Tarih:** 2026-08-26 · **Düzeltildi**

`POST /routes` hesaplayıp **anında kaydediyordu**. Kullanıcı rotayı ancak
kaydedildikten sonra görebiliyor, beğenmediği her deneme "Kayıtlı
Rotalarım"da kalıcı çöp bırakıyordu. Üstelik rota adı, rota daha
görülmeden isteniyordu.

**Düzeltme — akış ikiye ayrıldı:**

| Adım | Uç nokta | Ne yapar |
|---|---|---|
| 1. Önizleme | `POST /routes/preview` | TSP + OSRM çalışır, rota haritada çizilir. **Hiçbir şey yazılmaz** (`id` boş, `isSaved: false`) |
| 2. Kaydetme | `POST /routes` | Kullanıcı beğenirse: ad + isteğe bağlı tarih/saat sorulur, kaydedilir |

Kaydetme yeniden hesaplıyor. TSP ve OSRM aynı girdi için deterministik
olduğundan sonuç birebir aynı; alternatifi istemcinin hesaplanmış geometriyi
geri göndermesiydi — o da istemciye mesafe/süre uydurma imkânı verirdi.

**Ayrıca bu turda:**

- **Başlangıç seçimi tek bir konum kutusunda birleşti.** Önceden ayrı bir
  "Konumumu kullan" düğmesi ve ayrı bir adres arama kutusu vardı; ikisi de
  aynı soruyu cevapladığı hâlde iki farklı mekanizma gibi görünüyordu. Artık
  Google Maps'teki gibi tek kutu: açılınca en üstte canlı konum, altında
  **yazdıkça** gelen adres önerileri (300 ms debounce + `AbortController`).
- **"Sıfırla" artık veri silmiyor** — yalnızca ekranı ve oluşturucuyu
  temizliyor. Kayıtlı rota Profil'de duruyor.
- **Kayıtlı Rotalarım'a silme düğmesi** eklendi. İki adımlı onay: silme geri
  alınamaz, tek tıkla silmek listeye göz atarken rota kaybettirirdi.
- **Planlanan ziyaret zamanı** (`routes.scheduled_at`, migration 013) —
  kayıtlı rotalarda "🗓 29 Ağustos Cumartesi 14:00" olarak görünüyor.
  ⚠️ **Bildirim GÖNDERMİYOR**; gerekçe ve ön koşullar `backlog/v2.md`'de.

### 5.18 🟡 Tek anchor'lu koridor daire değil, elips çıkıyordu

**Tarih:** 2026-09-02 · **Düzeltildi**

Anchor koridoru buffer'ı `.Buffer(metres / MetresPerDegreeLat)` ile **derece**
cinsinden çiziliyordu — 1° boylam ile 1° enlemin aynı gerçek mesafeye denk
geldiği varsayılıyordu. Çankaya'nın enleminde (~39.9°) bu yanlış: 1° boylam,
1° enlemden yaklaşık **%23 daha kısa**. Sonuç: tek anchor'lu bir koridor
haritada daire değil, doğu-batı yönünde sıkışmış bir **elips** çıkıyordu
(gözle bulundu — bkz. §4.2 "anchor koridoru").

**Düzeltme:** buffer alınmadan önce X ekseni enlemin kosinüsüyle geriliyor
(bu uzayda 1 birim X = 1 birim Y gerçek mesafede), dairesel buffer bu
gerilmiş uzayda alınıp sonra geri sıkıştırılıyor. Aynı düzeltme yol tabanlı
(LineString) bacaklara da uygulandı; hata sadece tek-anchor durumunda
gözle daha görünürdü.

Kanıt: `api/src/Vivido.Api/controllers/PropertiesController.cs`.
