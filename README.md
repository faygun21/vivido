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
pnpm install                # workspace bağımlılıkları
pnpm infra:up               # postgis + redis + pgadmin

pnpm dev:api                # → http://localhost:5000/swagger
pnpm dev:web                # → http://localhost:5173   (ayrı terminal)
```

**Doğrulama:** `curl http://localhost:5000/health/ready` → `{"status":"Healthy"}`

### 2.4 Mobil uygulama

> ### ⚠️ Expo Go ÇALIŞMAZ
> `@maplibre/maplibre-react-native` bir **native modüldür**. Expo Go uygulamasında harita hiç açılmaz.
> **Development build** gerekir — bir kişi üretir, ekip aynı APK'yı kurar.

```powershell
# APK zaten üretilmişse: telefonuna kur, sonra
pnpm dev:mobile             # → npx expo start --dev-client

# APK'yı sen üretecekesen (Android Studio + SDK gerekli)
cd mobile
npx expo prebuild --platform android
npx expo run:android
```

Fiziksel cihazda test: telefon ve bilgisayar **aynı Wi-Fi** ağında olmalı.
`.env` içindeki `EXPO_PUBLIC_API_BASE_URL` değerini bilgisayarının yerel IP'siyle güncelle (`ipconfig` → IPv4).
Şirket ağı cihaz izolasyonu yapıyorsa: `npx expo start --tunnel`

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
├── mobile/                   React Native + Expo + MapLibre
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
| `pnpm dev:mobile` | Expo dev server (dev client ile) |
| `pnpm infra:up` / `infra:down` | Docker altyapısı |
| `pnpm infra:reset` | Volume dahil sıfırlar (**veri gider**) |
| `pnpm db:migrate` | `db/schema` altındaki uygulanmamış SQL dosyalarını uygular |
| `pnpm db:check` | Veri kalitesi (DQ) sorgularını çalıştırır |
| `pnpm test` | Tüm testler |
| `pnpm test:golden` | Skorlama altın veri seti (180 vaka) |
| `pnpm typecheck` | TS tip kontrolü (tüm paketler) |

---

## 5. Veri Artefaktları

OSRM grafikleri, harita tile'ları ve seed SQL toplam ~1 GB'tır ve **git'te tutulmaz**.
ETL **tek makinede bir kez** çalıştırılır (16 GB RAM gerekir), çıktılar GitHub Release'e yüklenir.

```bash
./data/scripts/00_fetch_artifacts.sh    # gh release download ile indirir
pnpm infra:up                            # artık routing profili de çalışır
```

Kendi 8 GB'lık makinende `osrm-extract` çalıştırma — **OOM ile çöker.**

---

## 6. Katkı

Branch kuralları, commit formatı ve PR süreci: [`CONTRIBUTING.md`](CONTRIBUTING.md)

Özet: `main` korumalı · her değişiklik PR ile · **1 onay** + CI yeşil zorunlu.

---

## 7. Lisans ve Atıf

Harita verisi © [OpenStreetMap](https://www.openstreetmap.org/copyright) katkıcıları — **ODbL 1.0**.
Bu atıf web ve mobil uygulamada harita üzerinde **görünür** olmak zorundadır.

Konut verisi **sentetiktir** (gerçek ilan değildir) ve arayüzde her yerde bu şekilde etiketlenir.
