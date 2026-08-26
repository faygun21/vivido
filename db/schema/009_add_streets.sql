-- ══════════════════════════════════════════════════════════════════════
--  Vivido — adlı sokaklar (konut adresi için)
--
--  NEDEN VAR
--  `properties` tablosunda adres alanı YOK: sentetik konutlar gerçek bina
--  poligonlarının içine üretiliyor (K-06) ama üretim sırasında hiçbir adres
--  bilgisi taşınmıyor. Kullanıcıya gösterebildiğimiz tek konum bilgisi
--  mahalle adıydı ("Kurtuluş Mah.") — bir kiralık ilanı için fazla kaba.
--
--  NEDEN TERS GEOKODLAMA DEĞİL
--  Nominatim'in kullanım politikası saniyede 1 istek sınırı koyuyor ve bir
--  veri kümesini sistematik olarak geokodlamayı açıkça yasaklıyor; 20
--  konutluk bir liste 20 saniye sürerdi ve IP yasağı riski TÜM ekibi
--  (staging dahil) etkilerdi — üstelik konum aramamız da aynı sağlayıcıya
--  bağlı, o özellik de birlikte ölürdü. Photon'un sert limiti yok ama
--  garantisi de yok. Her ikisi de istek anında dış servise bağımlılık
--  demek: bugün milisaniyeler süren detay paneli, Almanya'daki bir
--  sunucunun keyfine bağlanırdı.
--
--  Ve karşılığında daha iyi bir cevap vermiyorlar: Nominatim'in Çankaya
--  için döneceği sokak adı, `data/artifacts/cankaya.osm.pbf` dosyamızdaki
--  AYNI OSM verisinden geliyor. O hâlde veriyi yerele alıp KNN ile
--  sorgulamak hem daha hızlı hem de dış bağımlılıksız.
--
--  NASIL DOLDURULUR
--    ./data/scripts/05_load_streets.sh
--  Tablo boş kalırsa API adres alanını NULL döner ve arayüz mahalle adına
--  düşer — kimse hata görmez, sadece sokak adı görünmez.
--
--  ⚠️ Bu tablo ETL çıktısıdır, kullanıcı verisi DEĞİLDİR. `seed.sql`
--  yeniden üretilirken `pg_dump --data-only` kapsamına girmelidir.
-- ══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS streets (
  id           bigserial PRIMARY KEY,
  osm_id       bigint,
  name         text NOT NULL,
  -- OSM'de bir cadde onlarca ayrı `way` olarak parçalanmış olabilir; her
  -- parça ayrı satırdır. En yakını aradığımız için birleştirmeye gerek yok.
  geom         geometry(LineString, 4326) NOT NULL,
  data_version text NOT NULL
);

-- KNN (`geom <-> geom`) operatörünün indeksten faydalanabilmesi için GiST
-- ŞART. Onsuz "en yakın sokak" sorgusu tam tarama yapar.
CREATE INDEX IF NOT EXISTS idx_street_geom ON streets USING GIST (geom);

COMMENT ON TABLE streets IS
  'OSM adli yol/sokak parcalari. Konut adresi icin KNN ile en yakini bulunur; ters geokodlama YOK.';
