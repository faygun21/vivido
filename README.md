# Vivido

**Kiralık ev bul · kişiselleştirilmiş skorla · gezilecek en kısa rotayı kur · telefonda navigasyonla gez.**

Başarsoft stajyer projesi · CBS tabanlı web + mobil uygulama · Pilot bölge: **Ankara Çankaya**

---

## 1. Kapsam Sözleşmesi

> ⛔ **Bu liste kapalıdır.** Yeni özellik fikirleri [`backlog/v2.md`](backlog/v2.md)'ye yazılır, sprint'e alınmaz.
> Kapsam şişmesi bu projedeki 1 numaralı risktir.

### Web uygulaması

| # | Gereksinim |
|---|---|
| **W1** | Kullanıcı kaydolur / giriş yapar |
| **W2** | Hazır **persona** listesinden birini seçer (6 arketip) ve aylık **kira bütçesini** girer |
| **W3** | Varsayılan görünüm: personaya göre **skoru yüksek kiralık evler** harita + listede |
| **W4** | Kullanıcı **düzenli gittiği yerleri (anchor)** ekler ve **önem sırasına dizer**; skor bu sıraya göre yeniden hesaplanır |
| **W5** | Her ev için tek bir **0–100 skor**; liste yüksek skorluların yanı sıra **düşük skorluları da içerir** |
| **W6** | Her ev için **skorun gerekçe tablosu**: neden uygun / neden uygun değil, satır satır puan katkısıyla |
| **W7** | Kullanıcı 2–8 ev seçer → sistem **en kısa ziyaret rotasını** üretir (açık TSP) → rota kaydedilir |

### Mobil uygulama

| # | Gereksinim |
|---|---|
| **M1** | Giriş yapar (web ile aynı hesap) |
| **M2** | Web'de oluşturulmuş **kayıtlı rotaları** listeler |
| **M3** | Rota seçilir → harita üzerinde **rota çizgisi + numaralı ev durakları** |
| **M4** | **Adım listeli navigasyon**: manevra kartı + canlı GPS takibi + otomatik adım ilerlemesi + rotadan sapma uyarısı |
| **M5** | Her durakta **ev skor kartı**, **"ziyaret ettim"** işaretleme |

### Kapsam DIŞI

Isochrone · toplu taşıma/GTFS · bisiklet modu · günlük yaşam senaryoları · konut karşılaştırma matrisi · zaman avantajı · kaydedilmiş aramalar · satılık konut · **sesli navigasyon** · **mobilde arama/filtreleme/rota oluşturma** · gerçek ilan verisi · offline çalışma · gerçek zamanlı trafik.

📖 Tam teknik tasarım: [`docs/01-PROJE-PLANI.md`](docs/01-PROJE-PLANI.md)
🧭 Uygulama sırasında verilen kararlar ve gerekçeleri: [`docs/02-KARARLAR.md`](docs/02-KARARLAR.md)

---

## 2. Hızlı Başlangıç

> ### ⚠️ ÖNCE BUNU OKU — klasör konumu
> Depoyu **OneDrive / Masaüstü / Belgeler altına KLONLAMA** ve yolda **Türkçe karakter kullanma**.
> - OneDrive `node_modules` içindeki on binlerce dosyayı senkronlamaya çalışır → git kilitlenir, `index.lock` hataları alırsın.
> - Yoldaki `ü`, `ı`, `ş` gibi karakterler Java (Planetiler), osmium ve Docker mount'larını bozar.
>
> ✅ Doğru: `C:\dev\vivido` &nbsp;&nbsp;❌ Yanlış: `C:\Users\ad\OneDrive\Masaüstü\vivido`

### 2.1 Araçları kur

```powershell
winget install --id Microsoft.DotNet.SDK.10 -e
winget install --id OpenJS.NodeJS.LTS       -e
winget install --id pnpm.pnpm               -e
winget install --id GitHub.cli              -e
dotnet tool install --global dotnet-ef
```

