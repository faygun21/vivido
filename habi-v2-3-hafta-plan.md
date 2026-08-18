# Habi v2 — 3 Haftalık (15 İş Günü) Sıkıştırılmış Plan

Orijinal plan 8 haftaydı. Bu doküman aynı kapsam sözleşmesini (§02) koruyarak MVP çekirdeğini
(**W2 W3 W4 W6 W7 · M3 M4**) 3 haftaya sığdırır. Kesilenler, projenin kendi "Kesme sırası"na
(§14) sadıktır — sırayla:

| Kesilen | Neden |
|---|---|
| pet + bank kategorileri | 10 → 8 POI kategorisi, erişim matrisi %20 küçülür |
| Persona 6 → 4 | student · family_kids · remote_worker · elderly kalır |
| Anchor maks 5 → 3 | formül aynı kalır, sadece üst sınır düşer |
| Redis cache (H5) | scoring_version yine DB'de tutulur, cache olmadan da doğru çalışır — sadece hız kaybı |
| Rotadan sapma tespiti | navigasyonda "3 ardışık" kontrolü yerine basit tek-eşik kontrolüne indirilir |
| M5 (ev skor kartı, "ziyaret ettim") | Hafta 3'te süre kalırsa eklenir, kalmazsa v2 backlog'una gider |

Kesilmeyenler bu listede yok — onlar zorunlu ve her hafta planına dahil.

---

## 0. GitHub Reposu ve Branch Stratejisi

### Adım adım kurulum (bugün, Gün 0)

1. **Repo oluştur** — GitHub'da `habi-v2` adıyla private repo aç. `.gitignore` için .NET + Node
   şablonlarını birleştir (`bin/`, `obj/`, `node_modules/`, `.env`, `*.osm.pbf`, `*.mbtiles`).
2. **main branch koruması** — Settings → Branches → `main` için: doğrudan push yasak, PR zorunlu,
   en az 1 onay zorunlu, "require status checks" (CI yeşil olmadan merge yok).
3. **İki departman entegrasyon branch'i aç** (main'den):
   ```
   git checkout main
   git checkout -b dept/yazilim && git push -u origin dept/yazilim
   git checkout main
   git checkout -b dept/veri && git push -u origin dept/veri
   ```
4. **Departman branch'lerine de hafif koruma koy**: doğrudan push yasak, PR zorunlu ama onay
   sayısı 1 (departman içi hız için). Departmanın **seçili kişisi** (tech lead / data lead)
   CODEOWNERS dosyasında bu branch'lerin reviewer'ı olarak tanımlanır:
   ```
   # .github/CODEOWNERS
   /api/       @yazilim-lead
   /web/       @yazilim-lead
   /mobile/    @yazilim-lead
   /data/      @veri-lead
   /db/        @veri-lead
   ```
5. **Kişisel branch isimlendirme kuralı** — herkes kendi işine departman branch'inden dallanır:
   ```
   feature/yazilim/<isim>-<konu>     örn: feature/yazilim/ahmet-auth-backend
   feature/veri/<isim>-<konu>        örn: feature/veri/ayse-osm-extract
   ```
6. **Günlük iş akışı (herkes için)**:
   ```
   git checkout dept/yazilim && git pull        # (veya dept/veri)
   git checkout -b feature/yazilim/ahmet-auth-backend
   # ... çalış, commit et ...
   git push -u origin feature/yazilim/ahmet-auth-backend
   # PR aç: feature/... → dept/yazilim
   ```
7. **Conflict kuralı** — departman içi PR'larda çakışma çıkarsa, o çakışmayı **departmanın
   seçili kişisi** (lead) çözer, çözmeden merge etmez. Diğer departmanla çakışma prensipte
   olmamalı çünkü `api/`, `web/`, `mobile/` yazılımda; `data/`, `db/` veride — CODEOWNERS bunu
   zaten ayırıyor.
8. **Hafta sonu entegrasyonu (her Cuma)** — proje yönetim ekibi `dept/yazilim` ve `dept/veri`
   branch'lerini sırayla `main`'e PR ile açar, CI'ı (aşağıdaki "Doğrulama" testleri) çalıştırır,
   yeşilse merge eder. Merge sonrası herkes yeni haftaya başlamadan önce:
   ```
   git checkout dept/yazilim && git pull origin main && git push
   git checkout dept/veri && git pull origin main && git push
   ```
9. **Commit mesajı formatı**: `[W1] auth: login endpoint + JWT` gibi — hafta numarası +
   feature kısaltması, PM ekibinin hafta sonu review'unda taranabilir olsun diye.

---

## Hafta 1 (Gün 1–5) — İskelet, Auth, Profil, Veri Temeli

