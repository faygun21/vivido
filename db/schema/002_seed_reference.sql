-- ══════════════════════════════════════════════════════════════════════
--  Vivido — referans (sabit) veri
--
--  Buradaki veri OSM'den GELMEZ, ETL üretmez, elle bakımı yapılır:
--  skor eşikleri, personalar, ağırlık matrisi, OSM etiket eşlemesi.
--
--  ETL çıktısı (pois / buildings / properties …) ayrı gelir: seed.sql
--
--  Tekrar çalıştırılabilir olsun diye her INSERT idempotent yazıldı
--  (ON CONFLICT … DO UPDATE) — psql ile elle de çalıştırılabilir.
-- ══════════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════════
--  POI KATEGORİLERİ — 8 adet
--
--  3 haftalık plan 10 kategoriden 2'sini kesti:
--    · bank (banka / ATM)
--    · pet  (veteriner & köpek parkı)
--  Gerekçe: erişim matrisi %20 küçülür (60.000 → 48.000 satır).
--
--  Geri eklemek istenirse: buraya satır + persona ağırlıklarını yeniden
--  normalize et + data/lua/vivido_pois.lua içindeki filtreyi aç.
-- ══════════════════════════════════════════════════════════════════════
INSERT INTO poi_categories
  (code, display_name_tr, t_ideal_min, t_half_min, t_cutoff_min) VALUES
  ('market',   'Market / süpermarket',    4,  10, 25),
  ('pharmacy', 'Eczane',                  4,   9, 22),
  ('transit',  'Toplu taşıma durağı',     5,  11, 25),
  ('food',     'Kafe & restoran',         5,  12, 25),
  ('park',     'Park & yeşil alan',       5,  12, 28),
  ('gym',      'Spor salonu',             7,  15, 35),
  ('school',   'İlkokul / ortaokul',      6,  13, 30),
  ('health',   'ASM / hastane',           8,  16, 35)
ON CONFLICT (code) DO UPDATE SET
  display_name_tr = EXCLUDED.display_name_tr,
  t_ideal_min     = EXCLUDED.t_ideal_min,
  t_half_min      = EXCLUDED.t_half_min,
  t_cutoff_min    = EXCLUDED.t_cutoff_min;


-- ══════════════════════════════════════════════════════════════════════
--  PERSONALAR — 4 adet
--
--  3 haftalık plan 6'dan 4'e indirdi. Kesilenler:
--    · pet_owner  — pet kategorisi kesildiği için zaten anlamsız kalıyordu
--    · car_free   — transit ağırlığı student ile büyük ölçüde örtüşüyor
--
--  ⚠ packages/shared/src/index.ts içindeki PERSONA_CODES hâlâ 6 tanesini
--    listeliyor. Persona endpoint'i yazılırken orası da 4'e indirilmeli.
-- ══════════════════════════════════════════════════════════════════════
INSERT INTO personas (code, display_name_tr, description_tr, icon) VALUES
  ('student',       'Öğrenci',
   'Toplu taşıma ve sosyal hayat öncelikli; okula/kampüse erişim belirleyici.',
   'graduation-cap'),
  ('family_kids',   'Çocuklu aile',
   'Okul, market ve park yakınlığı öncelikli; sakin çevre tercih edilir.',
   'users'),
  ('remote_worker', 'Uzaktan çalışan',
   'Evden çalışır; kafe, park ve spor salonu günlük hayatın merkezinde.',
   'laptop'),
  ('elderly',       'Yaşlı / emekli',
   'Eczane, market ve sağlık kuruluşuna yürüme mesafesi belirleyici.',
   'heart')
ON CONFLICT (code) DO UPDATE SET
  display_name_tr = EXCLUDED.display_name_tr,
  description_tr  = EXCLUDED.description_tr,
  icon            = EXCLUDED.icon;