**Docker Desktop** ayrıca kurulu ve **çalışıyor** olmalı ([indir](https://www.docker.com/products/docker-desktop/)).
Kurulumdan sonra **terminali kapat-aç** (PATH yenilensin).

| Araç | Beklenen |
|---|---|
| `dotnet --list-sdks` | `10.x` |
| `node -v` | `v22` veya `v24` |
| `pnpm -v` | `11.x` |
| `gh --version` | herhangi |
| `docker info` | hata vermemeli |

### 2.2 Git ayarları (bir kez, herkes yapmalı)

```powershell
git config --global core.longpaths true
git config --global core.autocrlf input
git config --global init.defaultBranch main
git config --global pull.rebase true
```

`core.longpaths` olmadan `node_modules` derinliği yüzünden checkout hataları alırsın.

### 2.3 Depoyu kur ve çalıştır

```powershell
git clone https://github.com/faygun21/vivido.git C:\dev\vivido
cd C:\dev\vivido

copy .env.example .env      # gerekirse şifreleri düzenle
copy web\.env.example web\.env    # ⚠️ Vite .env'i web/ altından okur
pnpm install                # workspace bağımlılıkları
pnpm infra:up               # postgis + redis + pgadmin

pnpm db:migrate             # ⭐ ZORUNLU — şemayı kurar
pnpm dev:api                # → http://localhost:5000/swagger
pnpm dev:web                # → http://localhost:5173   (ayrı terminal)
```

> ⭐ **`pnpm db:migrate` atlanamaz.** Şema eskiden postgis konteyneri ilk
> açılışta kendiliğinden kuruluyordu; o mekanizma **kaldırıldı** çünkü
> sonradan eklenen şema dosyalarını sessizce "uygulandı" sayıp eksik şema
> üretiyordu ([K-12](docs/02-KARARLAR.md#k-12)).

**Doğrulama:** `curl http://localhost:5000/health/ready` → `Healthy`

Konut/POI verisini de istiyorsan: [`docs/04-MEVCUT-DURUM.md §3`](docs/04-MEVCUT-DURUM.md).

### 2.4 Ortak staging ortamı

**🔒 https://vividoapp.xyz** — ekibin tamamı buradan test eder, **SSH gerekmez.**

Tek veritabanı: bir bilgisayarda açılan hesapla başka bir cihazdan giriş
yapılabilir. Doğrulama e-postaları gerçekten gönderilir. Mobil uygulama da
buraya bağlanınca M1 ("web ile aynı hesap") gösterilebilir hale gelir.

Geliştirme staging'de yapılmaz — yerel kurulum aynen devam eder.
Kurulum, erişim modeli, deploy ve sorun giderme:
[`deploy/README.md`](deploy/README.md) · Karar: [K-11](docs/02-KARARLAR.md#k-11).

### 2.4b Mobil uygulama

Mobil **Flutter** ile yazılıyor ([K-08](docs/02-KARARLAR.md#k-08)) — Expo/React
Native terk edildi, `Expo Go` / dev client ayrımı gündemden düştü.

```powershell
flutter doctor              # yeşil olmalı (Android Studio + SDK gerekli, ~10 GB)
pnpm dev:mobile             # → cd mobile && flutter run
```

Fiziksel cihazda yerel API'ye bağlanacaksan telefon ve bilgisayar **aynı Wi-Fi**
ağında olmalı ve `mobile/lib/core/config/app_config.dart` içindeki adres
bilgisayarının yerel IP'si olmalı (`ipconfig` → IPv4). Daha kolayı: uygulamayı
staging adresine (`https://vividoapp.xyz/api/v1`) bağlamak — aynı ağda olma
zorunluluğu kalkar.

> ⚠️ Android 9+ düz HTTP'yi varsayılan olarak engelliyor. Release APK yalnızca
> **HTTPS** adrese bağlanabilir; `http://<IP>` yalnızca debug build'de çalışır.

### 2.5 E-posta doğrulama ve şifre sıfırlama

Kayıt olan kullanıcıya **6 haneli bir kod** gider; kod girilene kadar giriş
kapalıdır. "Şifremi unuttum" aynı mekanizmayı kullanır. Karar ve gerekçe:
[`docs/02-KARARLAR.md` K-09](docs/02-KARARLAR.md#k-09).

#### Geliştirme — kimlik bilgisi GEREKMEZ

Varsayılan `Email__Provider=console`: e-posta **gönderilmez**, kod
`pnpm dev:api` çalıştırdığın terminale basılır.

```
┌─ E-POSTA (gönderilmedi, Email:Provider=console) ─────────────
│ Kime : ornek@gmail.com
│ Konu : Vivido doğrulama kodun: 418305
├───────────────────────────────────────────────────────────────
Vivido doğrulama kodun: 418305
└───────────────────────────────────────────────────────────────
```

Kodu kopyalayıp forma yapıştır. Ekipteki herkes akışın tamamını böyle deneyebilir.

Doğrulama adımını tamamen kapatmak istersen `.env`:

```
Auth__RequireEmailVerification=false
```

#### Gerçek e-posta gönderimi — Gmail Uygulama Şifresi (~5 dakika)

> ### ⚠️ Gmail hesabının NORMAL ŞİFRESİ ÇALIŞMAZ
> Google 2022'den beri normal şifreyle SMTP girişini reddediyor
> (`535-5.7.8 Username and Password not accepted`).
> **16 haneli "Uygulama Şifresi" (App Password)** gerekiyor.
>
> Google Cloud projesi, Gmail API veya OAuth **gerekmiyor** — bu yol
> `System.Net.Mail` ile çalışır, ek NuGet paketi bile yok.

**Adım adım:**

| # | Ne yapacaksın | Nerede |
|---|---|---|
| 1 | **2 Adımlı Doğrulama'yı aç** (zorunlu ön koşul; kapalıyken uygulama şifresi menüsü hiç görünmez) | https://myaccount.google.com/signinoptions/twosv |
| 2 | **Uygulama Şifresi oluştur** — "Uygulama adı" kutusuna `Vivido` yaz, Oluştur'a bas | https://myaccount.google.com/apppasswords |
| 3 | Çıkan **16 haneli** değeri kopyala (`abcd efgh ijkl mnop`). Bu pencere bir daha açılmaz | — |
| 4 | Değeri **boşlukları silerek** aşağıdaki gibi tanımla | user-secrets ya da `.env` |

> ### ⚠️ Şifreyi nereye yazacağın, nasıl çalıştırdığına bağlı
> `dotnet run` depo kökündeki **`.env` dosyasını OKUMAZ** — o dosya yalnızca
> docker-compose içindir. `appsettings.Development.json` ise **git'te takipli**,
> oraya şifre yazılamaz.

**A) `pnpm dev:api` ile çalıştırıyorsan → user-secrets** (depo dışında durur):

```powershell
cd C:\dev\vivido
dotnet user-secrets --project api/src/Vivido.Api set "Email:Provider"    "smtp"
dotnet user-secrets --project api/src/Vivido.Api set "Email:User"        "senin.adresin@gmail.com"
dotnet user-secrets --project api/src/Vivido.Api set "Email:Password"    "abcdefghijklmnop"
dotnet user-secrets --project api/src/Vivido.Api set "Email:FromAddress" "senin.adresin@gmail.com"
```

**B) `docker compose --profile full` ile çalıştırıyorsan → `.env`:**

```dotenv
Email__Provider=smtp
Email__Host=smtp.gmail.com
Email__Port=587
Email__User=senin.adresin@gmail.com
Email__Password=abcdefghijklmnop        # 16 hane, BOŞLUKSUZ
Email__FromAddress=senin.adresin@gmail.com
Email__FromName=Vivido
```

API'yi yeniden başlat. Açılışta şunu görmelisin:

```
---> E-posta sağlayıcısı: smtp (smtp.gmail.com)
```

**Sınırlar ve tuzaklar**

| Sorun | Sebep / çözüm |
|---|---|
| `apppasswords` sayfası "kullanılamıyor" diyor | 2FA açık değil (adım 1) ya da hesap bir kurum/okul hesabı ve yönetici kapatmış |
| `535-5.7.8 Username and Password not accepted` | Normal şifre yazılmış ya da 16 hanenin arasındaki boşluklar silinmemiş |
| Günde 500 e-posta sonrası gönderim durur | Gmail kotası. Demo için fazlasıyla yeterli; aşılırsa `Email__Provider=console`'a dön |
| E-posta spam'e düşüyor | Gmail'den gönderilen otomatik postalarda olağan. Kullanıcıya "spam klasörüne de bak" diyoruz |

> ⛔ **Uygulama şifresini `appsettings.json`'a YAZMA** — o dosya git'e giriyor.
> Yalnızca `.env` (`.gitignore`'da) ya da ortam değişkeni.

**Google Cloud + Gmail API isterseniz:** aynı sonucu verir ama GCP projesi,
Gmail API etkinleştirme, OAuth consent screen ve refresh token üretimi
gerektirir. Geçiş yapılacaksa `IEmailSender` arayüzüne yeni bir implementasyon
yazmak yeterli — çağıran kodun hiçbir yeri değişmez
([K-09 gerekçe §4](docs/02-KARARLAR.md#k-09)).

---

## 3. Proje Yapısı

```
vivido/
├── api/                      .NET 10 · ASP.NET Core Web API
│   ├── src/
│   │   ├── Vivido.Api/            Controller, auth, Swagger
│   │   ├── Vivido.Application/    Use-case handler, DTO, validation
│   │   ├── Vivido.Domain/         Entity, value object
│   │   ├── Vivido.Infrastructure/ EF Core, OsrmClient, Redis
│   │   └── Vivido.Scoring/        ★ SAF skorlama motoru — I/O YOK
│   └── tests/
├── web/                      React 18 + TypeScript + Vite + MapLibre GL JS
├── mobile/                   Flutter + maplibre_gl (K-08)
├── packages/shared/          Ortak TS tipleri + üretilmiş API istemcisi
├── data/
│   ├── scripts/                   ETL kabuk betikleri
│   ├── lua/                       osm2pgsql flex şeması
│   ├── gen/                       Sentetik konut üretimi (Python)
│   └── artifacts/                 ~1 GB · git'te DEĞİL · Release'ten iner
├── db/
│   ├── schema/                    001_initial.sql — 13 tablo
│   └── checks/                    dq.sql — veri kalitesi kapıları
├── docs/
├── backlog/v2.md             Kapsam dışı fikirler
└── docker-compose.yml
```

### `Vivido.Scoring` kuralı

Bu projeye **hiçbir** dış paket referansı eklenmez — `DbContext`, `HttpClient`, `IMemoryCache` yok. Saf C#.
Girdi `ScoringInput`, çıktı `ScoreResult`. Bu sayede skorlama motoru veritabanı olmadan, milisaniyelerde, yüzlerce vaka ile test edilebilir. **Bu kural bozulursa altın veri seti koruması ölür.**

---

## 4. Günlük Komutlar

| Komut | Ne yapar |
|---|---|
| `pnpm dev:api` | API'yi başlatır → `:5000` |
| `pnpm dev:web` | Web'i başlatır → `:5173` |
| `pnpm dev:mobile` | Flutter uygulamasını çalıştırır (K-08) |
| `pnpm infra:up` / `infra:down` | Docker altyapısı |
| `pnpm infra:reset` | Volume dahil sıfırlar (**veri gider**) |
| **`pnpm db:migrate`** | **Şemayı kurar/günceller — kurulumda ZORUNLU** (K-12) |
| `pnpm db:check` | Veri kalitesi (DQ) sorgularını çalıştırır |
| `pnpm test` | Tüm testler |
| `pnpm test:golden` | Skorlama altın veri seti (72 vaka) |
| `pnpm typecheck` | TS tip kontrolü (tüm paketler) |

### Şema değişikliği eklerken

```bash
# db/schema/008_aciklayici_ad.sql        ← numara mevcut EN BÜYÜKTEN bir fazla
# Yalnızca DEĞİŞİKLİĞİ yaz (ALTER TABLE …), eski dosyaları DÜZENLEME
pnpm db:migrate
```

`migrate.sh` üç şeyi zorluyor: aynı numarayı iki kez kullanamazsın (`exit 2`),
uygulanmış bir dosyayı düzenleyemezsin (checksum, `exit 2`), şeması olup
defteri olmayan bir veritabanına sessizce baseline almaz (`exit 3`).
Dosyayı **yeniden adlandırmak güvenli** — içerik aynıysa checksum'dan tanır.

---

## 5. Veri Boru Hattı ve Artefaktları

Veri (DATA) ekibinin tamamladığı tüm ETL süreçleri, betikler ve dokümantasyon için bkz: [`data/README.md`](data/README.md)

OSRM grafikleri (`osrm/foot/`, `osrm/car/`), harita tile'ları (`cankaya.mbtiles`) ve veritabanı yedeği (`seed.sql`) toplam ~1 GB'tır ve **git'te tutulmaz**.
ETL **tek makinede bir kez** çalıştırılmıştır; çıktılar GitHub Release üzerinden indirilir.

```bash
./data/scripts/00_fetch_artifacts.sh    # gh release download ile hazır artefaktları indirir
pnpm infra:up                            # veritabanı, OSRM ve harita servisleri ayağa kalkar
```

Geliştirme makinende `osrm-extract` tekrar çalıştırmana gerek yoktur — hazır artefaktlar tek tıkla yüklenir.

---

## 6. Katkı

Branch kuralları, commit formatı ve PR süreci: [`CONTRIBUTING.md`](CONTRIBUTING.md)

Özet: `main` korumalı · her değişiklik PR ile · **1 onay** + CI yeşil zorunlu.

---

## 7. Lisans ve Atıf

Harita verisi © [OpenStreetMap](https://www.openstreetmap.org/copyright) katkıcıları — **ODbL 1.0**.
Bu atıf web ve mobil uygulamada harita üzerinde **görünür** olmak zorundadır.

Konut verisi **sentetiktir** (gerçek ilan değildir) ve arayüzde her yerde bu şekilde etiketlenir.
