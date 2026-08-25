-- Yoğunluk sinyali (R-27/R-109 destek): "300m'de 1 market ile 5 market"
-- ayrımı için, kategori başına arama yarıçapındaki POI sayısı artık
-- property_poi_access'te tutuluyor. Skorlama bu sayıyı min_poi_count'a
-- oranlayıp küçük bir çarpan olarak kullanıyor (bkz. ScoringEngine.cs).

ALTER TABLE property_poi_access
    ADD COLUMN IF NOT EXISTS poi_count_in_radius SMALLINT;

-- poi_categories.search_radius_m / min_poi_count şu ana kadar 8
-- kategorinin 8'inde de aynıydı (2500m, 5 adet) — kimse kategoriye göre
-- ayarlamamış, placeholder değerlerdi.
--
-- ⚠️ İlk sürümde min_poi_count'u "yürünebilirlik ideali" gibi küçük,
-- kategoriden bağımsız sayılarla (3-4) doldurmuştuk. Çankaya merkez gibi
-- yoğun bir bölgede gerçek POI sayıları bunun 5-10 katı çıktı (örn. food
-- kategorisinde medyan 30 POI/yarıçap) — sonuç: yoğunluk çarpanı neredeyse
-- HER evde üst sınıra (+%10) doyuyor, bu da Yol A'nın az önce dağıttığı
-- 100'lük tavan yığılmasını GERİ getiriyordu (canlı testte 456 ev yeniden
-- 100.00'e yığıldı). min_poi_count artık bu veri kümesindeki GERÇEK
-- medyan POI sayısına çekildi — evlerin yaklaşık yarısı ortalamanın
-- üstünde küçük bir bonus, yarısı altında küçük bir ceza alacak şekilde.
UPDATE poi_categories SET search_radius_m = 1200, min_poi_count = 30 WHERE code = 'food';
UPDATE poi_categories SET search_radius_m = 1500, min_poi_count = 24 WHERE code = 'gym';
UPDATE poi_categories SET search_radius_m = 1500, min_poi_count = 5  WHERE code = 'health';
UPDATE poi_categories SET search_radius_m = 1000, min_poi_count = 12 WHERE code = 'market';
UPDATE poi_categories SET search_radius_m = 1000, min_poi_count = 19 WHERE code = 'park';
UPDATE poi_categories SET search_radius_m = 800,  min_poi_count = 9  WHERE code = 'pharmacy';
UPDATE poi_categories SET search_radius_m = 1500, min_poi_count = 15 WHERE code = 'school';
UPDATE poi_categories SET search_radius_m = 700,  min_poi_count = 15 WHERE code = 'transit';

-- Mevcut 6000 konut için tek seferlik geriye dönük dolgu. Gelecekte yeni
-- konut/POI verisi geldiğinde bunu data/scripts/02_build_access_matrix.py
-- zaten otomatik hesaplıyor (bkz. o dosyadaki aynı UPDATE deseni).
UPDATE property_poi_access ppa
SET poi_count_in_radius = counts.cnt
FROM (
    SELECT p.id AS property_id, c.code AS category_code, count(poi.id) AS cnt
    FROM properties p
    CROSS JOIN poi_categories c
    LEFT JOIN pois poi
        ON poi.category_code = c.code
        AND ST_DistanceSphere(p.geom, poi.geom) <= c.search_radius_m
    WHERE c.active
    GROUP BY p.id, c.code
) counts
WHERE ppa.property_id = counts.property_id
  AND ppa.category_code = counts.category_code;

-- Skor hassasiyeti: 2 ondalık, iki farklı gerçek skorun aynı sayıya
-- yuvarlanıp sahte bir "eşit skor" görüntüsü vermesine yol açıyordu
-- (476 kayıttan 89'u tekrardı, ScoringEngine artık 4 ondalıkla hesaplıyor).
ALTER TABLE score_cache
    ALTER COLUMN total_score TYPE NUMERIC(7,4);

ALTER TABLE score_cache
    DROP CONSTRAINT IF EXISTS score_cache_total_score_check;

ALTER TABLE score_cache
    ADD CONSTRAINT score_cache_total_score_check
    CHECK (total_score >= 0::numeric AND total_score <= 100::numeric);
