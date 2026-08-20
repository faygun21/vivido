#!/usr/bin/env python3
"""
Vivido — Sentetik Kiralık Konut Üretici Betiği
Kaynak: docs/01-PROJE-PLANI.md §9.6

Deterministik SEED=20260817 ile PostGIS binaları (buildings) içinde
6.000 adet sentetik konut üretir ve properties tablosuna aktarır.
"""
import os
import math
import random
import numpy as np
import psycopg2

SEED = 20260817
TARGET_COUNT = 6000
DATA_VERSION = os.getenv("DATA_VERSION", "osm-2026-08-20")

DB_HOST = os.getenv("PGHOST", "localhost")
DB_PORT = os.getenv("PGPORT", "5432")
DB_NAME = os.getenv("PGDATABASE", "vivido")
DB_USER = os.getenv("PGUSER", "vivido")
DB_PASS = os.getenv("PGPASSWORD_OVERRIDE") or os.getenv("PGPASSWORD") or "vivido"

def get_room_count(area):
    if area < 50:
        return '1+0'
    elif area <= 75:
        return '1+1'
    elif area <= 110:
        return '2+1'
    elif area <= 150:
        return '3+1'
    else:
        return '4+1'

def get_db_connection():
    passwords = [os.getenv("PGPASSWORD"), "degistir_beni_local_sifre", "vivido"]
    for pwd in passwords:
        if not pwd: continue
        try:
            conn = psycopg2.connect(
                host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=pwd
            )
            return conn
        except Exception:
            continue
    raise Exception("Could not connect to PostgreSQL with any password")

def main():
    random.seed(SEED)
    np.random.seed(SEED)

    conn = get_db_connection()
    cur = conn.cursor()

    print("PostGIS binaları ve mahalleleri okunuyor...")
    cur.execute("TRUNCATE TABLE properties CASCADE;")

    # Binaları ve ait oldukları mahalleleri al
    cur.execute("""
        SELECT b.id, b.levels, ST_AsText(ST_PointOnSurface(b.geom)), n.id, n.rent_index
        FROM buildings b
        JOIN neighborhoods n ON ST_Contains(n.geom, ST_PointOnSurface(b.geom));
    """)
    building_rows = cur.fetchall()

    if not building_rows:
        print("HATA: Hiç bina ve mahalle eşleşmesi bulunamadı!")
        return

    print(f"Eşleşen bina sayısı: {len(building_rows)}")

    # 6.000 kayda ulaşana kadar rastgele binalardan örnekle
    selected_buildings = random.choices(building_rows, k=TARGET_COUNT)

    inserted = 0
    # Regresyon katsayıları (TÜİK/TCMB kalibrasyonlu)
    beta0 = 5.2    # Baz kira seviyesi katsayısı
    beta1 = 0.35   # m2 katsayısı
    beta2 = -0.01  # bina yaşı cezası
    beta3 = 0.12   # asansör primi
    beta4 = 0.08   # otopark primi
    beta5 = 0.15   # eşyalı primi

    properties_batch = []

    for i, b in enumerate(selected_buildings):
        b_id, levels, centroid_wkt, n_id, n_rent_index = b
        ext_ref = f"SYN-{i+1:06d}"

        # m2 ~ Lognormal(mu=4.55, sigma=0.30), [35, 250] aralığında
        raw_m2 = float(np.random.lognormal(mean=4.55, sigma=0.30))
        area_m2 = int(max(35, min(250, round(raw_m2))))

        room_count = get_room_count(area_m2)

        # Bina yaşı ~ Gamma(k=2, theta=8), [0, 55]
        raw_age = float(np.random.gamma(shape=2, scale=8))
        building_age = int(max(0, min(55, round(raw_age))))

        # Katlar
        total_floors = levels if (levels and levels > 0) else random.randint(3, 12)
        floor_no = random.randint(0, total_floors)

        # Özellikler
        has_elevator = True if total_floors >= 5 else (random.random() < 0.15)
        has_parking = random.random() < 0.40
        is_furnished = random.random() < 0.25
        pets_allowed = random.random() < 0.35

        # Kira modeli
        ln_nb_index = math.log(float(n_rent_index))
        epsilon = float(np.random.normal(0, 0.14))

        ln_rent_m2 = (beta0 +
                      beta1 * math.log(area_m2) +
                      beta2 * building_age +
                      (beta3 if has_elevator else 0) +
                      (beta4 if has_parking else 0) +
                      (beta5 if is_furnished else 0) +
                      ln_nb_index +
                      epsilon)

        rent_m2 = math.exp(ln_rent_m2)
        raw_monthly_rent = rent_m2 * area_m2
        monthly_rent = round(raw_monthly_rent / 250.0) * 250.0  # en yakın 250 TL'ye yuvarla
        if monthly_rent < 4000:
            monthly_rent = 4000.0

        deposit = round(monthly_rent * random.uniform(1.0, 2.0) / 250.0) * 250.0

        properties_batch.append((
            ext_ref, centroid_wkt, b_id, n_id, monthly_rent, deposit,
            area_m2, room_count, floor_no, total_floors, building_age,
            has_elevator, has_parking, is_furnished, pets_allowed,
            True, DATA_VERSION
        ))

    print(f"{len(properties_batch)} adet sentetik konut verisi veritabanına aktarılıyor...")
    cur.executemany("""
        INSERT INTO properties (
            external_ref, geom, building_id, neighborhood_id, monthly_rent, deposit,
            area_m2, room_count, floor_no, total_floors, building_age,
            has_elevator, has_parking, is_furnished, pets_allowed,
            is_synthetic, data_version
        )
        VALUES (
            %s, ST_GeomFromText(%s, 4326), %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s,
            %s, %s
        );
    """, properties_batch)

    conn.commit()
    cur.close()
    conn.close()
    print("BAŞARILI: 6.000 sentetik kiralık konut verisi PostGIS veritabanına eklendi!")

if __name__ == "__main__":
    main()
