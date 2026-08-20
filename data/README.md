# Vivido — Veri (DATA) Ekibi Dokümantasyonu ve ETL Kılavuzu

Bu klasör, Vivido projesinin CBS (Coğrafi Bilgi Sistemleri) veri boru hattını, ETL betiklerini, Lua filtreleme kurallarını, sentetik konut üreticisini ve üretilen veri artefaktlarını içerir.

---

## 1. Veri Kaynakları ve Atıf

| Veri | Kaynak | Lisans / Not |
|---|---|---|
| Harita Ham Verisi | [OpenStreetMap (OSM)](https://www.openstreetmap.org) / Geofabrik | **ODbL 1.0** — Web ve mobilde harita üzerinde görünür atıf zorunludur. |
| İlçe & Mahalle Sınırları | Kamusal Açık Coğrafi Veri (`cankaya.geojson`, `cankaya-ankara-mahalles.geojson`) | Çankaya idari sınırları ve 124 resmi mahalle poligonu. |
| Kira Kalibrasyonu | TÜİK Konut Fiyat Endeksi & TCMB EVDS İstatistikleri | Kamusal özet istatistikler ile ±%15 sapma bandında kalibre edilmiştir. |

---

## 2. Veri Ekibinin Oluşturduğu Betikler ve Kodlar

* 📄 **`data/lua/vivido_pois.lua`**
  * `osm2pgsql` flex formatı için yazılmıştır. OSM ham verisinden 8 aktif POI kategorisini (market, eczane, durak, kafe, park, gym, okul, sağlık) ve konut amaçlı bina poligonlarını süzer.
* 🐍 **`data/scripts/01_load_neighborhoods.py`**
  * Çankaya'nın 124 mahalle sınır poligonunu PostGIS `neighborhoods` tablosuna aktarır.
* 🗄️ **`db/schema/003_update_neighborhood_rent_indexes.sql`**
  * Çankaya mahallelerini sosyoekonomik yapılarına göre 4 segmente (Lüks, Orta-Üst, Standart, Gelişmekte Olan) ayırarak `rent_index` (0.70 – 1.48) değerlerini tanımlar.
* 🐍 **`data/gen/gen_properties.py`**
  * Deterministik `SEED=20260817` ile `buildings` poligonları içinde `ST_PointOnSurface` garantisiyle tam 6.000 sentetik kiralık konut üretir. Daire büyüklüğü ($m^2$), oda sayısı, kat, yaş, asansör, otopark, evcil hayvan izni ve mahalle endeksli kira değerlerini hesaplayarak `properties` tablosuna aktarır (`is_synthetic = true`).
* 🐍 **`data/scripts/02_build_access_matrix.py`**
  * PostGIS KNN (`<->`) operatörü ve yürüme süresi hesabı ile 6.000 konut × 8 POI kategorisi = 48.000 satırlık precomputed erişim matrisini (`property_poi_access`) doldurur.

---

## 3. Sıfırdan Tüm ETL Sürecini Çalıştırma Sırası

ETL araç kutusu Docker imajı ([Dockerfile.etl](Dockerfile.etl)) içinde paketlenmiştir. Sıfırdan veri üretmek için aşağıdaki komutlar sırasıyla çalıştırılır:

```bash
# 1) Docker altyapısını başlat
pnpm infra:up

# 2) ETL Docker imajını derle
docker compose --profile etl build etl

# 3) Türkiye OSM verisinden Çankaya kesitini ayıkla (osmium)
docker compose --profile etl run --rm etl osmium extract -p /work/data/cankaya.geojson /work/data/turkey-260817.osm.pbf -o /work/data/cankaya.osm.pbf

# 4) POI ve Bina poligonlarını PostGIS'e aktar (osm2pgsql)
docker compose --profile etl run --rm etl osm2pgsql -O flex -S /work/data/lua/vivido_pois.lua -H postgis -U vivido -d vivido /work/data/cankaya.osm.pbf

# 5) Mahalle sınırlarını yükle
docker compose --profile etl run --rm etl python3 /work/data/scripts/01_load_neighborhoods.py

# 6) Mahalle sosyoekonomik kira endekslerini güncelle
docker compose exec -T postgis psql -U vivido -d vivido -f /db/schema/003_update_neighborhood_rent_indexes.sql

# 7) Sentetik 6.000 konut verisini üret
docker compose --profile etl run --rm etl python3 /work/data/gen/gen_properties.py

# 8) Precomputed erişim matrisini hesapla (48.000 satır)
docker compose --profile etl run --rm etl python3 /work/data/scripts/02_build_access_matrix.py

# 9) Veri Kalitesi (DQ) testlerini çalıştır
pnpm db:check
```

---

## 4. Üretilen Veri Artefaktları (`data/artifacts/`)

Data ekibinin ürettiği ağır işlenmiş veri artefaktları `data/artifacts/` klasöründe yer alır ve git'e commit edilmez (GitHub Release üzerinden dağıtılır):

* **`seed.sql`** (~15.1 MB): 6.000 konut, 6.237 POI, 124 mahalle ve 48.000 erişim matrisinin PostGIS veri yedeği.
* **`osrm/foot/` & `osrm/car/`**: Yürüme ve araç yönlendirme motorlarının işlenmiş grafları.
* **`cankaya.mbtiles`** (~4.3 MB): TileServer-GL için derlenmiş harita vektör karoları.

Yazılım ekibi bu hazır artefaktları indirip kullanmak için sadece `./data/scripts/00_fetch_artifacts.sh` komutunu çalıştırır.

---

## 5. Veri Kalite Güvencesi (DQ Raporu)

`pnpm db:check` çalıştırıldığında alınan veri kalitesi kontrol sonuçları:

| Kod | Seviye | Kural | Durum | Detay |
|---|---|---|---|---|
| **DQ-01** | error | Konut kendi bina poligonu içinde | **PASS** | 0 konut binasının dışında |
| **DQ-02** | warn | rent_per_m2 mahalle medyanının [0.3x, 3x] aralığında | **PASS** | 0 / 6000 konut bant dışı |
| **DQ-03** | error | Her persona için SUM(weight) = 1.000 | **PASS** | Tüm personalar 1.000 |
| **DQ-04** | warn | Erişim matrisi tam (konut × aktif kategori) | **PASS** | 48.000 / 48.000 satır |
| **DQ-05** | warn | Kira dağılımı çeyreklikleri | **PASS** | p10=692, p50=965, p90=1376 ₺/m² |
| **DQ-06** | error | Anchor öncelikleri 1..n kesintisiz | **PASS** | 0 profilde bozuk sıralama |

**Sonuç:** Veri kalitesi kapıları %100 BAŞARILI (YEŞİL) olarak onaylanmıştır.
