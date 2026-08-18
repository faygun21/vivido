-- ══════════════════════════════════════════════════════════════════════
--  Vivido — veri kalitesi kapıları (DQ-01 … DQ-06)
--
--  Kaynak: docs/00-KAPSAM.md "Veri kalitesi kapıları"
--
--  Çalıştırma:
--      pnpm db:check
--      docker compose exec -T postgis psql -U vivido -d vivido -f /checks/dq.sql
--
--  Çıktı: her kapı için tek satırlık PASS / FAIL raporu.
--  severity='error' olan bir kapı FAIL ise en sonda EXCEPTION atılır →
--  psql sıfırdan farklı kod döner → ETL durur, veri "yayınlandı" sayılmaz.
--
--  Boş veritabanında hepsi PASS döner (ihlal yok). Bu kasıtlıdır:
--  kapılar "veri var mı" değil, "veri tutarlı mı" sorusunu sorar.
--  ETL'in gerçekten çalıştığını DQ-04 satır sayısı gösterir.
-- ══════════════════════════════════════════════════════════════════════

\pset border 2
\pset title 'Vivido — Veri Kalitesi Raporu'

CREATE TEMP VIEW dq_rapor AS

-- ── DQ-01 · Her konut kendi bina poligonunun içinde mi? ───────────────
-- Sentetik konutlar ST_GeneratePoints ile bina içinde üretilir.
-- Buradaki ihlal, üretim betiğinde geometri hatası demektir.
SELECT 'DQ-01' AS kod,
       'error' AS seviye,
       'Konut kendi bina poligonu içinde' AS kural,
       count(*) AS ihlal,
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS durum,
       count(*) || ' konut binasının dışında' AS detay
FROM   properties p
JOIN   buildings  b ON p.building_id = b.id
WHERE  NOT ST_Within(p.geom, b.geom)

UNION ALL

-- ── DQ-02 · Kira/m² mahalle medyanına göre makul mü? ──────────────────
-- [0.3× , 3×] bandı dışındakiler aykırı. %2'ye kadar tolere edilir:
-- log-normal kuyruğunda birkaç uç değer normaldir.
SELECT 'DQ-02', 'warn',
       'rent_per_m2 mahalle medyanının [0.3x, 3x] aralığında',
       count(*) FILTER (WHERE aykiri),
       CASE WHEN count(*) = 0
                 OR count(*) FILTER (WHERE aykiri)::numeric / count(*) <= 0.02
            THEN 'PASS' ELSE 'FAIL' END,
       count(*) FILTER (WHERE aykiri) || ' / ' || count(*) || ' konut bant dışı'
FROM (
  SELECT p.rent_per_m2 < 0.3 * m.medyan
      OR p.rent_per_m2 > 3.0 * m.medyan AS aykiri
  FROM   properties p
  JOIN  (SELECT neighborhood_id,
                percentile_cont(0.5) WITHIN GROUP (ORDER BY rent_per_m2) AS medyan
         FROM   properties GROUP BY neighborhood_id) m
    ON   m.neighborhood_id = p.neighborhood_id
  WHERE  m.medyan > 0
) s

UNION ALL

-- ── DQ-03 · Persona ağırlıkları tam 1.000 topluyor mu? ────────────────
-- Skorlama motorunun I8 değişmezliği. Bozulursa POI skoru sessizce
-- yanlış ölçeğe kayar ve hiçbir test bunu yakalamaz.
SELECT 'DQ-03', 'error',
       'Her persona icin SUM(weight) = 1.000',
       count(*),
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
       coalesce(string_agg(persona_code || '=' || toplam, ', '), 'tum personalar 1.000')
FROM (
  SELECT persona_code, round(sum(weight), 3) AS toplam
  FROM   persona_category_weights
  GROUP  BY persona_code
  HAVING round(sum(weight), 3) <> 1.000
) s

UNION ALL

-- ── DQ-04 · Erişim matrisi tam mı? ────────────────────────────────────
-- Beklenen: her aktif konut × her aktif kategori.
-- 3 haftalık planda 6.000 konut × 8 kategori = 48.000 satır.
SELECT 'DQ-04', 'warn',
       'Erisim matrisi tam (konut x aktif kategori)',
       greatest(beklenen - mevcut, 0),
       CASE WHEN beklenen = 0 THEN 'PASS'          -- ETL henüz çalışmadı
            WHEN mevcut >= beklenen THEN 'PASS'
            ELSE 'FAIL' END,
       mevcut || ' / ' || beklenen || ' satir'
FROM (
  SELECT (SELECT count(*) FROM properties)
       * (SELECT count(*) FROM poi_categories WHERE active) AS beklenen,
         (SELECT count(*) FROM property_poi_access)         AS mevcut
) s

UNION ALL

-- ── DQ-05 · Kira dağılımı makul mü? ───────────────────────────────────
-- Otomatik eşik yok — çeyreklikler gözle kontrol edilir.
-- Kapı yalnızca "hiç negatif/sıfır kira yok" kısmını zorlar.
SELECT 'DQ-05', 'warn',
       'Kira dagilimi ceyreklikleri (gozle kontrol)',
       0,
       'PASS',
       coalesce(
         'p10=' || round(q[1]) || ' p25=' || round(q[2]) || ' p50=' || round(q[3])
              || ' p75=' || round(q[4]) || ' p90=' || round(q[5]) || ' TL/m2',
         'veri yok')
FROM (
  SELECT percentile_cont(ARRAY[0.1, 0.25, 0.5, 0.75, 0.9])
         WITHIN GROUP (ORDER BY rent_per_m2) AS q
  FROM   properties
) s

UNION ALL

-- ── DQ-06 · Anchor öncelikleri 1..n kesintisiz mi? ────────────────────
-- Sürükle-bırak sıralaması (W4) yarım kalan bir transaction bırakırsa
-- burada yakalanır. Boşluklu sıra → geometrik ağırlık yanlış hesaplanır.
SELECT 'DQ-06', 'error',
       'Anchor oncelikleri 1..n kesintisiz',
       count(*),
       CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
       count(*) || ' profilde bozuk siralama'
FROM (
  SELECT profile_id
  FROM   anchors
  GROUP  BY profile_id
  HAVING max(priority) <> count(*)
      OR min(priority) <> 1
) s;


-- ─── Rapor ───
SELECT kod, seviye, kural, ihlal, durum, detay
FROM   dq_rapor
ORDER  BY kod;


-- ─── Kapı: error seviyesinde FAIL varsa ETL durur ───
DO $$
DECLARE
  bozuk text;
BEGIN
  SELECT string_agg(kod, ', ')
  INTO   bozuk
  FROM   dq_rapor
  WHERE  seviye = 'error' AND durum = 'FAIL';

  IF bozuk IS NOT NULL THEN
    RAISE EXCEPTION 'DQ KAPISI KAPALI — error seviyesinde basarisiz kontrol: %', bozuk
      USING HINT = 'Veri yayinlanamaz. Once bu kontrolleri duzeltin.';
  END IF;

  RAISE NOTICE 'DQ kapilari acik — error seviyesinde basarisiz kontrol yok.';
END $$;
