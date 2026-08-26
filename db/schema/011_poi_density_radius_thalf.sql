-- 010'da search_radius_m'i t_cutoff_min x 72 (yürüme hızı) olarak
-- türetmiştik. t_cutoff "skorun sıfırlandığı, artık hiç önemsenmeyen
-- sınır" olduğu için yoğunluk yarıçapı gereğinden büyük çıktı (eczane
-- 1600m, market 1800m — sezgisel olarak "yürüme mesafesi" değil).
--
-- Yoğunluk sinyalinin sorduğu soru farklı: "bu ev için MAKUL SAYILABİLECEK
-- kaç alternatif var" — bu, t_half_min'in ("hâlâ iyi sayılır, ideal değil
-- ama kabul edilebilir" sınırı) tam olarak tarif ettiği şey. t_cutoff'a
-- kadar her şeyi saymak sinyali "civardaki her şey" gibi anlamsız
-- genişletiyordu.
--
--   search_radius_m ≈ t_half_min × 72, en yakın 50m'ye yuvarlanmış
--
UPDATE poi_categories SET search_radius_m = 650  WHERE code = 'pharmacy'; -- 9.0 dk × 72
UPDATE poi_categories SET search_radius_m = 700  WHERE code = 'market';   -- 10.0 dk × 72
UPDATE poi_categories SET search_radius_m = 800  WHERE code = 'transit';  -- 11.0 dk × 72
UPDATE poi_categories SET search_radius_m = 850  WHERE code = 'food';     -- 12.0 dk × 72
UPDATE poi_categories SET search_radius_m = 850  WHERE code = 'park';     -- 12.0 dk × 72
UPDATE poi_categories SET search_radius_m = 950  WHERE code = 'school';   -- 13.0 dk × 72
UPDATE poi_categories SET search_radius_m = 1100 WHERE code = 'gym';      -- 15.0 dk × 72
UPDATE poi_categories SET search_radius_m = 1150 WHERE code = 'health';   -- 16.0 dk × 72

-- Yarıçap küçüldüğü için poi_count_in_radius yeniden hesaplanıyor.
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

-- min_poi_count yine bu veri kümesinin (yeni, küçülmüş yarıçaptaki)
-- medyanına göre dinamik hesaplanıyor.
UPDATE poi_categories pc
SET min_poi_count = medyan.deger
FROM (
    SELECT category_code,
           GREATEST(1, percentile_cont(0.5) WITHIN GROUP (ORDER BY poi_count_in_radius))::smallint AS deger
    FROM property_poi_access
    GROUP BY category_code
) medyan
WHERE pc.code = medyan.category_code;