**Milestone:** Ekip aynı repo/branch akışında çalışıyor, kullanıcı kayıt olup persona +
en fazla 3 anchor girebiliyor, mobilde dev client açık; veri tarafında POI ve bina verisi
PostGIS'e yüklü.

| Gün | Yazılım Ekibi | Veri Ekibi |
|---|---|---|
| 1 | Repo/branch akışı (yukarıdaki §0), .NET solution iskeleti (Habi.Api/Application/Domain/Infrastructure/Scoring), docker-compose (postgis, osrm-foot, osrm-car, tileserver), Vite+React+MapLibre iskeleti, **Expo dev client kurulumu (kritik, bu gün bitmeli — R1 riski)** | Çankaya OSM sınırını bul (Nominatim + polygons.openstreetmap.fr), Türkiye PBF indir, `osmium extract` ile Çankaya kesitini çıkar |
| 2 | Auth backend: register/login/refresh (JWT) + Swagger, Web: login/register sayfaları | `osm2pgsql -O flex` ile POI import (8 kategori, pet+bank hariç), `pois` tablosu dolsun |
| 3 | `GET /personas` (4 persona), Web onboarding — persona seçim ekranı | Bina poligonları (`building=*` residential filtre) → `buildings` tablosu |
| 4 | `/profile` GET/PUT, anchor CRUD backend (maks 3), Web anchor ekleme paneli | Mahalle poligonları (place node → Voronoi → ilçe sınırıyla kırp) |
| 5 | `PUT /profile/anchors/order` (geometrik ağırlık için sıra kaydı), Web'de dnd-kit sürükle-bırak, Mobile: login ekranı + mock rota listesi | Sentetik konut üretim script'i v1 (alan/oda/kat/yaş — kira modeli hariç) |

### Feature: Auth — adım adım
1. `Habi.Domain`'de `User` entity.
2. `Habi.Infrastructure`'da EF Core migration (`dotnet ef migrations add InitialAuth`).
3. `POST /auth/register` — parola hash (BCrypt), e-posta unique constraint.
4. `POST /auth/login` — JWT access + refresh token üret.
5. `POST /auth/refresh` — refresh token doğrula, yeni access token dön.
6. Web: `AuthContext` + korumalı route'lar (`/onboarding`, `/explore` login ister).

### Feature: Persona + Anchor — adım adım
1. `personas` tablosuna 4 arketipi sabit veri olarak seed et (§06'daki ağırlık tablosundan
   student, family_kids, remote_worker, elderly satırları).
2. `GET /personas` — statik liste + açıklama metni.
3. `anchors` tablosu: `profile_id, label, lat, lon, mode(car|foot), priority_order`.
4. Anchor CRUD: ekle/sil, `priority_order` DEFERRABLE UNIQUE (yeniden sıralamaya izin verir).
5. `PUT /profile/anchors/order` — tüm listeyi yeni sırayla topluca günceller (tek transaction).
6. Web: dnd-kit ile sürükle-bırak → bırakınca hemen bu endpoint'i çağır (skor henüz yoksa
   sadece sıra kaydedilir, Hafta 2'de skor tepkisi eklenecek).

### Feature: Veri ETL temeli — adım adım
1. `curl nominatim...` ile Çankaya relation ID'sini bul, sabit kabul etme.
2. `osmium extract -p cankaya.geojson turkey-latest.osm.pbf -o cankaya.osm.pbf`
3. `osm2pgsql -O flex -S data/lua/habi_pois.lua -d habi cankaya.osm.pbf` (lua dosyasında
   pet/bank etiketleri bu hafta için devre dışı bırakılır, yorum satırına alınır).
4. `building IN ('residential','apartments','house','yes',...)` filtresiyle bina import.
5. DQ-01 ön kontrolü: her binanın geometrisi valid mi (`ST_IsValid`).

---

## Hafta 2 (Gün 6–10) — Skor Motoru, Explore Ekranı, Veri Tamamlama

**Milestone:** Bir ev için 0–100 skor + gerekçe tablosu gerçek veriyle üretiliyor, web'de
`/explore` ekranı canlı, anchor sırası değişince skor gözle görülür değişiyor (AK-W4).

