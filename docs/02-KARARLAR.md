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
| [K-02](#k-02) | Şema değişiklikleri numaralı dosyalar + `db/migrate.sh` ile uygulanır | Kabul · [K-12](#k-12) ile sıkılaştırıldı |
| [K-03](#k-03) | `refresh_tokens` tablosu eklendi | Kabul |
| [K-04](#k-04) | Persona ağırlıkları 8 kategoriye yeniden normalize edildi | Kabul |
| [K-05](#k-05) | ETL araçları host'a değil Docker imajına kurulur | Kabul |
| [K-06](#k-06) | Konut verisi sentetik, coğrafi veri gerçek OSM | Kabul |
| [K-07](#k-07) | Mobil dev client bulutta (EAS Build) üretilir | **Değişti** → K-08 |
| [K-08](#k-08) | Mobil uygulama Flutter ile yazılır, web React kalır | Kabul |
| [K-09](#k-09) | E-posta doğrulama zorunlu; kayıt token dönmez (202) | Kabul |
| [K-10](#k-10) | Misafir modu: kayıtsız harita gezintisi, skor kilitli | Kabul |
| [K-11](#k-11) | Ortak staging ortamı — tek sunucu, tek origin, HTTPS | Kabul |
| [K-12](#k-12) | Şemanın tek uygulayıcısı `migrate.sh`; initdb.d kaldırıldı | Kabul |
| [K-13](#k-13) | Deploy "başarılı" diyemez — çalışan imaj doğrulanır | Kabul |
| [K-14](#k-14) | Oturuma bağlı sunucu verisi `useSessionQuery`'den geçer | Kabul |
| [K-15](#k-15) | Konut adresi yerel `streets` tablosundan; ters geokodlama yok | Kabul |
| [K-16](#k-16) | Gerekçe tablosu motorun İÇİNDEN üretilir, ikinci kopya yazılmaz | Kabul |

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

**Davranışlar.**

| Durum | Davranış |
|---|---|
| Yeni dosya eklendi | Yalnızca onu uygular, **veriye dokunmaz** |
| Uygulanmış dosya sonradan değiştirildi | Checksum uyuşmaz → uyarır, **exit 2** |
| Dosya yeniden adlandırıldı, içerik aynı | Checksum'dan tanır, defterdeki adı günceller ([K-12](#k-12)) |
| Aynı numarayı taşıyan iki dosya | **exit 2** — sıra rastlantısal olurdu ([K-12](#k-12)) |
| Defter yok ama şema var | **exit 3** — açık `--baseline` ister ([K-12](#k-12)) |

İkinci madde önemli: uygulanmış bir dosyayı düzenlersen çalışan veritabanları o
değişikliği görmez, yalnızca sıfırdan kurulanlar görür — iki makine sessizce
farklı şemaya sahip olur. Betik bunu yakalar.

> ⚠️ **Bu kararın ilk hâli eksikti.** Şema aynı zamanda
> `docker-entrypoint-initdb.d` ile de uygulanıyordu; iki uygulayıcı olduğu için
> `migrate.sh` otomatik baseline alıyor ve **hiç uygulanmamış dosyaları
> "uygulandı" sayabiliyordu.** Staging'de tam olarak bu oldu.
> Düzeltmesi: [K-12](#k-12).

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

---

## K-09
### E-posta doğrulama zorunlu; kayıt token dönmez, 202 döner

**Durum:** Kabul · 2026-08-21

**Bağlam.** [00-KAPSAM W1](00-KAPSAM.md) kabul kriteri *"kayıt formunu doldurup
gönderirim → **201 döner ve access + refresh token alırım**"* diyordu. Ürün
tarafından iki yeni istek geldi: kullanıcı **"Şifremi unuttum"** ile şifresini
yenileyebilmeli ve e-posta adresinin **gerçekten kendisine ait olduğu**
doğrulanmalı.

Şifre sıfırlama tek başına e-posta doğrulaması olmadan yazılamaz: doğrulanmamış
bir adrese sıfırlama kodu göndermek, o adresi yazan herkese hesabı ele geçirme
imkânı verir. İki iş aynı mekanizmaya (tek kullanımlık kod + e-posta) dayandığı
için birlikte kararlaştırıldı.

**Karar.**

| Konu | Karar |
|---|---|
| Hesap ne zaman oluşur | **Hemen** — `users` satırı doğrulanmamış olarak yazılır |
| Kayıt yanıtı | **202** + `verification_required` · **token YOK** |
| Doğrulanmamış hesapla giriş | **403 `EMAIL_NOT_VERIFIED`** |
| Kod doğrulanınca | **200 + token** — ayrıca giriş yapılmaz |
| Kod biçimi | 6 hane, 15 dk ömür, 5 yanlış deneme hakkı, 60 sn yeniden gönderme soğuması |
| Saklama | Ham kod ASLA saklanmaz — `SHA-256(kod + ':' + userId)` |
| E-posta sağlayıcı | **Gmail SMTP + Uygulama Şifresi** (`System.Net.Mail`), geliştirmede `console` |
| Anahtar | `Auth:RequireEmailVerification` — kapatılırsa eski davranış (201 + token) aynen sürer |

**Gerekçe.**

1. **Hesap neden hemen oluşuyor?** İki seçenek vardı: (a) `users` satırını hemen
   yaz, (b) doğrulanana kadar bekleyen-kayıt tablosunda tut. (a) seçildi çünkü
   `users.email` **UNIQUE** — satır yazılır yazılmaz adres rezerve olur ve
   "aynı e-postayla iki hesap" sorunu veritabanı seviyesinde kapanır. (b)
   seçilseydi iki kişi aynı adrese kayıt başlatabilir, ikincisi ancak
   **doğrulama anında** 409 yerdi — yani hatayı en geç öğrendiği anda.
2. **Doğrulanmamış kayıt üzerine tekrar kayıt olunabiliyor.** Kodu kaçıran
   kullanıcıya 409 basmak onu çıkmaza sokardı; bu durumda parola tazelenir ve
   yeni kod gider. Açık değil: hesabın sahibi olduğunu hâlâ ancak e-postasındaki
   kodu girerek kanıtlayabiliyor.
3. **Kod hash'inde `userId` tuz olarak var.** 6 hane = 1.000.000 olasılık;
   tuzsuz SHA-256 tablosu saniyeler içinde üretilir ve veritabanı sızıntısı
   doğrudan hesap ele geçirmeye dönerdi.
4. **Neden Gmail SMTP, Google Cloud + Gmail API değil?** İkisi de aynı sonucu
   veriyor. SMTP yolu bir NuGet paketi bile eklemiyor (`System.Net.Mail` BCL'de)
   ve kurulumu ~5 dakika: 2FA aç → Uygulama Şifresi al → `.env`. Gmail API yolu
   GCP projesi, OAuth consent screen ve refresh token üretimi istiyor —
   3 haftalık bir stajyer projesinde bu maliyetin karşılığı yok. `IEmailSender`
   arayüzü sağlayıcıyı soyutladığı için gerekirse geçiş tek sınıf.
5. **`console` sağlayıcı bilinçli.** Yedi kişilik ekibin hepsinin SMTP kimlik
   bilgisi olması gerekmesin; `pnpm dev:api` çalıştıran herkes kaydolur, kodu
   konsoldan okur, akışın tamamını dener.

**Bedeli — açıkça yazıyorum.**

- **Kabul kriteri W1 değişti.** `00-KAPSAM.md` güncellendi; "201 + token"
  artık yalnızca `RequireEmailVerification=false` iken doğru.
- **Sözleşme değişti:** `AuthUser` yeni `emailVerified` alanı taşıyor,
  `POST /auth/register` iki farklı başarılı yanıt verebiliyor. Web ve Flutter
  istemcilerinin ikisi de durum kodunu okumak zorunda kaldı.
- **Yeni tablo:** `auth_codes` (`db/schema/004_*.sql`).
- **Kayıt akışı bir adım uzadı.** Dönüşüm oranını düşüren bir karardır;
  karşılığında "şifremi unuttum" güvenli hale geldi.

**Sonuçları.**

- Yeni hata kodları: `EMAIL_NOT_VERIFIED` · `INVALID_CODE` · `CODE_EXPIRED` ·
  `TOO_MANY_ATTEMPTS` · `RESEND_TOO_SOON` · `EMAIL_SEND_FAILED` ·
  `VALIDATION_ERROR` — `packages/shared/src/errors.ts` ve `ApiProblem`'de.
- Şifre sıfırlama **tüm refresh token'ları iptal ediyor** (K-03). Şifresini
  sıfırlayan kişi çoğunlukla hesabının ele geçirildiğinden şüpheleniyor;
  iptal etmezsek saldırgan 14 gün daha oturumda kalırdı.
- `POST /auth/forgot-password` hesap var olmasa bile **her zaman 202** döner —
  aksi halde bu uç nokta "hangi e-postalar kayıtlı?" sorusunu cevaplayan bir
  tarama aracına dönerdi. `register`'ın 409'u bu bilgiyi zaten sızdırıyor ama
  o, W1 kabul kriterinin açık gereği.
- **Açık iş:** `auth_codes` için temizlik işi yok. Süresi geçmiş satırlar
  birikir; zararsız ama `DELETE FROM auth_codes WHERE expires_at < now()`
  elle çalıştırılmalı. Zamanlanmış iş `backlog/v2.md`'ye.

---

## K-10
### Misafir modu — kayıt olmadan harita gezintisi, skor kilitli

**Durum:** Kabul · 2026-08-21

**Bağlam.** [README §1](../README.md) kapsam listesi W1 ile başlıyor: kullanıcı
önce kaydolur. Uygulamayı ilk açan kişi ne gördüğünü bilmeden bir hesap açmaya
zorlanıyordu — üstelik K-09 ile araya bir de e-posta doğrulama adımı girdi.

**Karar.** Üçüncü bir giriş yolu: **"Misafir olarak devam et"**.

| Misafir görebilir | Misafir göremez |
|---|---|
| Çankaya haritası (sokak, bina, mahalle) | Kişiselleştirilmiş **0–100 skor** |
| Kiralık konutların **temel bilgileri** | Skorun **gerekçe tablosu** |
| — | **Persona** seçimi ve bütçe |
| — | **Anchor** ekleme / sıralama |

Kilitli bir işleme dokunulduğunda kullanıcı **giriş / kayıt ekranına
yönlendirilir**.

**Gerekçe.**

1. **Skor gizli kalmalı, harita değil.** Ürünün değeri skorda; onu bedava
   vermek kayıt olmanın sebebini ortadan kaldırırdı. Harita ise "bu uygulama
   ne yapıyor?" sorusunun tek cümlelik cevabı — onu göstermemek kayıt olmanın
   önündeki tek engel oluyordu.
2. **Kilitli özellikler GİZLENMİYOR, gösteriliyor.** Misafir panelinde üçü de
   listelenip kilit sebebi yazılıyor. "Burada ne kaçırıyorum?" sorusunun cevabı
   kayıt olmanın tek gerekçesi.

**Uygulama notları — ikisi de sessiz hata kaynağıydı.**

- **Web:** misafirken korumalı uç noktalara istek atılmaz
  (`useQuery({ enabled: authenticated })`). Atılsaydı `401 → yenileme denemesi →
  refresh token yok → onSessionExpired → clearSession()` zinciri çalışır ve
  **misafir kendi kendini kapı dışarı ederdi**.
- **Misafirlik `sessionStorage`'da**, `localStorage`'da değil. Geçici bir niyet,
  kalıcı bir tercih değil; sekme kapanınca unutulması doğru davranış.
- **Mobil:** `SessionPhase` ikiye ayrıldı — `guest` (karşılama ekranı) ve
  `browsing` (misafir harita). Tek değer kalsaydı kabuk hangisini çizeceğini
  bilemezdi.

**Kapsam notu.** Konut noktaları `GET /properties` ile gelecek (Hafta 2, BE-3).
O gün misafir yanıtında **skor alanları dönmemeli** — kilit sunucu tarafında da
zorlanmalı, yalnızca arayüzde gizlemek yetmez.

---

## K-11
### Ortak staging ortamı — tek sunucu, tek origin, HTTPS

**Durum:** Kabul · 2026-08-23

**Bağlam.** Yedi kişi kendi makinesinde kendi PostGIS'iyle çalışıyordu. Bunun
üç somut sonucu vardı:

1. **Bir bilgisayarda açılan hesap diğerinde tanınmıyordu.** Her laptop'ta ayrı
   bir `users` tablosu vardı; aynı e-posta yedi makinede ayrı ayrı kayıt
   olabiliyordu.
2. **M1 ("web ile aynı hesap") mobilde gösterilemiyordu.** Flutter uygulaması
   birinin `localhost`'una ancak aynı Wi-Fi + elle IP ayarıyla ulaşabiliyordu.
3. **Entegrasyon hataları yedi ayrı makinede ayrı ayrı keşfediliyordu.**

**Karar.** Tek sunucuda ortak bir **staging** ortamı.

| Konu | Karar |
|---|---|
| Sunucu | İlkbyte Cloud II — 3 vCPU / 4 GB / 40 GB, **KVM**, Türkiye (~29 ms) |
| Adres | `vividoapp.xyz` — Caddy + Let's Encrypt, otomatik yenilenen sertifika |
| Yönlendirme | **Tek origin**: `/` → web · `/api/*` → api · `/tiles/*` → tileserver |
| İmajlar | CI/registry'den çekilir; **sunucuda derleme yapılmaz** |
| Erişim | Ekibin tamamı tarayıcıdan; **SSH yalnızca deploy sorumlusu + 1 yedek** |
| Geliştirme | Yerelde kalır — staging'de kod yazılmaz |

**Gerekçe.**

1. **Neden ortak dev veritabanı değil, ortak ortam?** Yalnızca DB'yi
   paylaşmak daha ucuzdu ama [K-01](#k-01) yüzünden tuzaklı: şema SQL
   dosyalarıyla yönetiliyor, EF migration yok. Biri `008_*.sql` uygulayınca
   henüz pull etmemiş olanın C# entity'leri şemayla uyuşmaz; derleme geçer,
   uygulama **çalışma anında 500 döner** ve bu bir kod hatası gibi görünür.
   Yerel DB'ler izole kalmalı; paylaşılan şey tam bir ortam olmalı.
2. **Neden tek origin, `api.vividoapp.xyz` değil?** Aynı origin olunca CORS
   tamamen ortadan kalkıyor. Ayrıca `VITE_API_BASE_URL` göreli (`/api/v1`)
   kalabildiği için **domain değişince web imajının yeniden derlenmesi
   gerekmiyor**. İleride refresh token'ı `httpOnly` cookie'ye taşımak
   isterseniz (K-A'daki bilinen takas) yol da açık kalıyor.
3. **Neden sunucuda derleme yok?** `api/Dockerfile` `dotnet/sdk` ile derliyor;
   4 GB'lık makinede Postgres çalışırken bu OOM riski taşıyor. Ayrıca
   CI'dan geçen imajın **tam olarak aynısı** çalışsın istiyoruz.
4. **Neden herkese SSH yok?** Staging bir makine değil, bir URL. Yedi
   stajyere production benzeri bir sunucuda root vermek, birinin
   `docker compose down -v` yazıp veritabanını silmesinin en kısa yolu.
   **Yedek kişi ise şart:** anahtar tek kişideyse, o kişi demo gününden bir
   gün önce hastalandığında kimse deploy edemez.

**Bedeli.**

- Aylık ~$11 sunucu + yılda ~$2 domain.
- **Kapsam listesinde yok.** W1–W7 / M1–M5'te "deployment" diye bir madde
  yok. Bunu altyapı borcu sayıyoruz, özellik şişmesi değil — M1 bu olmadan
  gösterilemiyor ve demo günü tek çalışan ortam gerekiyor. Ama birinin
  1–2 gününü aldı, bu açıkça kabul edilmeli.
- **Bayat staging riski.** CI kurulana kadar site elle güncelleniyor;
  güncellenmezse ekip merge ettiği özelliği sitede bulamaz ve "kodum mu
  bozuk" diye vakit harcar. **Bayat ortam, ortam olmamaktan kötüdür.**

**Hemen karşılığını verdi.** Staging ilk gününde, `vite build` çıktısında
**haritanın hiç çalışmadığını** ortaya çıkardı
([04-MEVCUT-DURUM §5.5](04-MEVCUT-DURUM.md)). Herkes `pnpm dev` kullandığı
için üretim derlemesi o güne kadar hiç sunulmamıştı; bu hata büyük ihtimalle
demo günü keşfedilirdi.

**Açık iş.** CI/CD kurulmadı — bkz. [04-MEVCUT-DURUM §8.1](04-MEVCUT-DURUM.md).
Yedekleme cron'u da yok.

Kurulum, erişim modeli ve sorun giderme: [`deploy/README.md`](../deploy/README.md).

---

## K-12
### Şemanın tek uygulayıcısı `migrate.sh`; `initdb.d` mount'u kaldırıldı

**Durum:** Kabul · 2026-08-23 · [K-02](#k-02)'yi tamamlar

**Bağlam — sessizce eksik şema üreten bir hata.**

[K-02](#k-02) `migrate.sh` + defter tablosunu getirmişti. Ama şema aynı
zamanda `docker-entrypoint-initdb.d` mount'uyla da uygulanıyordu; yani
**iki uygulayıcı** vardı. `migrate.sh` bunu şöyle telafi ediyordu: defter
tablosu yoksa ve şema varsa, *"initdb.d hepsini çalıştırmıştır"* varsayıp
tüm dosyaları uygulanmış işaretliyordu (baseline).

Bu varsayım yanlış. `initdb.d` yalnızca konteyner **ilk açıldığı anda** var
olan dosyaları çalıştırır. Sonradan eklenen şema dosyaları hiç uygulanmadığı
hâlde deftere "uygulandı" diye yazılıyordu.

Staging kurulumunda tam olarak bu oldu: `add_profile_names` ve
`add_profile_category_order` konteyner açıldıktan **sonra** kopyalandı.
Veritabanında `first_name`, `last_name` sütunları ve
`user_profile_category_order` tablosu **yoktu** ama defter "var" diyordu.
Profil kodu çalışma anında patlayacaktı ve sebebi hiçbir logda
görünmeyecekti — [K-01](#k-01)'in uyardığı sessiz şema kaymasının aynısı.

**Karar — dört değişiklik.**

| # | Değişiklik | Neden |
|---|---|---|
| 1 | `db/schema:/docker-entrypoint-initdb.d` mount'u **kaldırıldı** | Çift kaynak sorunun kökü. Tek uygulayıcı kalınca hata yapısal olarak imkânsız |
| 2 | Otomatik baseline kaldırıldı, açık `--baseline` bayrağı istiyor | Baseline geçmiş hakkında bir **iddiadır**. Betik bunu bilemez; yalnızca doğrulayan insan söyleyebilir |
| 3 | **Çakışan numara koruması** — aynı numaralı iki dosya → `exit 2` | Sıralama ada göre; iki `004` varsa aralarındaki sıra adın geri kalanına göre, yani rastlantısal belirlenir. Biri diğerine bağlıysa sıra sessizce yanlış olur ve hata yalnızca sıfırdan kurulan makinelerde çıkar |
| 4 | **Yeniden adlandırma tespiti** — checksum eşleşiyorsa defterdeki ad güncellenir | Numara düzeltmesi ancak bununla mümkün. Aksi halde adı değiştirilen dosya "yeni" sanılır ve yeniden uygulanıp "tablo zaten var" ile patlar |

**Sonuçları.**

- **`pnpm db:migrate` artık zorunlu bir kurulum adımı.** `pnpm infra:up`
  tek başına şemayı kurmuyor. README ve
  [04-MEVCUT-DURUM §3.3](04-MEVCUT-DURUM.md) güncellendi.
- 4. madde sayesinde depoda birikmiş **üç adet `004`** güvenle düzeltildi:

  ```
  004_add_favorites.sql                         (değişmedi)
  004_add_profile_names.sql            → 005_add_profile_names.sql
  004_email_dogrulama_ve_sifre_sifirlama.sql
                                       → 006_email_dogrulama_ve_sifre_sifirlama.sql
  005_add_profile_category_order.sql   → 007_add_profile_category_order.sql
  ```

  Uygulanma sırası korundu. Her makine tek `pnpm db:migrate` ile
  kendiliğinden hizalanıyor; kimsenin elle SQL çalıştırması gerekmiyor.
  Staging'de doğrulandı: üç satır yeniden adlandırıldı, hiçbir dosya ikinci
  kez uygulanmadı, veri kaybı olmadı.
- Şeması olup defteri olmayan eski bir veritabanı artık `exit 3` ile durur ve
  ne yapılacağını yazar (`--baseline` ya da `pnpm infra:reset`).

**Bedeli.** Sıfırdan kurulum bir komut uzadı. Karşılığında "şema var sanıp
olmayan sütuna sorgu atma" sınıfı hatalar kapandı.

---

## K-13
### Deploy "başarılı" diyemez — sunucuda çalışan imaj doğrulanır

**Durum:** Kabul · 2026-08-24 · [K-11](#k-11)'in CI/CD açığını kapatır

**Bağlam — sekiz yeşil deploy, sıfır güncelleme.**

24 Ağustos'ta `yazilim` dalına sekiz PR merge edildi ve `deploy-staging`
sekizinde de **success** verdi. Ama https://vividoapp.xyz 23 Ağustos'ta
derlenmiş imajı çalıştırmaya devam etti: konteynerler 29 saatlik,
`docker inspect vivido-api` → `created=2026-08-23T14:03`.

Sebep, uzak betiğin **STDIN'ini tüketen bir komut**:

```bash
ssh "$H" bash -s <<SH          # betik uzak tarafta STDIN'den okunuyor
  …
  docker compose exec -T postgis bash /db/migrate.sh   # ← STDIN'i devralır
  docker compose up -d                                 # ← ARTIK ÇALIŞMAZ
SH
```

`exec -T` konteynere stdin'i **aktarır**; aktardığı stdin de betiğin
kendisidir. `migrate.sh`'ten sonraki satırları psql yutar, `bash` EOF görür
ve **0 ile çıkar**. Hata yok, uyarı yok.

Sonuç zinciri: şema 008 ile `monthly_budget` sütununu düşürdü (migrate
çalıştı), API ise hâlâ o sütunu soran eski imajdaydı →
`42703: column u.monthly_budget does not exist` → `/profile` ve
`/profile/anchors` **500**. Haritaya yer pinlerken, mobil giriş yaparken
görülen hata buydu. Yani tek bir kök neden üç ayrı arıza gibi göründü.

**Duman testi neden yakalamadı:** `/health/ready`, `/`, `/tiles/data/v3.json`
ve worker parçası — hepsi 200. Site ayaktaydı, yalnızca **eskiydi**.
Ayakta olmak ile güncel olmak aynı şey değil.

**Karar — üç madde.**

| # | Değişiklik | Neden |
|---|---|---|
| 1 | Uzak betikte stdin tüketen her komut `</dev/null` alır | Betiğin geri kalanının yutulması yapısal olarak imkânsız olur |
| 2 | `up -d` sonrası `docker inspect` ile **çalışan imaj = beklenen SHA** doğrulanır, değilse `exit 1` | Sessiz no-op bir daha yeşil görünemez |
| 3 | Boru (`echo … \| docker login --password-stdin`) sorun değildir, dokunulmadı | Boru komuta KENDİ stdin'ini verir; gereksiz değişiklik gürültüdür |

**Ders.** Deploy otomasyonunun doğruluğu, "iş yeşil mi" ile değil
**"sunucuda ne çalışıyor"** ile ölçülür. K-11 "bayat staging, staging
olmamaktan kötüdür" diyordu; bu olay onun otomasyona bakan yüzü:
**yeşil raporlayan bayat staging, elle deploy'dan da kötüdür** — çünkü
kimse şüphelenmez.

---

## K-14
### Oturuma bağlı sunucu verisi yalnızca `useSessionQuery` üzerinden okunur

**Durum:** Kabul · 2026-08-24

**Bağlam — başka hesabın pinleri haritada kaldı.**

Test sırasında bulundu: A hesabıyla eklenen anchor pinleri çıkış
yapıldıktan sonra **misafir ekranında** ve **B hesabıyla girildiğinde**
görünmeye devam ediyordu.

İki ayrı sebep vardı ve ikisi de aynı boşluktan besleniyordu — *"bu veri
kime ait?"* sorusunun kodda bir cevabı yoktu:

1. **Önbellek anahtarı kimliğe bağlı değildi.** `['profile']`, `['anchors']`,
   `['favorites']`, `['routes']` herkes için aynı kutuydu. B kullanıcısı
   A'nın kutusunu açıyordu.
2. **`enabled: false` veriyi GİZLEMEZ.** Yaygın yanılgı buydu: misafirken
   `enabled: authenticated` ile istek atılmıyordu, dolayısıyla "veri de
   görünmez" sanıldı. Oysa `useQuery` istek atmasa bile **önbellekteki
   `data`yı döndürür**. Misafir ekranında A'nın pinlerini çizen tam olarak
   buydu. Çıkışta hiçbir yerde `queryClient.clear()` de çağrılmıyordu.

**Karar.**

| # | Kural | Nerede |
|---|---|---|
| 1 | Oturum deposu **kimlik** taşır: `sessionKey` = `user:<id>` \| `guest` \| `anon` | `features/auth/authStore.ts` |
| 2 | Oturuma bağlı her sorgu `useSessionQuery` ile yazılır; anahtarın **sonuna** kimlik eklenir, `enabled` giriş koşuluyla VE'lenir | `shared/api/sessionQuery.ts` |
| 3 | Kimlik değişince önbelleğin tamamı boşaltılır | `app/SessionCacheSync.tsx` |

⛔ Oturuma bağlı bir uç nokta için doğrudan `useQuery` yazılmaz.

**Neden iki mekanizma birden.** Tek başına hiçbiri yetmiyor:

- Yalnız **anahtar kapsamı** → veri okunamaz ama bellekte kalır; çıkış
  yapan kullanıcının profili sekme kapanana kadar RAM'de durur.
- Yalnız **temizlik** → efekt render'dan sonra çalışır; arada bir kare
  boyunca yeni kimlik eski veriyle çizilebilir.

Kimlik anahtarın **sonuna** ekleniyor (`['anchors', 'user:42']`), çünkü
TanStack Query önek eşleştirir: mutasyonlardaki
`invalidateQueries({ queryKey: ['anchors'] })` çağrıları olduğu gibi
çalışmaya devam ediyor, kimlik taşımaları gerekmiyor.

**Neden `status` değil `sessionKey` dinleniyor.** Token yenilemesi de
`setSession` çağırır. `status` karşılaştırsaydık her yenilemede önbellek
boşuna düşer, kullanıcı 15 dakikada bir boş ekran görürdü. Bu davranış
`sessionScope.test.tsx` içinde ayrı bir testle korunuyor.

**Sonuçları.**

- `PropertiesMapView` ortak istemciye taşındı. Kendi `fetch`'ini kuruyor ve
  token'ı `localStorage.getItem('token')` ile okuyordu — **projede öyle bir
  anahtar yok** (access token bellekte, K-A). Her istek `Bearer ` (boş)
  gidiyor, 401 dönüyor, `response.ok` false olunca hata yutuluyor ve ekran
  sessizce boş kalıyordu.
- Onboarding kaydından sonra `['profile']` invalidate ediliyor; eskiden
  `/explore` `staleTime` dolana kadar "Profil bulunamadı" gösterebiliyordu.
- Mobil tarafta bu sınıf hata **yok**: `SessionController.logout()` zaten
  `profile` ve `personas`'ı sıfırlıyor, sunucu verisi ayrı bir önbellekte
  durmuyor.

---

## K-15
### Konut adresi yerel `streets` tablosundan üretilir; ters geokodlama yok

**Durum:** Kabul · 2026-08-25

**Bağlam.** `properties` tablosunda adres alanı **yok**. Sentetik konutlar
gerçek bina poligonlarının içine üretiliyor ([K-06](#k-06)) ama üretim
sırasında hiçbir adres bilgisi taşınmıyor. Kullanıcıya gösterebildiğimiz tek
konum bilgisi mahalle adıydı ("Kurtuluş") — bir kiralık ilanı için fazla
kaba, üstelik detay panelinde ve "en uygun evler" listesinde evi tarif eden
başka bir şey de yoktu.

**Değerlendirilen üç yol.**

| Yol | Sonuç |
|---|---|
| Sadece mahalle | Bedava ama yetersiz |
| Ters geokodlama (Nominatim / Photon) | **Reddedildi**, gerekçe aşağıda |
| Yerel `streets` tablosu + KNN | **Seçildi** |

**Ters geokodlama neden reddedildi.**

1. **Nominatim'in kullanım politikası bunu açıkça yasaklıyor.** Saniyede
   1 istek sınırı var ve *"bir veri kümesini sistematik olarak
   geokodlamak"* politika ihlali. 20 konutluk bir liste en iyi ihtimalle
   20 saniye sürerdi; 6.000 konutu önbelleğe almak ~100 dakika kesintisiz
   istek, yani IP yasağı demekti. Yasak **sunucu bazlı**: staging'de
   yenirse tüm ekip etkilenir ve `LocationSearch` (konum arama) aynı
   sağlayıcıya bağlı olduğu için **o özellik de birlikte ölür**.
2. **Photon daha gevşek ama garantisi yok** — ücretsiz topluluk servisi,
   SLA'sı yok.
3. **İstek anında dış servise bağımlılık.** Bugün `GET /properties/{id}`
   saf yerel sorgu, milisaniyeler. Ters geokod girseydi panelin açılma
   hızı başka bir ülkedeki sunucuya bağlanırdı.
4. **Zaten şema değişikliği gerektiriyordu.** Her tıklamada dış istek
   kabul edilemez olduğu için kalıcı bir önbellek tablosu + migration +
   yeni sağlayıcı arayüzü + throttle kuyruğu gerekirdi.
5. **Ve daha iyi bir cevap vermiyordu.** Nominatim'in Çankaya için
   döneceği sokak adı, `data/artifacts/cankaya.osm.pbf` dosyamızdaki
   **aynı OSM verisinden** geliyor.

**Karar.**

- `db/schema/012_add_streets.sql` — `streets` tablosu (adlı yol parçaları,
  GiST indeksli).
- `data/lua/vivido_streets.lua` + `data/scripts/05_load_streets.sh` — mevcut
  `.osm.pbf` kesitinden tek seferlik yükleme. **Tüm ETL yeniden koşmuyor**;
  Planetiler, OSRM ve konut üretimine dokunulmuyor, adım dakikalar sürüyor.
- Adres sorgu anında KNN ile bulunuyor: `ORDER BY s.geom <-> p.geom LIMIT 1`,
  `&&  ST_Expand(p.geom, 0.003)` (~330 m) ile sınırlı.

**Ölçülen sonuç:** 6.845 sokak parçası, 3.491 farklı ad, konutların
**%98,7'si** bir sokakla eşleşiyor. Kalan %80 konut mahalle adına düşüyor.

**Neden `ST_Distance` değil `<->`:** `ST_Distance` ile sıralamak GiST
indeksini **kullanmaz**, her konut için 6.845 satırın tamamı taranırdı.
KNN operatörü indeksten sırayla okuyup ilk satırda duruyor.

**Bedeli — açıkça yazıyorum.**

- Kurulum bir adım uzadı. **Atlanabilir:** `streets` boş kalırsa API adres
  alanını NULL döner ve arayüz mahalleye düşer — hata görünmez.
- `seed.sql` yeniden üretilirken `streets` de kapsanmalı, aksi halde
  release'ten kuran makinelerde tablo boş kalır.

**Kapı numarası bilerek YOK.** Sokak adı sentetik ilanı inandırıcı kılıyor
ve K-06'nın *"gerçek adreslerde sahte ilanlar"* ifadesiyle uyumlu; kapı
numarası ise gerçek bir konutu tekil olarak işaret ederdi.

---

## K-16
### Gerekçe tablosu skor motorunun İÇİNDEN üretilir

**Durum:** Kabul · 2026-08-25

**Bağlam.** W6 "skorun satır satır gerekçesi" istiyor. Detay paneli skoru
gösteriyordu ama **neden** o skor olduğunu göstermiyordu — ürünün tüm
iddiası açıklanabilirlik olduğu hâlde panel bir kara kutuydu.

Kolay yol, gerekçe satırlarını servis katmanında yeniden hesaplamaktı:
bozunum formülünü `PropertyScoreBreakdownService` içine ikinci kez yazmak.

**Karar.** Yazılmadı. Bunun yerine `ScoringEngine`'e
`CalculateBreakdown()` eklendi ve **`CalculateScore()` ona devrediyor**:

```csharp
public static double CalculateScore(IEnumerable<CategoryInput> inputs)
    => CalculateBreakdown(inputs).Total;
```

**Gerekçe.** İki kopya olsaydı motorun mantığı değiştiğinde tablo ile skor
**sessizce ayrışırdı**: kullanıcı "77 puan" görürken satırların toplamı 71
ederdi ve hiçbir test bunu yakalamazdı. Bu, [K-01](#k-01)'in şema için
uyardığı "iki doğruluk kaynağı" probleminin skorlama karşılığı.

Karar özellikle şu an önemli: skor motorunun mantığı **yakın zamanda
değiştirilecek**. Tek kaynak sayesinde formül değişince gerekçe tablosu
kendiliğinden takip eder; hiçbir arayüz kodu güncellenmez.

**Sonuçları.**

- `Vivido.Scoring` **saf kaldı** — yeni paket/proje referansı yok, kural
  bozulmadı. `CategoryInput`'a yalnızca varsayılanı olan bir `Code` alanı
  eklendi; mevcut çağıranlar değişmeden derleniyor.
- Yuvarlama **en sonda** yapılıyor: satır satır yuvarlanmış değerleri
  toplamak toplamı 8 kategoride ±0.04'e kadar kaydırıyordu.
- Arayüzdeki TOPLAM satırı `total`ı doğrudan basmıyor, **satır katkılarını
  topluyor** — backend tutarsızlığı ekranda anında görünür (W6 kuralı).

**Bütçe skorun parçası DEĞİL.** Mevcut motor yalnızca POI erişim
sürelerini hesaba katıyor. Bütçe uyumu panelde **ayrı ve açıkça etiketli**
bir bölüm; gerekçe satırlarının arasına karıştırılsaydı kullanıcı
"bütçem skorumu düşürmüş" gibi yanlış bir sonuç çıkarırdı. Motor bütçeyi
hesaba katmaya başlarsa burası bir gerekçe satırına dönüşür.
