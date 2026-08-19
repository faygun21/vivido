#!/usr/bin/env python3
"""
Load Çankaya neighborhood boundaries GeoJSON into PostGIS neighborhoods table.
"""
import os
import json
import psycopg2
from shapely.geometry import shape, MultiPolygon, Polygon

DB_HOST = os.getenv("PGHOST", "localhost")
DB_PORT = os.getenv("PGPORT", "5432")
DB_NAME = os.getenv("PGDATABASE", "vivido")
DB_USER = os.getenv("PGUSER", "vivido")
DB_PASS = os.getenv("PGPASSWORD", "vivido")
DATA_VERSION = os.getenv("DATA_VERSION", "osm-2026-08-20")

GEOJSON_PATH = "/work/data/cankaya-ankara-mahalles.geojson"

def main():
    if not os.path.exists(GEOJSON_PATH):
        print(f"File not found: {GEOJSON_PATH}")
        return

    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASS
    )
    cur = conn.cursor()

    # Clear existing neighborhoods
    cur.execute("TRUNCATE TABLE neighborhoods CASCADE;")

    with open(GEOJSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    inserted = 0
    for feature in data.get("features", []):
        props = feature.get("properties", {})
        name = props.get("name") or props.get("MAHALLE_ADI") or "Bilinmeyen Mahalle"
        geom_obj = shape(feature.get("geometry"))

        if isinstance(geom_obj, Polygon):
            multi_geom = MultiPolygon([geom_obj])
        elif isinstance(geom_obj, MultiPolygon):
            multi_geom = geom_obj
        else:
            continue

        wkt = multi_geom.wkt

        cur.execute(
            """
            INSERT INTO neighborhoods (name, geom, rent_index, data_version)
            VALUES (%s, ST_Multi(ST_GeomFromText(%s, 4326)), 1.000, %s);
            """,
            (name, wkt, DATA_VERSION)
        )
        inserted += 1

    conn.commit()
    cur.close()
    conn.close()
    print(f"Successfully loaded {inserted} neighborhoods into PostGIS!")

if __name__ == "__main__":
    main()
