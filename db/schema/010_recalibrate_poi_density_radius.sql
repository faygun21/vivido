-- 009'daki search_radius_m değerleri ilk tahmindi (800m eczane, 1000m
-- market gibi), hiçbir kaynağa dayanmıyordu. Veri ekibinden ayrı bir
-- "kategoriye göre ideal yarıçap" standardı beklemek gerçekçi değil —
-- bunun yerine ZATEN ELİMİZDE OLAN, skorlama için tanımlı
-- poi_categories.t_cutoff_min ("bu süreden sonra artık kabul edilmez")
-- ve ETL'deki standart yürüme hızından (72 m/dk, WALK_M_PER_MIN)
-- türetiyoruz. Böylece "kabul edilebilir azami mesafe" tanımı TEK yerde:
-- yoğunluk sinyali için ayrı, uydurma bir mesafe icat etmiyoruz.
--
--   search_radius_m ≈ t_cutoff_min × 72, en yakın 100m'ye yuvarlanmış
--
UPDATE poi_categories SET search_radius_m = 1800 WHERE code = 'food';     -- 25.0 dk × 72
UPDATE poi_categories SET search_radius_m = 2500 WHERE code = 'gym';      -- 35.0 dk × 72
UPDATE poi_categories SET search_radius_m = 2500 WHERE code = 'health';   -- 35.0 dk × 72
UPDATE poi_categories SET search_radius_m = 1800 WHERE code = 'market';   -- 25.0 dk × 72
UPDATE poi_categories SET search_radius_m = 2000 WHERE code = 'park';     -- 28.0 dk × 72
UPDATE poi_categories SET search_radius_m = 1600 WHERE code = 'pharmacy'; -- 22.0 dk × 72
UPDATE poi_categories SET search_radius_m = 2200 WHERE code = 'school';   -- 30.0 dk × 72
UPDATE poi_categories SET search_radius_m = 1800 WHERE code = 'transit';  -- 25.0 dk × 72

-- Yarıçap değiştiği için poi_count_in_radius'u yeniden hesaplamak şart
-- (bkz. data/scripts/02_build_access_matrix.py'deki aynı desen).
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

-- min_poi_count, 009'da bu veri kümesinin medyanına göre kalibre
-- edilmişti (küçük yürünebilirlik-ideali sayıları tavan yığılmasına yol
-- açmıştı) — yarıçap büyüdüğü için medyan da değişti, yeniden hesaplanıyor.
-- Not: bu değer "gerçek dünya standardı" değil, MEVCUT sentetik POI
-- dağılımının medyanı — gerçek veriye geçildiğinde tekrar hesaplanmalı.
UPDATE poi_categories pc
SET min_poi_count = medyan.deger
FROM (
    SELECT category_code,
           GREATEST(1, percentile_cont(0.5) WITHIN GROUP (ORDER BY poi_count_in_radius))::smallint AS deger
    FROM property_poi_access
    GROUP BY category_code
) medyan
WHERE pc.code = medyan.category_code;
