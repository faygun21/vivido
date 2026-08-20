# Kararlar

> Bu dosya, uygulama sırasında verilen ve **plan dokümanlarından sapan ya da
> onları netleştiren** kararları kaydeder.
>
> Amaç: altı hafta sonra "bu neden böyle yapılmış?" sorusunun cevabı kodun
> içinde kaybolmasın. Bir karar değişirse satırı silmeyin — durumunu
> `Değişti` yapıp yenisini altına ekleyin.
>
> Kapsam değişiklikleri buraya YAZILMAZ, onlar [`backlog/v2.md`](../backlog/v2.md)'ye gider.

| # | Karar | Durum |
|---|---|---|
| [K-01](#k-01) | Şemanın doğruluk kaynağı SQL dosyaları, EF Core migration değil | Kabul |
| [K-02](#k-02) | Şema değişiklikleri numaralı dosyalar + `db/migrate.sh` ile uygulanır | Kabul |
| [K-03](#k-03) | `refresh_tokens` tablosu eklendi | Kabul |
| [K-04](#k-04) | Persona ağırlıkları 8 kategoriye yeniden normalize edildi | Kabul |
| [K-05](#k-05) | ETL araçları host'a değil Docker imajına kurulur | Kabul |
| [K-06](#k-06) | Konut verisi sentetik, coğrafi veri gerçek OSM | Kabul |
| [K-07](#k-07) | Mobil dev client bulutta (EAS Build) üretilir | **Değişti** → K-08 |
| [K-08](#k-08) | Mobil uygulama Flutter ile yazılır, web React kalır | Kabul |

---

## K-01
### Şemanın doğruluk kaynağı SQL dosyalarıdır, EF Core migration değil

**Durum:** Kabul · 2026-08-18

**Bağlam.** [01-PROJE-PLANI.md §12.3](01-PROJE-PLANI.md) ilk çalıştırma sırasında
`dotnet ef database update` diyordu; aynı dokümanın proje yapısı bölümü ise
`db/schema/001_initial.sql` diyordu. İki farklı doğruluk kaynağı aynı anda
çalışamaz — EF, var olan tabloları yeniden yaratmaya çalışır ve hata verir.

**Karar.** Şema `db/schema/*.sql` içinde tanımlanır. EF Core **migration üretmez
ve uygulamaz**; C# entity'leri var olan şemaya uyacak şekilde elle yazılır.

**Gerekçe.**

1. **Şema paylaşılan bir kontrat, yazılım ekibinin iç meselesi değil.**
   [CODEOWNERS](../.github/CODEOWNERS) `db/schema/**` satırını ayrıca
   işaretliyor: *"KORUMALI: şema kontratı — dört iş kolu da buna güveniyor."*
   ETL, API, web ve mobil aynı şemaya bakıyor. Kontratın `api/` altındaki
   C# migration'larında yaşaması, onu tek bir ekibin bölgesine hapsederdi.
   [Üç haftalık plan](../habi-v2-3-hafta-plan.md) ayrıca `db/` ve `data/`
   klasörlerini veri ekibine devretmeyi öngörüyor (CODEOWNERS'ta henüz
   `@veri-lead` yazılmadı, hepsi `@faygun21`) — o geçiş yapıldığında SQL
   tabanlı şema bu ayrımla kendiliğinden uyumlu olur.
2. **ETL doğrudan yazıyor.** `osm2pgsql` tabloları EF'ten habersiz doldurur.
   Şema SQL'de olunca ETL ile tek kaynağı paylaşır.
3. **`DEFERRABLE INITIALLY DEFERRED`.** Anchor öncelik kısıtının EF Fluent
   API'sinde karşılığı yok; migration içinde ham SQL yazmak gerekirdi. Bu kısıt
   W4'ün (sürükle-bırak yeniden sıralama) çalışması için zorunlu.
4. **Veritabanı tek kullanımlık.** Demo verisi `data_version` ile donduruluyor,
   korunacak üretim verisi yok. Migration'ın asıl faydası burada küçük.

**Not:** EF'in PostGIS'i beceremediği *doğru değil* — GiST/BRIN indeksi, CHECK,
`citext`, `GENERATED ALWAYS AS STORED` ve geometry kolonları Npgsql
sağlayıcısında desteklidir. Karar teknik yetersizlikten değil, sahiplik ve iş
akışından çıktı.

**Sonuçları.**

- `pnpm db:migrate` artık EF komutu değil, [`db/migrate.sh`](../db/migrate.sh) çağırır (K-02).
- ETL çıktısı `seed.sql` **`pg_dump --data-only`** ile üretilmelidir — aksi
  halde şemayı ikinci kez yaratmaya çalışır.
- **Açık risk:** C# entity'leri ile SQL şeması sessizce ayrışabilir. Derleme
  geçer, uygulama çalışma anında patlar. Karşı önlem olarak Testcontainers ile
  bir "şema drift" testi yazılacak (`Category=Schema`): gerçek şemayı ayağa
  kaldırıp her `DbSet`'e sorgu atar. **Bu test henüz yazılmadı** — EF entity'leri
  yazılırken aynı PR'da gelmeli.

---

## K-02
### Şema değişiklikleri numaralı dosyalar + `db/migrate.sh` ile uygulanır

**Durum:** Kabul · 2026-08-18

**Bağlam.** Docker'ın `docker-entrypoint-initdb.d` mekanizması betikleri
**yalnızca konteyner ilk kez açıldığında** çalıştırır. K-01 ile şemayı SQL'e
taşıyınca, sonradan yapılacak her değişiklik `pnpm infra:reset` gerektirirdi —
volume silinir, 6.000 konut + 28.000 POI yeniden yüklenirdi.

**Karar.** `schema_migrations` defter tablosu + [`db/migrate.sh`](../db/migrate.sh).
Betik `db/schema/*.sql` dosyalarını ada göre sıralar ve **yalnızca defterde
kayıtlı olmayanları** çalıştırır.

**Nasıl kullanılır.**

```bash
# Yeni bir değişiklik: 001'i DÜZENLEME, yeni dosya aç
#   db/schema/003_konut_isitma_tipi.sql
#   ALTER TABLE properties ADD COLUMN isitma_tipi text;
pnpm db:migrate
```

**Davranışlar (üçü de test edildi).**

| Durum | Davranış |
|---|---|
| Defter yok, şema var (initdb.d çalışmış) | Baseline alır, dosyaları yeniden çalıştırmaz |
| Yeni dosya eklendi | Yalnızca onu uygular, **veriye dokunmaz** |
| Uygulanmış dosya sonradan değiştirildi | Checksum uyuşmaz → uyarır, **exit 2** |

Son madde önemli: uygulanmış bir dosyayı düzenlersen çalışan veritabanları o
değişikliği görmez, yalnızca sıfırdan kurulanlar görür — iki makine sessizce
farklı şemaya sahip olur. Betik bunu yakalar.

---

## K-03
### `refresh_tokens` tablosu eklendi

**Durum:** Kabul · 2026-08-18

**Bağlam.** [01-PROJE-PLANI.md §5](01-PROJE-PLANI.md) DDL'inde böyle bir tablo
yok, ama §10 API tablosunda `POST /auth/refresh` var ve `.env.example`
`Jwt__RefreshTokenDays=14` tanımlıyor.

**Karar.** Tablo eklendi. Token'ın kendisi değil **hash'i** saklanır.

**Gerekçe.** Refresh token sunucuda saklanmazsa iptal edilemez: kullanıcı çıkış
yapsa bile token süresi dolana kadar (14 gün) geçerli kalır. Hafta 1 Gün 2'nin
auth işi bu tabloya bağlıydı.

---

## K-04
### Persona ağırlıkları 8 kategoriye yeniden normalize edildi

**Durum:** Kabul · 2026-08-18

**Bağlam.** [habi-v2-3-hafta-plan.md](../habi-v2-3-hafta-plan.md) kesme listesi
`pet` ve `bank` kategorilerini çıkarıyor (10 → 8) ve personaları 6'dan 4'e
indiriyor. Ama §6.2'deki ağırlık matrisi 10 kategori için yazılmış ve satır
toplamları 1.000.

**Sorun.** İki kategori çıkarılınca toplamlar 1.000'in altına düşüyor:
`student` 0.85, `family_kids` 0.97, `remote_worker` 0.89, `elderly` 0.95.
Bu haliyle **DQ-03 ve I8 daha ilk gün kırmızı** olurdu.

**Karar.** Kalan 8 kategori, göreceli oranlar korunarak yeniden normalize edildi:

```
yeni_w = eski_w / (1 − w_bank − w_pet)
```

Dört personanın da toplamı tam `1.000` (doğrulandı). Kategoriler arası göreceli
önem plan dokümanıyla birebir aynı — yalnızca ölçek büyüdü.

**Kalan personalar:** `student`, `family_kids`, `remote_worker`, `elderly`.
Kesilenler: `pet_owner` (dayandığı `pet` kategorisi zaten kesildi), `car_free`
(`transit` ağırlığı `student` ile büyük ölçüde örtüşüyor).

**Açık iş:** [`packages/shared/src/index.ts`](../packages/shared/src/index.ts)
içindeki `PERSONA_CODES` hâlâ 6 persona listeliyor, veritabanında 4 var.
`GET /personas` yazılırken düzeltilmeli.

---

## K-05
### ETL araçları host'a değil Docker imajına kurulur

**Durum:** Kabul · 2026-08-18

**Bağlam.** ETL zinciri `osmium`, `osm2pgsql`, `psql` ve birkaç Python kütüphanesi
istiyor. Bunların Windows sürümü yok; WSL'e `sudo apt install` ile kurulmaları
gerekirdi.

**Karar.** [`data/Dockerfile.etl`](../data/Dockerfile.etl) — resmi `ubuntu:24.04`
tabanlı araç kutusu, compose'da `etl` profili altında.

```bash
docker compose --profile etl build etl
docker compose --profile etl run --rm etl bash
```

**Gerekçe.**

- Host'a kurulum gerekmez; ETL makinesi rolü başkasına geçerse imaj build edilir, kurulum tekrarlanmaz.
- Sürümler sabitlenir — "bende çalışıyordu" sorunu ortadan kalkar.
- Proje zaten OSRM ve Planetiler'i Docker'la çalıştırıyor (§9.2, §9.7); tutarlı.
- Üçüncü taraf imaj (`stefda/osmium-tool`, `iboates/osm2pgsql`) çekmek yerine
  resmi Ubuntu tabanından kurmak tedarik zinciri açısından daha güvenli.

**Doğrulanan sürümler:** osmium 1.16.0 · osm2pgsql 1.11.0 · psql 16.14 ·
Python 3.12.3 · psycopg2 2.9.9 · numpy 1.26.4 · shapely 2.0.3

Python paketleri `pip` yerine `apt`'ten kuruluyor: Ubuntu 24.04 PEP 668 ile
sistem Python'una pip kurulumunu engelliyor.

**Not:** `postgis` servisi `etl` profiline de eklendi — ETL doğrudan bu
veritabanına yazdığı için profil tek başına açıldığında da ayakta olmalı.

---

## K-06
### Konut verisi sentetik, coğrafi veri gerçek OSM

**Durum:** Kabul · 2026-08-18

**Karar.**

| Veri | Kaynak |
|---|---|
| Konut ilanları | **Sentetik** (`data/gen/gen_properties.py`, `is_synthetic = true`) |
| POI'ler | Gerçek OSM |
| Bina poligonları | Gerçek OSM |
| Yol ağı (OSRM) | Gerçek OSM |

**Gerekçe.**

- Konut tarafı: gerçek ilan verisi kullanım şartları açısından riskli
  (§9.6 "İlan scrape etmeyin"). Sentetik üretim ayrıca **deterministik**
  (`SEED=20260817`) — altın veri seti testleri buna dayanıyor — ve demo için
  gereken skor çeşitliliğini garanti ediyor.
- Coğrafi taraf: ürünün tamamı "bu ev markete 4 dakika" iddiası üzerine kurulu.
  POI'ler uydurma olursa skorun anlamı kalmaz. Yürüme süreleri OSRM'in gerçek
  yol ağından geliyor, uydurulamaz.
- Sentetik konutlar **gerçek bina poligonlarının içine** üretilir
  (`ST_GeneratePoints`, DQ-01 `ST_Within` ile zorlar). İnandırıcılığı sağlayan
  budur: gerçek adreslerde sahte ilanlar.

**Dürüstlük kuralı:** web ve mobilde her yerde "Sentetik veri" rozeti zorunlu.

---

## K-07
### Mobil dev client bulutta (EAS Build) üretilir

**Durum:** **Değişti · 2026-08-19** — mobil tarafı Flutter'a geçti, bkz. [K-08](#k-08).
Aşağıdaki metin tarihsel kayıt olarak duruyor.

**Bağlam.** `@maplibre/maplibre-react-native` native bir modül ve Expo Go'nun
sabit native setinde yok — harita Expo Go'da hiç açılmaz (§12.4). Development
build şart.

**Öneri.** EAS Build (bulut), yerel Android Studio derlemesi yerine.

**Gerekçe.** Makinede Android SDK yok; yerel yol ~10 GB indirme demek. EAS
doğrudan paylaşılabilir APK linki veriyor — README §2.4'ün "bir kişi üretir,
ekip aynı APK'yı kurar" akışına birebir uyuyor. Native modül listesi sabit
olduğu için tek derleme üç haftayı götürür.

**Karşı durum:** Şirket ağı EAS'i bloklarsa veya Expo hesabı istenmiyorsa yerel
derlemeye geçilir.

**Durum notu.** [`mobile/app.json`](../mobile/app.json) zaten doğru
yapılandırılmış (plugins, izinler, paket adı, konum metinleri). Eksik olan:
`eas.json` ve APK'nın kendisi. `mobile/App.tsx` hâlâ Expo boilerplate.

---

## K-08
### Mobil uygulama Flutter ile yazılır; web React+Vite olarak kalır

**Durum:** Kabul · 2026-08-19 · [K-07](#k-07)'nin yerine geçer

**Bağlam.** Hafta 2'ye 7 kişilik yazılım ekibiyle giriliyor (4 backend + 3 frontend). Frontend
ekibi mobil tarafı **Flutter** ile yazma kararı aldı. Karar alındığında `mobile/` klasöründe
`App.tsx` hâlâ Expo boilerplate'ti — yani terk edilen çalışan kod yok.

**Karar.**

| Katman | Seçim |
|---|---|
| Web (W1–W7) | **React 18 + TS + Vite + MapLibre GL JS** — değişmiyor |
| Mobil (M1–M5) | **Flutter** (`maplibre_gl`, `dio`, `go_router`, `flutter_secure_storage`) |
| Sözleşme | `packages/shared` (TS) **doğruluk kaynağı olmaya devam eder**; Dart modelleri onu yansıtır |

**Gerekçe.**

1. **Web tarafında terk edilecek gerçek iş var, mobilde yok.** `web/src/shared/api/client.ts`
   (RFC 7807 ayrıştırma + tek-uçuş 401→refresh→tekrar dene, testli), MSW handler'ları, auth store
   ve korumalı route'lar çalışıyor. Mobilde ise sadece boş şablon vardı. Sınırı buradan çekmek
   en az işi çöpe atan yer.
2. **Expo Go / dev client ayrımı ortadan kalkar.** K-07'nin çözmeye çalıştığı problem — native
   modülün Expo Go'da çalışmaması — Flutter'da yok. `flutter run` doğrudan native derler.
   R1 riski ("mobil ekip haftalarca kurulumla boğuşur") yapısal olarak kapanır.
3. **EAS hesabı ve bulut kuyruğu bağımlılığı gider.** APK derlemesi yerel ve tekrarlanabilir olur.

**Bedeli — açıkça yazıyorum.**

- **Android SDK yerel kurulum zorunlu (~10 GB).** K-07'nin kaçındığı maliyet buydu; artık ödeniyor.
- **Sözleşme iki kez yazılıyor.** `packages/shared`'daki TS tipleri Dart'ta elle yansıtılacak.
  Doğruluk kaynağı TS tarafı; Dart sapmaz. `anchorWeights()` gibi saf yardımcılar birebir port edilir.
- **Tek-uçuş refresh mantığı ikinci kez yazılıyor** (K-E). Web'deki uygulama referans alınır.
- **Kod paylaşımı yok.** Web ve mobil yalnızca API sözleşmesini paylaşır — zaten §2.3 mobilde
  arama/filtreleme/rota oluşturmayı kapsam dışı bıraktığı için örtüşen ekran yok.

**Sonuçları.**

- `mobile/` pnpm workspace'inden çıkar: `pnpm-workspace.yaml`, kök `package.json`
  (`dev:mobile`, `test:mobile`), `.github/workflows/ci-mobile.yml` (→ `flutter analyze` +
  `flutter test`), `.github/CODEOWNERS` güncellenir.
- `eas.json` ve EAS Build akışı gündemden düşer.
- `docs/01-PROJE-PLANI.md` §3 (teknoloji yığını) ve §12.4 (Expo dev client tuzağı) mobil satırları
  **eskimiştir** — bu karar onların yerine geçer.
- **Doğrulama kapısı:** `maplibre_gl` ile "hello map" gerçek Android cihazda **Hafta 2 Gün 6'da**
  açılmalı. Açılmazsa karar Hafta 2 içinde yeniden değerlendirilir — Hafta 3'te değil.

Uygulama planı: [`03-HAFTA-2-PLANI.md`](03-HAFTA-2-PLANI.md) §7 FE-3.