| Gün | Yazılım Ekibi | Veri Ekibi |
|---|---|---|
| 6 | `Habi.Scoring`: kategori alt skoru (plato+üstel bozunum), CES birleştirme — saf, I/O'suz, birim testli | Erişim matrisi: PostGIS KNN ön-eleme (en yakın 5 aday) |
| 7 | Anchor bileşeni (geometrik ağırlık) + bütçe skoru + gerekçe satırları (CES düzeltmesi dahil) | OSRM `/table` (foot) ile gerçek yürüme süreleri, `property_poi_access` doldur; OSRM foot+car build |
| 8 | `GET /properties` (skorlu arama, bbox+filtre), `GET /properties/{id}/score` | Sentetik kira modeli (log-normal β katsayıları, TÜİK/TCMB ile ±%15 kalibrasyon), 6.000 kayıt tamamla |
| 9 | Web `/explore`: harita + liste + filtreler, skor bandı renkleri, gerçek API'ye bağlanma | Planetiler ile `cankaya.mbtiles` build, tileserver-gl'e bağla |
| 10 | Web gerekçe tablosu UI (✅/❌ 4'er satır), düşük skorlu evleri gösterme toggle (W5); Mobile: property skor kartı (basit) | DQ-01..06 script'i (`db/checks/dq.sql`) + altın veri seti (6 konut × 4 persona × 3 anchor senaryosu = 72 vaka) |

### Feature: Skorlama motoru — adım adım
1. `Habi.Scoring` projesine `ScoringInput` / `ScoreResult` DTO'ları — proje hiçbir DB/HTTP
   çağrısı yapmaz (değişmez kural).
2. Kategori alt skoru: `s_c(t)` plato+üstel bozunum fonksiyonu, parametreler DB'den (t_ideal,
   t_half, t_cutoff), kodda sabit yok.
3. CES birleştirme: `POISkoru = (Σ w_c·s_c^ρ)^(1/ρ)`, ρ=-0.5, alt sınır s_c=1.
4. Anchor ağırlığı: sıraya göre `0.5^(i-1)` normalize et; anchor mesafe→puan formülü (mode'a
   göre T_free/T_half/T_cutoff farklı: car vs foot).
5. Bütçe skoru: parçalı fonksiyon (r≤0.70 → 100, ... r>1.00 → yarılanan ceza).
6. Nihai skor: bütçe girildiyse `0.70×YaşamSkoru+0.30×BütçeSkoru`, girilmediyse `YaşamSkoru`.
7. Gerekçe satırları: her satırın katkısı ayrı hesaplanır, CES doğrusal olmadığı için
   "CES dengesizlik düzeltmesi" satırı eklenir — `Σ contribution == total` (±0.05) testiyle
   korunur (I4).
8. Birim testler: I1 (0-100 aralık), I2 (monotonluk), I5 (anchor sırası değişince skor
   değişmeli), I8 (persona ağırlıkları toplamı 1.000).

### Feature: Explore ekranı — adım adım
1. `GET /properties?bbox=...&persona=...&budget=...` — skoru backend'de hesaplayıp döner
   (Hafta 2'de cache yok, her istekte hesap — Redis Hafta 3'e bile girmiyor bu planda).
