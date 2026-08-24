#!/usr/bin/env python3
"""
Çankaya Mahalleleri Sosyoekonomik Kira Endeksi Güncelleyici
Çankaya mahallelerini sosyoekonomik ve fiyat seviyelerine göre 4 segmentte indeksler:
- Lüks / Üst Segment (Oran, Gaziosmanpaşa, Alacaatlı, Beytepe, Çayyolu, Bilkent vb.): 1.30 - 1.50
- Orta-Üst / Öğrenci & Memur (Ayrancı, Bahçelievler, Birlik, 100.Yıl, Çukurambar vb.): 1.05 - 1.25
- Standart Yerleşim (Balgat, Öveçler, Dikmen, Sokullu, Seyranbağları vb.): 0.90 - 1.05
- Alt / Gelişmekte Olan (Akpınar, Bademlidere, Boztepe, Karataş, İmrahor vb.): 0.70 - 0.88
"""
import os
import psycopg2

DB_HOST = os.getenv("PGHOST", "localhost")
DB_PORT = os.getenv("PGPORT", "5432")
DB_NAME = os.getenv("PGDATABASE", "vivido")
DB_USER = os.getenv("PGUSER", "vivido")
DB_PASS = os.getenv("PGPASSWORD", "degistir_beni_local_sifre")

# Mahalle Sosyoekonomik Endeks Haritası
LUXURY_NEIGHBORHOODS = {
    'Oran': 1.48, 'Alacaatlı': 1.45, 'Beytepe': 1.42, 'Ahlatlıbel': 1.40,
    'Gaziosmanpaşa': 1.45, 'Çayyolu': 1.42, 'Ümitköy': 1.40, 'Koru': 1.35,
    'Bilkent': 1.45, 'Çukurambar': 1.40, 'Mustafa Kemal': 1.35, 'Mutlukent': 1.38
}

MID_HIGH_NEIGHBORHOODS = {
    'Ayrancı': 1.22, 'Bahçelievler': 1.25, 'Birlik': 1.18, '100.Yıl': 1.15,
    'Emek': 1.15, 'Büyükesat': 1.20, 'Kavaklıdere': 1.25, 'Barbaros': 1.20,
    'Anıttepe': 1.15, 'Güvenevler': 1.22, 'Kırkkonaklar': 1.12, 'Yıldızevler': 1.20
}

STANDARD_NEIGHBORHOODS = {
    'Balgat': 1.02, 'Aşağı Öveçler': 1.05, 'Yukarı Öveçler': 1.05,
    'Dikmen': 0.95, 'Sokullu Mehmet Paşa': 0.98, 'Seyranbağları': 0.92,
    'Cebeci': 0.95, 'Kurtuluş': 1.05, 'Kızılay': 1.08, 'Maltepe': 1.00,
    'Ata': 0.96, 'Aydınlar': 0.92, 'Bayraktar': 0.94, 'Mebusevleri': 1.05
}

AFFORDABLE_NEIGHBORHOODS = {
    'Akpınar': 0.85, 'Bademlidere': 0.80, 'Boztepe': 0.78, '50.Yıl': 0.82,
    'Arka Topraklık': 0.80, 'Aşağı İmrahor': 0.75, 'Aşıkpaşa': 0.82,
    'Karataş': 0.70, 'Yakupabdal': 0.72, 'Karahasanoğlu': 0.78
}

def main():
    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASS
    )
    cur = conn.cursor()

    cur.execute("SELECT id, name FROM neighborhoods;")
    rows = cur.fetchall()

    updated = 0
    for n_id, n_name in rows:
        idx = 1.000
        clean_name = n_name.strip()

        if clean_name in LUXURY_NEIGHBORHOODS:
            idx = LUXURY_NEIGHBORHOODS[clean_name]
        elif clean_name in MID_HIGH_NEIGHBORHOODS:
            idx = MID_HIGH_NEIGHBORHOODS[clean_name]
        elif clean_name in STANDARD_NEIGHBORHOODS:
            idx = STANDARD_NEIGHBORHOODS[clean_name]
        elif clean_name in AFFORDABLE_NEIGHBORHOODS:
            idx = AFFORDABLE_NEIGHBORHOODS[clean_name]
        else:
            # İsme göre kısmi eşleşme kontrolü
            matched = False
            for k, v in LUXURY_NEIGHBORHOODS.items():
                if k in clean_name:
                    idx = v
                    matched = True
                    break
            if not matched:
                for k, v in STANDARD_NEIGHBORHOODS.items():
                    if k in clean_name:
                        idx = v
                        matched = True
                        break

        cur.execute("UPDATE neighborhoods SET rent_index = %s WHERE id = %s;", (idx, n_id))
        updated += 1

    conn.commit()
    cur.close()
    conn.close()
    print(f"BAŞARILI: {updated} Çankaya mahallesinin sosyoekonomik kira endeksi güncellendi!")

if __name__ == "__main__":
    main()