-- ══════════════════════════════════════════════════════════════════════
--  PERSONA × KATEGORİ AĞIRLIK MATRİSİ
--
--  ⚠ Bu değerler plan dokümanındaki 10 kategorilik tablodan OLDUĞU GİBİ
--    alınmadı. bank + pet kesilince satır toplamları 1.000'in altına
--    düşüyordu (ör. student: 0.85). Kalan 8 kategori, orijinal oranları
--    korunacak şekilde yeniden normalize edildi:
--
--        yeni_w = eski_w / (1 - w_bank - w_pet)
--
--    Böylece kategoriler arası GÖRECELİ önem plan dokümanıyla birebir
--    aynı kaldı, sadece ölçek büyüdü. Her satır tam 1.000 topluyor
--    (I8 değişmezliği ve DQ-03 kapısı bunu şart koşuyor).
-- ══════════════════════════════════════════════════════════════════════
INSERT INTO persona_category_weights (persona_code, category_code, weight) VALUES
  -- Öğrenci  (orijinal toplam 0.85 → /0.85)
  ('student',       'market',   0.165),
  ('student',       'pharmacy', 0.071),
  ('student',       'transit',  0.259),   -- en yüksek: kampüse ulaşım
  ('student',       'food',     0.235),
  ('student',       'park',     0.082),
  ('student',       'gym',      0.129),
  ('student',       'school',   0.000),
  ('student',       'health',   0.059),

  -- Çocuklu aile  (orijinal toplam 0.97 → /0.97)
  ('family_kids',   'market',   0.186),
  ('family_kids',   'pharmacy', 0.103),
  ('family_kids',   'transit',  0.124),
  ('family_kids',   'food',     0.051),
  ('family_kids',   'park',     0.144),
  ('family_kids',   'gym',      0.041),
  ('family_kids',   'school',   0.258),   -- en yüksek: okul
  ('family_kids',   'health',   0.093),

  -- Uzaktan çalışan  (orijinal toplam 0.89 → /0.89)
  ('remote_worker', 'market',   0.202),
  ('remote_worker', 'pharmacy', 0.079),
  ('remote_worker', 'transit',  0.079),
  ('remote_worker', 'food',     0.247),   -- en yüksek: kafe
  ('remote_worker', 'park',     0.180),
  ('remote_worker', 'gym',      0.146),
  ('remote_worker', 'school',   0.000),
  ('remote_worker', 'health',   0.067),

  -- Yaşlı / emekli  (orijinal toplam 0.95 → /0.95)
  ('elderly',       'market',   0.232),   -- en yüksek (eczane ile eşit)
  ('elderly',       'pharmacy', 0.232),
  ('elderly',       'transit',  0.147),
  ('elderly',       'food',     0.053),
  ('elderly',       'park',     0.126),
  ('elderly',       'gym',      0.021),
  ('elderly',       'school',   0.000),
  ('elderly',       'health',   0.189)
ON CONFLICT (persona_code, category_code) DO UPDATE SET
  weight = EXCLUDED.weight;


-- ══════════════════════════════════════════════════════════════════════
--  OSM ETİKET → KATEGORİ EŞLEMESİ
--
--  Kaynak: docs/01-PROJE-PLANI.md §9.3
--  data/lua/vivido_pois.lua bu tabloyla TUTARLI olmak zorundadır.
-- ══════════════════════════════════════════════════════════════════════
INSERT INTO poi_tag_mapping (osm_key, osm_value, category_code) VALUES
  ('shop',    'supermarket',       'market'),
  ('shop',    'convenience',       'market'),
  ('shop',    'greengrocer',       'market'),
  ('shop',    'butcher',           'market'),

  ('amenity', 'pharmacy',          'pharmacy'),

  ('highway', 'bus_stop',          'transit'),
  ('amenity', 'bus_station',       'transit'),
  ('railway', 'tram_stop',         'transit'),
  -- Ankara metrosu: railway=station + station=subway ikili etiketle gelir.
  -- Bu tablo tek anahtar/değer çifti tutar; ikinci koşulu lua betiği uygular.
  ('railway', 'station',           'transit'),

  ('amenity', 'cafe',              'food'),
  ('amenity', 'restaurant',        'food'),
  ('amenity', 'fast_food',         'food'),
  ('shop',    'bakery',            'food'),

  ('leisure', 'park',              'park'),
  ('leisure', 'garden',            'park'),
  ('leisure', 'playground',        'park'),
  ('landuse', 'recreation_ground', 'park'),

  ('leisure', 'fitness_centre',    'gym'),
  ('leisure', 'sports_centre',     'gym'),
  ('leisure', 'pitch',             'gym'),
  ('leisure', 'swimming_pool',     'gym'),

  ('amenity', 'school',            'school'),
  ('amenity', 'kindergarten',      'school'),

  ('amenity', 'hospital',          'health'),
  ('amenity', 'clinic',            'health'),
  ('amenity', 'doctors',           'health')
ON CONFLICT (osm_key, osm_value, category_code) DO NOTHING;
