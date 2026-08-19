-- ══════════════════════════════════════════════════════════════════════
-- Çankaya Mahalleleri Sosyoekonomik Kira Endeksi Güncellemesi
-- ══════════════════════════════════════════════════════════════════════

-- 1. Lüks / Üst Segment (1.30 - 1.50)
UPDATE neighborhoods SET rent_index = 1.48 WHERE name LIKE '%Oran%';
UPDATE neighborhoods SET rent_index = 1.45 WHERE name LIKE '%Alacaatlı%' OR name LIKE '%Gaziosmanpaşa%' OR name LIKE '%Bilkent%';
UPDATE neighborhoods SET rent_index = 1.42 WHERE name LIKE '%Beytepe%' OR name LIKE '%Çayyolu%';
UPDATE neighborhoods SET rent_index = 1.40 WHERE name LIKE '%Ahlatlıbel%' OR name LIKE '%Ümitköy%' OR name LIKE '%Çukurambar%';

-- 2. Orta-Üst / Öğrenci & Memur (1.10 - 1.25)
UPDATE neighborhoods SET rent_index = 1.25 WHERE name LIKE '%Bahçelievler%' OR name LIKE '%Kavaklıdere%';
UPDATE neighborhoods SET rent_index = 1.22 WHERE name LIKE '%Ayrancı%' OR name LIKE '%Güvenevler%';
UPDATE neighborhoods SET rent_index = 1.20 WHERE name LIKE '%Büyükesat%' OR name LIKE '%Yıldızevler%' OR name LIKE '%Barbaros%';
UPDATE neighborhoods SET rent_index = 1.18 WHERE name LIKE '%Birlik%';
UPDATE neighborhoods SET rent_index = 1.15 WHERE name LIKE '%100.Yıl%' OR name LIKE '%Emek%' OR name LIKE '%Anıttepe%';

-- 3. Standart Yerleşim (0.90 - 1.05)
UPDATE neighborhoods SET rent_index = 1.05 WHERE name LIKE '%Öveçler%' OR name LIKE '%Kurtuluş%' OR name LIKE '%Mebusevleri%';
UPDATE neighborhoods SET rent_index = 1.02 WHERE name LIKE '%Balgat%';
UPDATE neighborhoods SET rent_index = 1.00 WHERE name LIKE '%Maltepe%';
UPDATE neighborhoods SET rent_index = 0.98 WHERE name LIKE '%Sokullu%';
UPDATE neighborhoods SET rent_index = 0.95 WHERE name LIKE '%Dikmen%' OR name LIKE '%Cebeci%';
UPDATE neighborhoods SET rent_index = 0.92 WHERE name LIKE '%Seyranbağları%' OR name LIKE '%Aydınlar%';

-- 4. Alt / Gelişmekte Olan Segment (0.70 - 0.88)
UPDATE neighborhoods SET rent_index = 0.85 WHERE name LIKE '%Akpınar%';
UPDATE neighborhoods SET rent_index = 0.82 WHERE name LIKE '%50.Yıl%' OR name LIKE '%Aşıkpaşa%';
UPDATE neighborhoods SET rent_index = 0.80 WHERE name LIKE '%Bademlidere%' OR name LIKE '%Topraklık%';
UPDATE neighborhoods SET rent_index = 0.78 WHERE name LIKE '%Boztepe%' OR name LIKE '%Karahasanoğlu%';
UPDATE neighborhoods SET rent_index = 0.75 WHERE name LIKE '%İmrahor%';
UPDATE neighborhoods SET rent_index = 0.72 WHERE name LIKE '%Yakupabdal%';
UPDATE neighborhoods SET rent_index = 0.70 WHERE name LIKE '%Karataş%';
