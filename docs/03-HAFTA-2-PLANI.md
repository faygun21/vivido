# Hafta 2 Çalışma Planı — Skor Motoru, Explore Ekranı, Flutter Mobil

> **7 kişi (4 backend · 3 frontend), 5 iş günü (Gün 6–10), çakışmadan.**
>
> Bu doküman [habi-v2-3-hafta-plan.md](../habi-v2-3-hafta-plan.md)'nin Hafta 2 bölümünü
> **kişi bazına** indirir. Takvim ve kapsam oradan gelir; kim neyi hangi gün yapacak buradan.
> Hafta 1'in beş kişilik düzeni için bkz. `vivido-calisma-duzeni.md`.
>
> Not: `habi` yazan dosyalar eski isimden kalma. Uygulamanın adı **Vivido**.

> ### ⚠️ Bu bir PLAN dokümanıdır, durum raporu değil
> Aşağıdaki "boş / yazılmadı" ifadeleri **plan yazıldığı andaki** (Gün 6)
> durumu anlatır. Bugün gerçekten nerede olduğumuz için tek doğru kaynak:
> **[04-MEVCUT-DURUM.md](04-MEVCUT-DURUM.md)**.
>
> Plandan sonra eklenen ve burada geçmeyen işler: e-posta doğrulama +
> şifre sıfırlama ([K-09](02-KARARLAR.md#k-09)), misafir modu
> ([K-10](02-KARARLAR.md#k-10)), staging ortamı
> ([K-11](02-KARARLAR.md#k-11)), favoriler, konum arama.

---

## 1. Hafta 2 milestone'u

**Bir ev için 0–100 skor + gerekçe tablosu gerçek veriyle üretiliyor, web'de `/explore` ekranı
canlı, anchor sırası değişince skor gözle görülür değişiyor (AK-W4).**

Hafta sonunda şunlar çalışıyor olmalı:

- Aynı ev, 4 farklı persona ile açıldığında **anlamlı şekilde farklı** skorlar alıyor
- `/explore` haritasında skor bandına göre renkli evler, yanında skora göre sıralı liste
- Ev detayında **gerekçe tablosu**: neden uygun / neden uygun değil, katkı toplamı skora eşit
- Anchor sırası sürükle-bırakla değişince liste yeniden yükleniyor ve skorlar değişiyor
- Mobilde web hesabıyla giriş yapılıyor, ev skor kartı **gerçek API'den** geliyor
- 72 vakalık altın veri seti ve I1–I8 değişmezlik testleri yeşil

---

## 2. Hafta 2'ye nereden giriyoruz

Hafta 1'in yazılım işleri bitmiş kabul edilir. Aşağıdaki tablo **kod taramasıyla doğrulanmış**
gerçek durumdur — plan dokümanlarının iddiası değil.

### Sağlam ve hazır

| Ne | Durum |
|---|---|
| `db/schema/001_initial.sql` | **16 tablonun tamamı** kurulu |
| `db/schema/002_seed_reference.sql` | 8 POI kategorisi + 4 persona + ağırlık matrisi + 25 tag eşlemesi |
| `db/checks/dq.sql` | DQ-01..06 tam; `error` seviyesinde `RAISE EXCEPTION` ile kapı |
| `db/migrate.sh` | Defter tablosu + checksum koruması (K-02), CI'da idempotenlik testli |
| CI | 4 workflow yeşil. `ci-api.yml` **EF migration yasağını** ve **Scoring saflığını** build kırarak zorluyor |
| `packages/shared` | 476 satır TS sözleşmesi. `score.ts`, `property.ts`, `route.ts` **zaten yazılı**; `anchorWeights()` `utils.ts`'te hazır |
| `web/src/shared/api/client.ts` | RFC 7807 ayrıştırma + **tek-uçuş 401→refresh→tekrar dene**, testli |
| MSW altyapısı | `auth`, `persona`, `profile` handler'ları çalışıyor |
| Auth backend | register / login / refresh, rotasyonlu, `problem+json` + `code` alanı |

### Boş — Hafta 2'nin işi

| Ne | Durum |
|---|---|
| `api/src/Vivido.Scoring/` | **Sıfır `.cs` dosyası.** Projenin kalbi hiç yazılmamış |
| `api/src/Vivido.Application/` | **Sıfır `.cs` dosyası.** İş mantığı `AuthController` içinde |
| EF entity'leri | 16 tablodan sadece 2'sinin (`users`, `refresh_tokens`) entity'si var |
| Test trait'leri | `Category=Golden` / `Category=Invariant` **hiçbir teste konmamış** — kapılar bugün boşa çalışıyor |
| Playwright | **Kurulu değil.** `web/package.json`'da `test:e2e` script'i yok |
| ~~`data/lua/`, `data/gen/`, `data/artifacts/`~~ | ✅ **TAMAMLANDI** — ETL koştu, `data-v1` release'i yayında |
| Mobil | ✅ Flutter'a geçildi (K-08); kod yazıldı ama **derlenip test edilmedi** |

---

## 3. Takım düzeni ve dosya sahipliği

> **Altın kural değişmiyor: bir dosyanın tek sahibi vardır.**
> Başkasının dosyasına ihtiyacın varsa ona söyle, kendin açma.

| Rol | Alanı | Sahip olduğu yollar |
|---|---|---|
| **BE-1** | Skor motoru — çekirdek | `api/src/Vivido.Scoring/**` |
| **BE-2** | Altın veri seti + değişmezlikler | `api/tests/Vivido.Scoring.Tests/**` |
| **BE-3** | Veri katmanı + `GET /properties` | `Vivido.Domain/Entities/**`, `Vivido.Infrastructure/**`, `db/fixtures/**` |
| **BE-4** | Orkestrasyon + `/properties/{id}/score` | `Vivido.Application/**`, `Vivido.Api/Controllers/PropertiesController.cs` |
| **FE-1** | Web: `/explore` harita + filtreler | `web/src/features/explore/**`, `web/src/mocks/handlers/property.ts`, `web/package.json` |
| **FE-2** | Web: liste + gerekçe tablosu + anchor→skor | `web/src/features/property/**`, `web/src/features/anchors/**` |
| **FE-3** | Flutter mobil | `mobile/**` |

**Ortak dosya, tek istisna:** `PropertiesController.cs` iki kişide (BE-3 arama, BE-4 skor).
Bunu ikiye bölün — `PropertiesController.cs` (BE-3) ve `PropertyScoreController.cs` (BE-4),
ikisi de `[Route("api/v1/properties")]`. Aynı dosyada iki kişi çalışmasın.

**Dokunulmayanlar:** `db/schema/**` (veri ekibi + PR onayı), `packages/shared/**` (değişiklik
ayrı ve küçük PR + iki onay — `vivido-api-sozlesmesi.md` §9).

---

## 4. Plandan sapmalar

Üç haftalık plana göre eklediğim ve çıkardığım işler — hepsi gerekçeli.

### Eklenenler

| # | Ne | Neden |
|---|---|---|
| 1 | **`db/fixtures/dev_seed.sql`** — ~300 konut + 3 mahalle + sahte erişim matrisi | Hafta 2'nin tamamı `property_poi_access` verisine bağlı ama ETL çıktısı henüz yok. Bu olmadan 4 backend kişisi Çarşamba'ya kadar bekler |
| 2 | **C# `ScoringInput`/`ScoreResult` sözleşme PR'ı — Gün 6 öğlene kadar** | Dört backend kişisi de bu tiplere bağlı. W1'de MSW web ekibini nasıl kurtardıysa, bu da backend'in içini paralelleştiren tek şey |
| 3 | **MSW `/properties` + `/properties/{id}/score` handler'ları** | W1'in kanıtlanmış deseni; web ekibi backend'i beklemez |
| 4 | **Flutter bootstrap + workspace/CI geçişi** | Stack değişikliğinin bedeli. 5 dosya güncellenmeli (§7 FE-3) |
| 5 | **`Category=Golden` / `Category=Invariant` trait altyapısı** | Kök `package.json` bu filtreleri çağırıyor ama hiçbir test trait taşımıyor — kapılar **bugün boşa çalışıyor** |
| 6 | **Playwright kurulumu** | E2E kabul kriterleri (AK-W3..W6) planda var ama araç kurulu değil |
| 7 | **Mimari borç: `Vivido.Application` katmanını aç** | İş mantığı `AuthController` içinde, `Infrastructure → Application` ters bağımlılığı var. Hafta 3'te rota + TSP aynı katmana oturacak; şimdi düzeltmek ucuz |
| 8 | **Flutter "hello map" duman testi — Gün 6'da bitmeli** | R1 riskinin Flutter karşılığı: harita gerçek cihazda Hafta 2'nin ilk gününde kanıtlanır |

### Çıkarılanlar / ertelenenler

| Ne | Neden |
|---|---|
| Redis + `score_cache` yazımı | 3-hafta planı zaten kesti. W2'de her istekte hesaplanır; sadece `IScoreCacheInvalidator` arayüzü bırakılır |
| `api/openapi.yaml` + `pnpm gen:api` | Sözleşme bugün `packages/shared` + `vivido-api-sozlesmesi.md` üzerinden yürüyor ve **çalışıyor**. İkinci doğruluk kaynağının W2'de getirisi yok → `backlog/v2.md` |
| Expo dev client / EAS APK (K-07) | Flutter doğrudan APK üretir. **K-08 kararı yazılmalı**, K-07 geçersiz |
| Mobil rota detay haritası (M3) | Hafta 3'e. W2'de sadece duman testi |
| `Poi` ve `Building` EF entity'leri | API bunlara hiç dokunmuyor (erişim matrisi precompute). Yazılmayan entity, şemayla ayrışamaz |
| Web `/route/new`, `/routes` sayfaları | Zaten Hafta 3 (W7) |

---

## 5. Bağımlılık zinciri — kim kimi bekliyor

```
Gün 6 öğlen   ScoringInput/ScoreResult   (BE-1 + BE-2)  →  BE-3 ve BE-4 açılır
Gün 6 öğlen   MSW property handler'ları  (FE-1)         →  FE-2 açılır
Gün 6 akşam   dev_seed.sql               (BE-3)         →  backend ETL'i beklemez
Gün 8         BE-1 motoru çalışır                       →  BE-4 orkestrasyonu tamamlar
Gün 8         Veri: 6.000 konut + erişim matrisi         →  BE-3 gerçek veriye geçer
Gün 9         BE-3 + BE-4 endpoint'leri yayında          →  FE-1 ve FE-2 MSW'yi kapatır
Gün 9         Veri: cankaya.mbtiles                      →  FE-1'in harita altlığı dolar
```

**Tek gerçek darboğaz: Gün 6 öğlenki iki sözleşme PR'ı.** İkisi de gecikirse 6 kişi boşta kalır.
Küçük tutun, tartışmayı PR'a değil sabah 15 dakikalık toplantıya sığdırın.

---

## 6. Backend — adım adım ilerleme haritaları

### BE-1 · Skor motoru çekirdeği

**Branch:** `feat/W2-skor-motoru` · **Kaynak:** `docs/01-PROJE-PLANI.md` §6

#### Gün 6 — Sözleşme, sonra kategori alt skoru

**Sabah, BE-2 ile birlikte (öğlene kadar merge):**

`api/src/Vivido.Scoring/` içine girdi/çıktı tipleri. `packages/shared/src/score.ts` alan adlarına
birebir uyacak — o dosya **zaten yazılı**, ona bak.

```
ScoringInput
  ├─ CategoryAccess[]   { code, durationMin, weight, tIdeal, tHalf, tCutoff, poiCount, minPoiCount }
  ├─ AnchorInput[]      { priority, label, durationMin, mode }
  ├─ decimal? monthlyRent, monthlyBudget
  └─ ScoringWeights     { lifeVsBudget, poiVsAnchor, rho }   ← DB'den, kodda sabit değil

ScoreResult
  ├─ decimal Total, ScoreBand Band
  ├─ ScoreRow[] Rows    { kind, code, label, measured, target, subScore, weight, contribution, loss, status }
  ├─ string[] Strengths, Weaknesses
  └─ string ScoringVersion
```

`ScoreRowKind`: `poi` · `ces_adjustment` · `anchor` · `budget` (TS tarafıyla aynı).

**Öğleden sonra — kategori alt skoru** (§6.2 Adım A):

```
        ┌ 100                                          , t ≤ t_ideal
s_c(t) =┤ 100 · 0.5^((t − t_ideal)/(t_half − t_ideal))  , t_ideal < t < t_cutoff
        └ 0                                            , t ≥ t_cutoff
```

Her aşamada `clamp(0, 100)`.

**Kabul:** `dotnet build api/Vivido.sln` yeşil, sözleşme PR'ı merge.

#### Gün 7 — CES birleştirme

```
POISkoru = ( Σ_c  w_c · s_c^ρ )^(1/ρ)     ,  ρ = −0.5
s_c alt sınırı = 1   ← 0 DEĞİL: bölme hatası ve tek sıfırın her şeyi öldürmesi engellenir
```

`min_poi_count` altındaki kategori **devre dışı**: satır tabloda "veri yetersiz" olarak kalır ama
ağırlığı kalan aktif kategorilere **oransal dağıtılır** (toplam yine 1.000 olmalı).

**Kabul:** `w_c = 1.0`, `s_c = 100` tek kategori → `POISkoru = 100`. Bir kategori 1, diğerleri 100
→ sonuç ağırlıklı toplamdan **belirgin şekilde düşük** (CES'in varlık sebebi bu).

#### Gün 8 — Anchor + bütçe bileşenleri

**Anchor ağırlığı** (§6.3) — geometrik azalan, normalize:

```
w_i = 0.5^(i−1) / Σ        →  3 anchor için  0.571 · 0.286 · 0.143
```

**Anchor mesafe → puan:**

```
a_j = 100                                  , T_j ≤ T_free
    = 100 · 0.5^((T_j − T_free)/T_half)    , T_free < T_j ≤ T_cutoff
    = 0                                    , T_j > T_cutoff

car  → T_free = 10 dk,  T_half = 15 dk,  T_cutoff = 60 dk
foot → T_free =  8 dk,  T_half = 12 dk,  T_cutoff = 45 dk

AnchorSkoru = Σ_j  w_j · a_j       ← ağırlıklı toplam (CES DEĞİL)
```

> **Kural:** *Altyapı eksikliği telafi edilemez (CES). Kullanıcı tercihi telafi edilebilir
> (ağırlıklı toplam).* Kategoriler CES ile, anchor'lar ağırlıklı toplamla birleşir.

**Bütçe** (§6.4) — asimetrik, parçalı:

```
        ┌ 100                              , r ≤ 0.70
B(r) = ┤ 100 − 40 · (r − 0.70)/0.30       , 0.70 < r ≤ 1.00
        └ 60 · 0.5^((r − 1.00)/0.10)       , r > 1.00
```

**Kabul:** `r=0.85 → 80`, `r=1.00 → 60`, `r=1.10 → 30`, `r=1.20 → 15`.

#### Gün 9 — Gerekçe satırları ⭐

**Tasarım kuralı: tablodaki tüm katkıların toplamı, gösterilen skora birebir eşit olmalı.**

```
POI kategorisi katkısı  = 0.70 × 0.50 × w_c × s_c   = 0.35 × w_c × s_c
CES düzeltmesi          = 0.35 × (POISkoru − Σ w_c·s_c)     ← negatif, AYRI SATIR
Anchor katkısı          = 0.35 × w_j × a_j
Bütçe katkısı           = 0.30 × B
Kayıp                   = maks_katkı − gerçek_katkı
```

CES doğrusal olmadığı için fark **açık bir satır** olarak gösterilir — "toplamı tutmayan tablo"
problemi böyle çözülür. `strengths` = katkısı en yüksek 4 satır, `weaknesses` = kaybı en yüksek 4
satır. Bir satır **her ikisinde de** olabilir (bütçe gibi) — bu doğrudur.

**Kabul:** `Σ Rows[].Contribution == Total` (±0.05) — bu I4, BE-2'nin testi bunu her vakada zorlar.

#### Gün 10 — Sınır durumları ve kapanış

| Durum | Davranış |
|---|---|
| Anchor yok | `YaşamSkoru = POISkoru`; anchor satırları yok; katkılar `0.70 × w_c × s_c` |
| Bütçe yok | `Skor = YaşamSkoru`; bütçe satırı yerine bilgi notu |
| Kategoride POI yok | `s_c = 0`, satır "❌ Bu kategoride yakında hiç yer yok" |
| Kategoride `< min_poi_count` | Kategori devre dışı, ağırlık oransal dağıtılır, "veri yetersiz" |
| Anchor'a rota yok | `a_j = 0` + uyarı; skoru sıfırlamaz |

`ScoringVersion = "1.0.0"`. BE-2'nin altın veri kırmızılarını kapat.

> ⛔ **`Vivido.Scoring`'e hiçbir `PackageReference` / `ProjectReference` eklenemez.**
> `api/Directory.Build.props` ve `ci-api.yml` build'i kırar. Ne EF, ne HttpClient, ne cache.
> Bütün parametreler `ScoringInput` içinde gelir — kodda sabit sayı yok.

---

### BE-2 · Altın veri seti ve değişmezlikler

**Branch:** `feat/W2-altin-veri-seti` · **Kaynak:** `docs/00-KAPSAM.md` §Değişmezlikler

**Neden ayrı kişi:** Motoru yazan kişi kendi testini yazarsa test, motoru değil kendini doğrular.
R2 riski ("skorlama sihirli sayı çorbasına döner, kimse 71'i açıklayamaz") ancak bağımsız yazılmış
altın veriyle kapanır.

#### Gün 6 — Sözleşme + test altyapısı

Sabah BE-1 ile sözleşme PR'ı. Sonra `api/tests/Vivido.Scoring.Tests/`:

- `UnitTest1.cs` stub'ını sil
- Trait altyapısı: `[Trait("Category", "Golden")]` ve `[Trait("Category", "Invariant")]`
- **Doğrula:** `pnpm test:golden` ve `pnpm test:invariant` gerçekten test topluyor mu?
  Bugün 0 test topluyorlar — kapılar boşa çalışıyor.

#### Gün 7 — Altın veri seti ⭐

`api/tests/Vivido.Scoring.Tests/golden/scores.json` —
**6 konut × 4 persona × 3 anchor senaryosu (0 / 2 / 3 anchor) = 72 vaka.**

Her vaka: girdi (erişim süreleri, anchor süreleri, kira, bütçe) + **elle hesaplanmış** beklenen
toplam skor (±0.5 tolerans).

> ### ⚠️ En büyük tuzak — bunu atlarsan 72 vakanın hepsi yanlış olur
>
> `docs/01-PROJE-PLANI.md` §6.5'teki dolu gerekçe tablosu örneği (71.0 puanlı Kurtuluş dairesi)
> **10 kategori / 6 persona** dönemine ait. Veritabanında **8 kategori / 4 persona** var (K-04).
> O tablodaki ağırlıkları (`transit 0.22`, `food 0.20` …) kopyalayamazsın.
>
> **Doğru kaynak: `db/schema/002_seed_reference.sql`.** Yeniden normalize edilmiş hâli:

| Persona | market | pharmacy | transit | food | park | gym | school | health |
|---|---|---|---|---|---|---|---|---|
| `student` | 0.165 | 0.071 | **0.259** | 0.235 | 0.082 | 0.129 | 0.000 | 0.059 |
| `family_kids` | 0.186 | 0.103 | 0.124 | 0.051 | 0.144 | 0.041 | **0.258** | 0.093 |
| `remote_worker` | 0.202 | 0.079 | 0.079 | **0.247** | 0.180 | 0.146 | 0.000 | 0.067 |
| `elderly` | **0.232** | **0.232** | 0.147 | 0.053 | 0.126 | 0.021 | 0.000 | 0.189 |

Eşikler de aynı dosyada: `market 4/10/25`, `pharmacy 4/9/22`, `transit 5/11/25`, `food 5/12/25`,
`park 5/12/28`, `gym 7/15/35`, `school 6/13/30`, `health 8/16/35`.

> `golden/**` **CODEOWNERS ile korunuyor.** Testi geçirmek için beklenen değeri değiştirmek yasak —
> değişiklik gerekiyorsa PR'da diff tablosu + gerekçe zorunlu.

#### Gün 8 — I1–I8 değişmezlik testleri

| # | Değişmezlik | Nasıl test edilir |
|---|---|---|
| I1 | Skor her zaman `[0, 100]` | Rastgele 10.000 girdi |
| I2 | Süre azalırsa skor artmalı veya aynı kalmalı | Aynı girdi, tek kategoride süreyi azalt |
| I3 | Tüm alt skorlar 100 + bütçe rahat → toplam 100 | Tek vaka |
| I4 | `Σ Rows[].Contribution == Total` (±0.05) | **Her altın vakada** |
| I5 | Anchor sırası değişince skor **değişmeli** | 3 anchor, permütasyon → farklı sonuç |
| I6 | Aynı girdi iki kez → bit-bit aynı çıktı | Determinizm |
| I7 | Anchor yokken skor = POISkoru (bütçesiz) | Tek vaka |
| I8 | Her persona için ağırlık toplamı 1.000 | 4 persona |

**I5 kritik:** R4 riski ("anchor sıralaması skoru anlamlı değiştirmiyor, W4 demoda etkisiz kalır")
bu testle korunuyor. Sadece "değişti mi" değil, **ne kadar değişti** de ölç — AK-W4 en az 5 puan
fark istiyor.

#### Gün 9 — Fuzz taraması

I1 (aralık) ve I2 (monotonluk) için rastgele girdi üretimi. Motor saf ve I/O'suz olduğu için
on binlerce vaka saniyeler içinde koşar — bu ayrıcalığı kullan.

#### Gün 10 — "Kodda sabit yok" testi + CI kapıları

Aynı girdiyi iki farklı `ScoringWeights` / eşik seti ile çalıştır → sonuç **değişmeli**.
Değişmiyorsa motor parametreyi yok sayıp içine sabit gömmüş demektir (R2).

`.github/workflows/ci-api.yml`'e Golden + Invariant kapılarını ekle.

**Kabul:** `pnpm test:golden` 72 vaka **< 1 saniye**, `pnpm test:invariant` I1–I8 yeşil.

---

### BE-3 · Veri katmanı ve `GET /properties`

**Branch:** `feat/W2-properties-arama` · **Kaynak:** `docs/01-PROJE-PLANI.md` §10, `00-KAPSAM.md` W3/W5

#### Gün 6 sabah — EF entity'leri

Sadece **4 entity** yaz. `Poi` ve `Building`'e API hiç dokunmuyor (erişim matrisi precompute) —
yazılmayan entity şemayla ayrışamaz.

| Entity | Tablo | Dikkat |
|---|---|---|
| `PoiCategory` | `poi_categories` | Eşikler ve `min_poi_count` buradan gelir |
| `Neighborhood` | `neighborhoods` | Sadece `id`, `name`, `rent_index` gerekli |
| `Property` | `properties` | `rent_per_m2` **salt-okunur** — `GENERATED ALWAYS AS STORED`, EF asla yazmamalı |
| `PropertyPoiAccess` | `property_poi_access` | Bileşik PK `(property_id, category_code)` |

`UseSnakeCaseNamingConvention()` zaten kurulu ama **tablo adlarını açıkça yaz**:
`builder.ToTable("properties")`.

Şema drift testini (`Category=Schema`) yeni DbSet'lerle genişlet — K-01'in bilinen riskini kapatan
tek şey bu.

#### Gün 6 öğleden sonra — `db/fixtures/dev_seed.sql` ⭐ **Bu gün bitmeli**

ETL bağımlılığını kesen bootstrap veri:

- 3 sahte mahalle (`neighborhoods`, basit poligon, `rent_index` 0.85 / 1.00 / 1.20)
- ~300 konut (`properties`, `is_synthetic = true`, Çankaya bbox içinde dağıtılmış,
  kira/alan/oda çeşitliliği skor bantlarının dördünü de üretecek şekilde)
- 300 × 8 = 2.400 satır `property_poi_access` (süreler 2–30 dk arası dağıtılmış)

> ⛔ **`db/schema/` altına KOYMA.** `migrate.sh` onu şema dosyası sanar, deftere yazar ve gerçek
> ETL verisi gelince çakışır. `db/fixtures/` altında yaşar, elle çalıştırılır, gerçek veri gelince
> `TRUNCATE` ile atılır.

```bash
docker compose exec -T postgis psql -U vivido -d vivido -f /db/fixtures/dev_seed.sql
```

`buildings` boş olduğu için `properties.building_id` NULL bırakılır — **DQ-01 bu fixture ile
çalıştırılmaz.** Fixture'ın başına bunu yorum olarak yaz.

#### Gün 7 — Sorgu katmanı

- bbox: `ST_MakeEnvelope(w, s, e, n, 4326)` + `ST_Intersects`, GiST indeksi kullanılıyor mu
  `EXPLAIN` ile doğrula
- Filtreler: `minRent`, `maxRent`, `minArea`, `maxArea`, `roomCount` (çoklu)
- ⭐ **Aday konutların erişim matrisini TEK sorguda çek.** Konut başına ayrı sorgu = N+1 =
  p95 hedefi (300 ms) uçar.

#### Gün 8 — `GET /properties` ⭐

```
GET /api/v1/properties?bbox=32.80,39.86,32.90,39.93
    &minRent=10000&maxRent=25000&roomCount=2%2B1,3%2B1
    &sort=score_desc&includeLowScores=true&page=1&limit=30
```

> ### ⚠️ Sıra kritik: **önce hepsini skorla → sonra sırala → sonra sayfala**
>
> Önce sayfalayıp sonra skorlarsan liste sıralaması yanlış olur ve AK-W3 kırılır. Filtreye uyan
> tüm konutlar (en fazla 6.000) bellekte skorlanır — 8 kategori × 6.000 = 48.000 satır, saf motor
> bunu ~50 ms'de bitirir. Cache yok, gerek de yok.

Yanıt: `items[]` (skor + bant + `topStrength` + `topWeakness`), `page`, `totalPages`, `totalCount`,
`scoreDistribution` (excellent / good / fair / poor).

`includeLowScores=false` → skoru **< 55** olan hiçbir ev dönmez (W5).

#### Gün 9 — Performans ve gerçek veriye geçiş

p95 < 300 ms ölç. Veri ekibinin 6.000 konutu geldiyse fixture'ı `TRUNCATE` edip gerçek veriye geç;
gelmediyse fixture ile devam et ve Cuma tekrar dene.

#### Gün 10 — Entegrasyon testleri

Testcontainers ile (`Vivido.Api.IntegrationTests`):

- **AK-W3:** `items[i].score >= items[i+1].score`; ilk sayfadaki evlerin **≥ %60'ının skoru ≥ 65**
- **AK-W5:** toggle açıkken skoru < 55 olan **en az 1 ev** var; kapalıyken **hiç yok**;
  `scoreDistribution` 4 bandın da sayısını dönüyor

---

### BE-4 · Orkestrasyon ve `/properties/{id}/score`

**Branch:** `feat/W2-skor-endpoint` · **Kaynak:** `docs/01-PROJE-PLANI.md` §6.5, §10

#### Gün 6 — `Vivido.Application` katmanını aç

Bugün bu proje **boş**. İki şey koy:

1. **`IScoringParameterProvider`** — `poi_categories` (eşikler, `min_poi_count`) +
   `persona_category_weights` (persona ağırlıkları) DB'den okur, süreç ömrü boyunca cache'ler.
   *Skor parametreleri koda gömülmez — R2'nin ana savunması bu.*
2. **`ScoringInputBuilder`** — konut + erişim matrisi + profil (persona, bütçe) + anchor listesi
   → `ScoringInput`. Anchor ağırlıkları burada **hesaplanmaz**, sıra bilgisi motora geçer;
   ağırlığı motor üretir (tek doğruluk kaynağı).

**Mimari borç, aynı PR'da:** `AuthController` içindeki iş mantığını Application'a taşı;
`Infrastructure → Application` ters bağımlılığını düzelt. Hafta 3'te TSP + rota aynı katmana
oturacak — şimdi düzeltmek yarım gün, sonra iki gün.

#### Gün 7 — `GET /properties/{id}/score`

Yanıt gövdesi `docs/01-PROJE-PLANI.md` §10'daki örnekle **birebir** ve
`packages/shared/src/score.ts` ile **alan-alan** uyumlu olmalı. FE-2 bu şekle karşı kod yazıyor.

Kimlik doğrulama zorunlu; profil yoksa **404 + `PROFILE_NOT_FOUND`**.

#### Gün 8 — AK-W4 backend tarafı ⭐

```gherkin
Given 3 anchor eklemiş bir öğrenciyim
When  PUT /profile/anchors/order ile spor salonunu 1. sıraya taşırım
Then  GET /properties YENİ skorları döner
 And  aynı evin liste skoru ile detay skoru EŞİTTİR
 And  gerekçe tablosunda spor salonunun ağırlığı 0.571'e yükselmiştir
```

**R6 riski (skor tutarsızlığı):** aynı ev listede 71, detayda 78 görünmesi. Cache yazmadığımız için
W2'de bu risk düşük — ama testi **şimdi** yaz, Hafta 3'te cache girerse koruma hazır olur.
`IScoreCacheInvalidator` arayüzünü tanımla, implementasyonu `NoOp` bırak.

#### Gün 9 — Sözleşme ve hata standardizasyonu

- W2 endpoint'leri için `problem+json` + `code` alanı
- Swagger'a örnek gövdeler
- ⭐ **`vivido-api-sozlesmesi.md`'ye W2 bölümü ekle** — `GET /properties` ve
  `GET /properties/{id}/score`. Sözleşme değişikliği kuralı (§9): küçük ayrı PR, **iki onay**
  (backend + FE-1), ekibe duyuru.

#### Gün 10 — Sınır durumu ve AK-W6

- `min_poi_count` "veri yetersiz" yolu uçtan uca (kategori devre dışı, ağırlık dağıtıldı, satır
  tabloda notla görünüyor)
- **AK-W6 entegrasyon testi:** `Σ rows[].contribution == total` (±0.05), `strengths` ≥ 3 satır,
  `weaknesses` ≥ 1 satır, her satırda `measured/target/subScore/weight/contribution` dolu,
  anchor satırları öncelik sırasında, CES düzeltmesi ayrı satır

---

## 7. Frontend — adım adım ilerleme haritaları

### FE-1 · Web: `/explore` harita ve filtreler

**Branch:** `feat/W3-explore-harita` · **Kaynak:** `docs/01-PROJE-PLANI.md` §11.2, §11.4

#### Gün 6 sabah — MSW handler'ları ⭐ **öğlene kadar merge** (FE-2 bekliyor)

`web/src/mocks/handlers/property.ts`:

- `GET /properties` — ~40 sahte konut, **skorlar dört banda da yayılmış** (85+ / 70–84 / 55–69 / <55),
  `scoreDistribution` tutarlı, sayfalama çalışıyor, `includeLowScores` filtresi uygulanıyor
- `GET /properties/{id}/score` — §10'daki gövdeyle birebir, **katkı toplamı `total`'a eşit olacak
  şekilde** (yoksa FE-2 tabloyu yanlış toplarken fark edemez)

> Gövdeleri uydurma. `packages/shared/src/property.ts` ve `score.ts` **zaten yazılı** — tipler
> oradan import edilir, MSW fixture'ı derleme zamanında doğrulanır.

#### Gün 6 öğleden sonra — MapLibre bileşeni

- `attributionControl` ile **`© OpenStreetMap katkıcıları`** — ODbL yükümlülüğü, opsiyonel değil
- Tile yoksa boş altlık + açıklayıcı uyarı (mbtiles Gün 9'da gelecek, o güne kadar normal)

#### Gün 7 — Nokta katmanı

| Zoom | Render |
|---|---|
| `z < 13` | `cluster: true`, `clusterRadius: 55`, rozet üzerinde ev sayısı |
| `z ≥ 13` | Tekil nokta, skor bandına göre renk |

Bantlar: **85+** / **70–84** / **55–69** / **< 55**. Vector tile gerekmez — 6.000 nokta GeoJSON
olarak sorunsuz çizilir (§11.4, bilinçli sadeleştirme).

#### Gün 8 — Filtre paneli

Kira / m² / oda tipi slider'ları, bbox → URL senkronu (paylaşılabilir link), TanStack Query +
debounce (harita her piksel oynadığında istek atma), `includeLowScores` toggle — **varsayılan açık** (W5).

#### Gün 9 — Gerçek API'ye geçiş + Playwright kurulumu

- MSW `property` handler'ını kapat, gerçek `/properties`'e bağlan
- `scoreDistribution` mini çubuğu sonuç başlığında
- Seçili ev pin'leri (numaralı) — Hafta 3'ün rota seçimi buna oturacak
- ⭐ **Playwright kur** (`web/package.json`'a `test:e2e`) — bugün kurulu değil, kabul kriterleri
  buna bağlı

#### Gün 10 — Cilalama ve E2E

- Boş / hata / yükleniyor durumları
- ⭐ **"Sentetik veri" rozeti** — her ev kartında ve detayda. K-06 dürüstlük kuralı, pazarlığa kapalı
- Playwright: **AK-W3** (azalan sıralı, ≥%60'ı ≥65, her kartta sayısal skor + renk bandı) ve
  **AK-W5** (toggle davranışı)

---

### FE-2 · Web: liste, gerekçe tablosu, anchor→skor

**Branch:** `feat/W6-gerekce-tablosu` · **Kaynak:** `docs/01-PROJE-PLANI.md` §11.3

#### Gün 6 — Ev kartı ve sonuç listesi

FE-1'in MSW'sine karşı çalış (öğleden sonra hazır olacak; sabah saf bileşenleri yaz).

Ev kartı: sayısal skor + renk bandı şeridi + mahalle · oda · m² + kira + `topStrength` (✓) +
`topWeakness` (✗) + seçim kutusu (Hafta 3 rota için).

Liste: skora göre azalan sıralı, sayfalama.

#### Gün 7 — `/property/:id` ve gerekçe tablosu

```
┌─ Bu ev size neden 71 puan aldı? ────────────────────────────┐
│  ✅ NEDEN UYGUN                    ❌ NEDEN UYGUN DEĞİL      │
│  Bütçe uyumu        +21.0         Bütçe uyumu        −9.0   │
│  Hacettepe Beytepe  +11.5         Hacettepe Beytepe  −8.5   │
│  Spor salonu        +9.5          Aile evi           −3.4   │
│  Toplu taşıma       +7.7          Denge cezası       −2.4   │
│                                                             │
│  [ Tüm kriterleri göster ▾ ]                                │
│  Kriter │ Ölçülen │ Hedef │ Puan │ Katkı                    │
│  …                                                          │
│  TOPLAM                                    71.0             │
└─────────────────────────────────────────────────────────────┘
```

- Router'a `/property/:id` ekle (`web/src/app/router.tsx` — FE-1'in dosyası, **ona söyle**)
- Bir satır **her iki listede de** görünebilir (bütçe gibi) — bu doğrudur, gizleme
- **CES dengesizlik düzeltmesi satırı görünür olmalı**, gizlenmiş bir düzeltme açıklanabilirliği öldürür
- Tam tablonun altındaki TOPLAM, satır katkılarının toplamı olarak **hesaplanarak** yazılsın —
  `total`'ı doğrudan basma. Böylece backend tutarsızlığı UI'da anında görünür

#### Gün 8 — Anchor sırası → skor bağlama ⭐ **Haftanın en kritik işi**

W4 ürünün en çarpıcı etkileşimi. Anchor paneli Hafta 1'de yazıldı; eksik olan **skor tepkisi**.

1. dnd-kit ile sıra bırakıldığı anda `PUT /profile/anchors/order`
2. 200 dönünce `properties` **ve** açık `property/:id` sorgularını invalidate et
3. Liste ve detay skorları yeniden yüklenir — kullanıcı sıranın etkisini **anında** görür
4. Her anchor'ın yanında ağırlığını göster: **0.571 · 0.286 · 0.143**

> ⛔ `anchorWeights()` **`packages/shared/src/utils.ts`'te zaten yazılı.** Yeniden yazma, import et.

**Kabul (AK-W4):** 200 döner · 3 saniye içinde liste yeniden yüklenir · bir evin skoru **en az
5 puan** değişir · gerekçe tablosunda 1. anchor'ın ağırlığı 0.571.

#### Gün 9 — Gerçek API'ye geçiş

MSW'yi kapat. ⭐ **Doğrula: aynı evin liste skoru == detay skoru** (R6). Eşit değilse bu bir
frontend hatası değil, backend'e bildirilecek bir tutarsızlıktır — BE-4'e yaz.

#### Gün 10 — E2E

Playwright (FE-1 Gün 9'da kuruyor):

- **AK-W4** — projenin en kritik testi: sürükle-bırak → 200 → yeniden yükleme → skor farkı ≥ 5
- **AK-W6** — gerekçe tablosundaki katkıları topla, gösterilen skora eşit mi (±0.05)

---

### FE-3 · Flutter mobil, sıfırdan

**Branch:** `feat/M1-flutter-bootstrap` · **Kaynak:** `docs/01-PROJE-PLANI.md` §8,
`vivido-api-sozlesmesi.md`

> **Stack değişikliği.** Mevcut `mobile/` Expo/React Native şablonu terk ediliyor. `App.tsx`
> boilerplate'ten öteye gitmediği için kaybedilen iş yok.

#### Gün 6 — Bootstrap ⭐ **Bu gün bitmeli**

**Beş dosya güncellenecek:**

| Dosya | Değişiklik |
|---|---|
| `mobile/` | Expo dosyalarını kaldır, `flutter create` |
| `pnpm-workspace.yaml` | `- 'mobile'` satırını çıkar; `minimumReleaseAgeExclude` altındaki Expo satırlarını sil |
| `package.json` (kök) | `dev:mobile` → `cd mobile && flutter run`; `test:mobile` → `cd mobile && flutter test` |
| `.github/workflows/ci-mobile.yml` | pnpm/jest → `flutter analyze` + `flutter test` |
| `.github/CODEOWNERS` | `mobile/** @<FE-3>` satırı ekle |

**Ortam:** Android Studio + Android SDK kurulu, `flutter doctor` yeşil.

⭐ **`maplibre_gl` "hello map" gerçek Android cihazda açılıyor — bu gün kanıtlanacak.**
Bu, R1 riskinin ("mobil ekip haftalarca kurulumla boğuşur") Flutter karşılığıdır. Hafta 3'te
keşfedilirse iki gün kaybedilir; bugün keşfedilirse iki saat.

**`docs/02-KARARLAR.md`'ye K-08 yaz:** *"Mobil uygulama Flutter ile yazılır; K-07 (EAS dev client)
geçersizdir."* Gerekçe: Flutter native modülleri doğrudan APK'ya derler, ayrı dev client kabuğu
gerekmez; Expo Go / dev client ayrımı ortadan kalkar. Karşı durum: Android SDK yerel kurulum
gerektiriyor (~10 GB) — K-07'nin kaçındığı maliyet bu, artık ödeniyor.

#### Gün 7 — Sözleşme modelleri ve HTTP istemcisi

**Dart modelleri** — `packages/shared/src/*.ts`'in birebir karşılığı. Doğruluk kaynağı TS
dosyaları ve `vivido-api-sozlesmesi.md`; Dart onları **yansıtır**, kendi sözleşmesini kurmaz.

`auth.dart` · `profile.dart` · `property.dart` · `score.dart` · `route.dart` (`json_serializable`).

**Dio istemcisi + interceptor:**

```
1. login / register   →  accessToken (15 dk) + refreshToken (14 gün)
2. Her istekte        →  Authorization: Bearer <accessToken>
3. 401                →  /auth/refresh  →  YENİ ikili  →  isteği tekrarla
4. refresh de 401     →  token'ları temizle  →  login ekranına
```

> ⭐ **Tek-uçuş refresh zorunlu (K-E).** Aynı anda 5 istek 401 alırsa **5 kez refresh çağrılmaz** —
> biri çağırır, diğerleri onun `Future`'ını bekler. Refresh rotasyonlu olduğu için ikinci çağrı
> iptal edilmiş token gönderir, `TOKEN_REVOKED` alır ve kullanıcı sebepsiz çıkış yer.
> Web'de aynı sorun çözüldü — `web/src/shared/api/client.ts` referans alınabilir.

Token saklama: `flutter_secure_storage`.

#### Gün 8 — Login ekranı (M1)

**Gerçek API'ye bağlı** — web ile aynı hesap, ayrı kullanıcı tablosu yok. `go_router` + oturum
önyükleme (uygulama açılışında saklı refresh token ile sessiz giriş).

Yönlendirme mantığı web ile aynı: `GET /profile` → 404 ise onboarding uyarısı ("profilini web'de
oluştur"), 200 ise ana ekran. Mobilde onboarding **kapsam dışı** (§2.3).

**Kabul (M1):** Web'de kayıt olunan hesapla mobilde giriş yapılıyor, token akışı çalışıyor.

#### Gün 9 — Rota listesi (M2) ve ev skor kartı

- **Rota listesi:** `GET /routes` Hafta 3'te gelecek → fixture'dan besle. Ekran hazır olsun,
  Hafta 3'te tek satır değişsin (ad, tarih, ev sayısı, toplam süre)
- **Ev skor kartı:** `GET /properties/{id}/score`'a **gerçek** bağlı — BE-4 Gün 7'de yayınladı.
  Skor + bant + gerekçe tablosunun özeti (güçlü 3 / zayıf 3 satır) + **"Sentetik veri" rozeti**

#### Gün 10 — Hafta 3'ün saf mantığını öne çek ⭐

Hafta 3'te navigasyonun tamamı tek güne yığılı. Bu iki dosya **API'siz, haritasız, GPS'siz,
telefonsuz** yazılabilir — bugün yazılırsa Hafta 3'te iş "test edilmiş mantığı ekrana bağlamak"a iner.
**Projenin en büyük zamanlama riskini düşüren adım budur.**

**`lib/navigation/maneuver_text.dart`** — saf fonksiyon, OSRM `type` + `modifier` → Türkçe.
Eşleme tablosu `docs/01-PROJE-PLANI.md` §8.1'de hazır. Bilinmeyen kombinasyon → **"Devam edin"**.
Tablo testi: tüm `type × modifier` kombinasyonları.

**`lib/navigation/step_machine.dart`** — saf, I/O'suz durum makinesi:

```
Girdi:  { steps[], routeLine, currentPosition, currentStepIndex }
Çıktı:  { activeStepIndex, distanceToManeuverM, offRoute, arrivedAtStop }

1. Konum rota çizgisine izdüşürülür (nearest point on line)
2. Aktif adımın manevra noktasına kalan mesafe hesaplanır
3. Kalan mesafe  < 15 m  →  sonraki adıma geç
4. Durak noktasına < 30 m →  arrivedAtStop = true
5. Rota çizgisine dik mesafe > 50 m  →  offRoute = true
```

> Sapma tespiti bu planda **basitleştirildi**: orijinal "3 ardışık ölçüm" kontrolü yerine tek eşik.
> Üç haftalık planın kesme listesinde bu karar var; "3 ardışık" v2 backlog'a gitti.

**Kabul:** `cd mobile && flutter test` yeşil, telefon gerekmeden.

> ### ⚠️ Risk: M1–M5'in tamamı tek kişide
> Hafta 3'te navigasyon, rota detay haritası ve saha testi aynı kişide birikiyor.
> **Hafta 3 planında FE-2'nin mobile kayması öngörülmeli.** Bu, Hafta 2 sonunda karara bağlanacak.

---

## 8. Veri ekibi — yazılımın beklediği teslimler

ETL tek makinede koşuyor (kurulumlar yapıldı). Yazılım tarafı için **kritik yol** budur.

| Gün | Teslim | Kimi açar |
|---|---|---|
| 6 | Erişim matrisi KNN ön-eleme (kategori başına en yakın 5 aday) | — |
| 7 | OSRM foot + car build; `/table` ile gerçek yürüme süreleri → `property_poi_access` | BE-3, BE-4 |
| **8** | **6.000 sentetik konut + kira modeli kalibrasyonu (TÜİK/TCMB ±%15)** | ⭐ Haftanın kilit teslimi |
| 9 | Planetiler → `cankaya.mbtiles` → tileserver ayakta | FE-1 (harita altlığı) |
| 10 | `data-v1` GitHub release yayınla + "vitrin evleri" seç | Tüm ekip |

✅ **`data-v1` release'i yayınlandı**, `data/scripts/00_fetch_artifacts.sh` çalışır durumda.

> ✅ **Not (2026-08-23):** Bu bölümdeki veri teslimlerinin tamamı bitti —
> `vivido_pois.lua`, `gen_properties.py`, OSRM grafları, `cankaya.mbtiles` ve
> `seed.sql` üretildi, `data-v1` olarak yayınlandı. Doğrulanmış çıktılar:
> 6.239 POI · 40.706 bina · 124 mahalle · 6.000 konut · 48.000 erişim satırı.

### Çarşamba (Gün 8) sonu kapısı — yedek plan

`property_poi_access` gerçek veriyle dolu değilse:

1. Backend `db/fixtures/dev_seed.sql` ile **devam eder**, beklemez
2. Cuma günü tek `TRUNCATE` + yeniden yükleme ile geçiş yapılır
3. Skor motoru zaten saf ve veriden bağımsız — altın veri seti etkilenmez

**Bu yüzden BE-3'ün Gün 6 fixture işi pazarlığa kapalıdır.**

---

## 9. Hafta 2 yasak listesi

| Yapma | Neden | Onun yerine |
|---|---|---|
| `dotnet ef migrations add` | `ci-api.yml` build'i kırar (K-01) | `db/schema/003_*.sql` + `pnpm db:migrate` |
| `Vivido.Scoring`'e paket / proje referansı | `Directory.Build.props` + CI kırar | Girdiyi `ScoringInput` içinde taşı |
| `Database.EnsureCreated()` / `Migrate()` | Sessizce ikinci şema kaynağı | Hiç çağırma |
| `001_initial.sql` veya `002_seed_reference.sql`'i düzenlemek | Checksum uyuşmaz, `migrate.sh` **exit 2** | Yeni numaralı dosya |
| `dev_seed.sql`'i `db/schema/` altına koymak | `migrate.sh` onu şema sanar, gerçek veriyle çakışır | `db/fixtures/` |
| Skor parametrelerini koda gömmek | R2; BE-2'nin "kodda sabit yok" testi yakalar | `poi_categories` + `persona_category_weights`'ten oku |
| §6.5 örnek tablosundaki ağırlıkları altın veriye kopyalamak | 10 kategori / 6 persona dönemine ait (K-04) | `002_seed_reference.sql` — §6'daki tablo |
| Sayfaladıktan sonra skorlamak | Liste sıralaması bozulur, AK-W3 kırılır | Önce skorla → sırala → sayfala |
| `anchorWeights()`'i TS veya Dart'ta yeniden yazmak | `packages/shared/src/utils.ts`'te yazılı | Import et / birebir port et |
| Anchor sıralamasında döngü içinde `SaveChanges()` | `DEFERRABLE` avantajı kaybolur, kısıt ihlali | Tek `SaveChanges()` |
| MSW fixture'ında alan adı uydurmak | Gerçek API'ye geçince sessizce kırılır | `packages/shared` tiplerini import et |
| ~~`00_fetch_artifacts.sh` çalıştırmak~~ | ✅ Release yayınlandı, betik çalışıyor | — |
| Başkasının dosyasını açmak | Çakışma | Sahibine söyle (§3) |

---

## 10. Branch, PR ve merge akışı

```
feat/W2-skor-motoru           BE-1
feat/W2-altin-veri-seti       BE-2
feat/W2-properties-arama      BE-3
feat/W2-skor-endpoint         BE-4
feat/W3-explore-harita        FE-1
feat/W6-gerekce-tablosu       FE-2
feat/M1-flutter-bootstrap     FE-3
```

Commit mesajı — küçük harf, emir kipi, Türkçe:

```
feat: CES birleştirme ve kategori alt skoru
fix: liste skoru ile detay skoru uyuşmuyordu
test: I5 anchor sırası değişmezliği
```

Tip listesi: `feat` · `fix` · `data` · `docs` · `chore` · `test` · `refactor`

**Kurallar:**

1. **Küçük PR, günlük merge.** Bir PR 2 günden fazla açık kalmasın
2. PR: **1 onay** + CI yeşil
3. `packages/shared` değişikliği: ayrı küçük PR + **iki onay** (backend + FE-1) + duyuru
4. Bağımlılık kurmak web'de **FE-1'in** işi (`pnpm-lock.yaml` çakışması en sinir bozucu olanıdır)
5. Her sabah güncelle:

```powershell
git switch yazilim
git pull
git switch feat/W2-skor-motoru
git rebase yazilim
```

---

## 11. Hafta 2 sonu kabul kapıları (Cuma, merge öncesi)

```powershell
pnpm test:golden                                          # 72 altın vaka < 1 sn
pnpm test:invariant                                       # I1-I8
dotnet test api/Vivido.sln --filter Category=Schema       # şema drift
pnpm test:api                                             # entegrasyon dahil
pnpm test:web                                             # Vitest
pnpm --filter web test:e2e                                # Playwright: AK-W3/W4/W5/W6
cd mobile; flutter analyze; flutter test                  # maneuverText + stepMachine
pnpm db:check                                             # DQ-01..06
```

### Elle doğrulama — milestone kanıtı

- [ ] Aynı evi 4 persona ile aç → skorlar **anlamlı şekilde** farklı
- [ ] Anchor sırasını sürükle-bırakla değiştir → **3 sn içinde** liste yeniden yüklenir,
      bir evin skoru **≥ 5 puan** değişir
- [ ] Gerekçe tablosundaki katkıları elle topla → gösterilen skora eşit (±0.05)
- [ ] CES dengesizlik düzeltmesi tabloda **ayrı satır** olarak görünüyor
- [ ] "Düşük skorlu evleri göster"i kapat → skoru < 55 hiç ev dönmüyor
- [ ] Aynı evin **liste skoru == detay skoru**
- [ ] Her ev kartında ve detayında **"Sentetik veri" rozeti** var
- [ ] Haritada `© OpenStreetMap katkıcıları` atıfı görünüyor
- [ ] Mobilde web hesabıyla giriş yapılıyor, ev skor kartı gerçek API'den geliyor
- [ ] `api/` altında `Migrations/` klasörü **yok**
- [ ] `GET /properties` p95 **< 300 ms**, `GET /properties/{id}/score` **< 250 ms**

---

## 12. Hafta 3'e devreden riskler

| # | Risk | Durum | Hafta 3'te ne yapılacak |
|---|---|---|---|
| **R-A** | M1–M5'in tamamı tek kişide (FE-3) | **Açık** | FE-2'nin mobile kayması Hafta 2 sonunda karara bağlanmalı |
| **R-B** | ETL gecikirse skorlar sentetik fixture'a dayanır | Yedek plan var (§8) | Cuma geçiş yapılmadıysa Hafta 3 Pazartesi ilk iş |
| **R-C** | `score_cache` yazılmadı, her istekte hesap | **Bilinçli** (Redis kesildi) | Ölçüm 300 ms'i aşarsa cache Hafta 3'e alınır |
| **R-D** | `api/openapi.yaml` yok, sözleşme elle senkron | **Bilinçli** | `backlog/v2.md`; iki taraf da `vivido-api-sozlesmesi.md`'ye uyduğu sürece sorun yok |
| **R-E** | Web ve Flutter'da iki ayrı HTTP istemcisi (tek-uçuş refresh iki kez yazıldı) | Kaçınılmaz | İkisi de aynı sözleşmeye uyuyor; testleri ayrı |
| **R4** | Anchor sıralaması skoru anlamlı değiştirmiyor | I5 testi + AK-W4 E2E ile korunuyor | Demo için "vitrin evleri" veri ekibinden gelecek |

---

## İlgili dokümanlar

| Dosya | Ne var |
|---|---|
| [00-KAPSAM.md](00-KAPSAM.md) | **Kabul kriterleri** — işin "bitti" sayılma şartı, I1–I8, DQ-01..06 |
| [01-PROJE-PLANI.md](01-PROJE-PLANI.md) | Teknik tasarım — §6 skorlama, §8 mobil navigasyon, §10 API, §11 web UI |
| [02-KARARLAR.md](02-KARARLAR.md) | K-01 (EF yasağı), K-04 (4 persona / 8 kategori), K-06 (sentetik veri), K-08 (Flutter) |
| [habi-v2-3-hafta-plan.md](../habi-v2-3-hafta-plan.md) | 3 haftalık takvim (dosya adı eski isimden) |
| `vivido-api-sozlesmesi.md` | API sözleşmesi — hata kodları, token akışı, sözleşme değiştirme kuralı |
| `vivido-backend-temel-katman.md` | Hafta 1 backend rehberi — entity/EF/JWT tuzakları |
| `db/schema/002_seed_reference.sql` | **Skor parametrelerinin doğruluk kaynağı** |
| [CONTRIBUTING.md](../CONTRIBUTING.md) | Branch, commit, PR kuralları |
