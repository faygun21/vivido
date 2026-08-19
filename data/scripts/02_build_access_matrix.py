#!/usr/bin/env python3
"""
Vivido — Precomputed Erişim Matrisi Üretici Betiği
Kaynak: docs/01-PROJE-PLANI.md §9.8

6.000 konut × 8 POI kategorisi için en yakın POI'yi PostGIS KNN (<->) ve mesafe
hesaplaması ile tespit edip property_poi_access tablosuna yazar (48.000 satır).
"""
import os
import psycopg2

DATA_VERSION = os.getenv("DATA_VERSION", "osm-2026-08-20")

DB_HOST = os.getenv("PGHOST", "localhost")
DB_PORT = os.getenv("PGPORT", "5432")
DB_NAME = os.getenv("PGDATABASE", "vivido")
DB_USER = os.getenv("PGUSER", "vivido")
DB_PASS = os.getenv("PGPASSWORD_OVERRIDE") or os.getenv("PGPASSWORD") or "vivido"

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
    conn = get_db_connection()
    cur = conn.cursor()

    print("Erişim matrisi tablosu temizleniyor...")
    cur.execute("TRUNCATE TABLE property_poi_access CASCADE;")

    print("PostGIS KNN ile her konut × 8 kategori için en yakın POI ve yürüme süresi hesaplanıyor...")

    # Yürüme hızı ~1.2 m/s = 72 m/dk
    # ST_DistanceSphere (metre cinsinden küresel mesafe)
    cur.execute("""
        INSERT INTO property_poi_access (property_id, category_code, poi_id, duration_min, distance_m, data_version)
        SELECT DISTINCT ON (p.id, c.code)
            p.id AS property_id,
            c.code AS category_code,
            poi.id AS poi_id,
            ROUND((ST_DistanceSphere(p.geom, poi.geom) / 72.0)::numeric, 1) AS duration_min,
            ROUND(ST_DistanceSphere(p.geom, poi.geom))::integer AS distance_m,
            %s AS data_version
        FROM properties p
        CROSS JOIN poi_categories c
        JOIN LATERAL (
            SELECT id, geom
            FROM pois
            WHERE category_code = c.code AND active = true
            ORDER BY pois.geom <-> p.geom
            LIMIT 5
        ) poi ON true
        ORDER BY p.id, c.code, ST_DistanceSphere(p.geom, poi.geom) ASC;
    """, (DATA_VERSION,))

    inserted = cur.rowcount
    conn.commit()
    cur.close()
    conn.close()
    print(f"BAŞARILI: {inserted} satır erişim matrisi (property_poi_access) veritabanına aktarıldı!")

if __name__ == "__main__":
    main()