2. MapLibre: zoom<13 cluster, zoom≥13 tekil nokta, skor bandına göre renk (85+/70-84/55-69/<55).
3. Liste paneli: skora göre azalan sıralama, sayfalama.
4. Filtre paneli: kira/m²/oda tipi slider'ları, anchor listesi (ekle/sil/sürükle).
5. Anchor sürükle-bırak bırakıldığında: `PUT /profile/anchors/order` → liste otomatik yeniden
   fetch edilir (AK-W4'ün UI karşılığı).

### Feature: Veri — erişim matrisi ve kira modeli — adım adım
1. Her konut × 8 kategori için KNN ile en yakın 5 aday: `ORDER BY pois.geom <-> p.geom LIMIT 5`.
2. Bu 5 adayın gerçek yürüme süresini OSRM `/table` (foot) ile al, en küçüğü yaz.
3. Kira modeli: `ln(rent_m2) = β0 + β1·ln(area) + β2·age + β3·elevator + β4·parking + β5·furnished
   + ln(neighborhood_rent_index) + ε`.
4. β0'ı TÜİK Konut Fiyat Endeksi / TCMB EVDS ile ±%15 bandında kalibre et — **ilan scrape etme**.
5. `properties.is_synthetic = true` + her yerde "Sentetik veri" rozeti (dürüstlük kuralı).
6. DQ kapıları: severity=error olanlar (bina dışı konut yok, persona ağırlıkları toplamı 1.000,
   min_poi_count) geçmeden ETL "yayınlandı" sayılmaz.

---

## Hafta 3 (Gün 11–15) — Rota, Mobil Navigasyon, Test, Teslim

**Milestone:** Kullanıcı 2–8 ev seçip en kısa rotayı oluşturuyor, mobilde bu rotayı gerçek
GPS ile adım adım yürüyebiliyor, tüm test kapıları yeşil, demo verisi donmuş.

| Gün | Yazılım Ekibi | Veri Ekibi |
|---|---|---|
| 11 | TSP: Held-Karp (açık TSP, sabit başlangıç) implementasyonu + brute-force karşılaştırma testi (n≤6) | Veri dondurma tarihi sabitle (`data_version`), tile'ları yayına al |
| 12 | `POST /routes` (OSRM `/table` → Held-Karp → OSRM `/route` steps=true), `routes`+`route_stops` tabloları | ETL'i baştan tam koşu (freeze öncesi son doğrulama), yedek pg_dump al |
| 13 | Web: ev seçimi → başlangıç noktası → rota önizleme → kaydet; Mobile: rota listesi + rota detay haritası (numaralı duraklar) | DQ raporunu final haline getir, "vitrin evleri" (demo için anlamlı skor farkı gösteren evler) seç |
| 14 | Mobile navigasyon: manevra metni eşleme (OSRM type/modifier → Türkçe), adım durum makinesi (saf, GPS fixture'la test edilebilir), `expo-location` entegrasyonu, basit rota-dışı uyarısı | Sahada test için destek (GPX iz hazırlama, emülatör Location mock) |
| 15 | Bug-fix + regresyon, gerçek cihazda saha testi (Çankaya'da bir rota, ekran kaydı al — demo yedeği), dokümantasyon, PM'e son PR | Son onay: demo öncesi manuel doğrulama checklist'i (aşağıda) |

### Feature: TSP / Rota — adım adım
1. `POST /routes` body: başlangıç koordinatı + 2-8 ev id'si.
2. OSRM `/table` (car) ile (1+n)×(1+n) süre matrisi al.
3. Held-Karp DP ile açık TSP'yi kesin çöz (`O(n²·2ⁿ)`, n=8 için <1ms) — `/trip` sadece hata
   durumunda yedek.
4. Bulunan sırayla OSRM `/route?steps=true&geometries=geojson&overview=full` çağır.
5. `routes` + `route_stops` tablolarına yaz — mobil bu payload'ı tek kaynak olarak kullanır,
   ikinci bir API çağrısına ihtiyaç duymaz.
6. Test: n≤6 için Held-Karp çıktısını brute-force ile birebir karşılaştır; n=8 için performans
   testi (<5ms).

### Feature: Mobil navigasyon — adım adım
1. `maneuverText.ts` — OSRM `type`+`modifier` → Türkçe metin eşleme tablosu (saf fonksiyon),
   bilinmeyen kombinasyon için varsayılan "Devam edin".
2. `stepMachine.ts` — saf, I/O'suz durum makinesi: konum → rota çizgisine izdüşür, aktif adıma
   kalan mesafe hesapla, <15m ise sonraki adıma geç, durak <30m ise `arrivedAtStop`.
3. Bu hafta için sapma tespiti basitleştirildi: dik mesafe >50m olduğu **tek** ölçümde uyar
   (orijinal plandaki "3 ardışık" kontrolü v2 backlog'a).
4. `expo-location.watchPositionAsync` — `Accuracy.High`, `distanceInterval:10`, `timeInterval:3000`.
5. Navigasyon ekranından çıkınca `watchPosition`'ı `useEffect` cleanup'ında mutlaka durdur (en
   sık yapılan hata).
6. Test: kaydedilmiş GPS iz fixture'larıyla `stepMachine`'i CI'da test et — telefon gerekmez.

### Hafta 3 sonu — manuel doğrulama checklist'i (demo öncesi)
- [ ] Aynı evi 4 farklı persona ile aç → skorlar anlamlı şekilde farklı
- [ ] Anchor sırasını değiştir → skor ve liste sırası gözle görülür şekilde değişir
- [ ] Gerekçe tablosundaki katkıları elle topla → gösterilen skora eşit
- [ ] 5 evle rota kur → seçim sırasıyla gezmekten kısa
- [ ] Rotayı telefonda gerçekten gez → adımlar doğru zamanda ilerliyor

---

## Otomatik Test Kapıları (her hafta sonu merge öncesi PM ekibi çalıştırır)
```
dotnet test --filter Category=Golden       # altın veri seti < 1 sn
dotnet test --filter Category=Invariant    # I1-I8
pnpm --filter web test:e2e                 # Playwright
pnpm --filter mobile test                  # stepMachine + maneuverText
psql -f db/checks/dq.sql                   # DQ-01..06 boş dönmeli
```

## Haftalık Merge Akışı (özet)
1. Hafta içi: herkes `feature/<dept>/<isim>-<konu>` → PR → `dept/<dept>` (departman lead'i onaylar/conflict çözer).
2. Cuma: PM ekibi `dept/yazilim` → `main` PR, testler yeşilse merge.
3. Cuma: PM ekibi `dept/veri` → `main` PR, testler yeşilse merge.
4. Pazartesi sabahı: herkes kendi dept branch'ini `main`'den günceller, yeni haftaya oradan başlar.
