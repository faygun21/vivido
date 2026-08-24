#!/usr/bin/env python3
"""
Vivido — Precomputed Erişim Matrisi Üretici Betiği
Kaynak: docs/01-PROJE-PLANI.md §9.8

6.000 konut × 8 POI kategorisi için EN YAKIN POI'nin GERÇEK YÜRÜME süresini
hesaplar ve property_poi_access tablosuna yazar (48.000 satır).

Yöntem (§9.8'deki üç adım):
  1. PostGIS KNN (`<->`) ile kategori başına en yakın 5 aday POI
  2. Bu adayların gerçek yürüme süresi OSRM `/table` (foot profili) ile
  3. En küçüğü property_poi_access'e yazılır

⚠️ NEDEN OSRM: Önceki sürüm `ST_DistanceSphere / 72` kullanıyordu, yani
KUŞ UÇUŞU mesafe. Ürünün tüm iddiası "bu ev markete 4 dakika" üzerine kurulu;
kuş uçuşu binaları, vadileri ve yaya geçidi olmayan bulvarları yok sayar ve
süreleri sistematik olarak İYİMSER gösterir (gerçek yürüme tipik 1.3–1.6 kat).
Ayrıca KNN `LIMIT 5` ön-elemesi o haliyle anlamsızdı: aynı metrikle tekrar
minimum alınıyordu, yani 5 aday çekmenin hiçbir etkisi yoktu.

Gereksinim: osrm-foot servisi ayakta olmalı.
    docker compose --profile routing up -d osrm-foot
"""
import os
import sys
from collections import defaultdict

import psycopg2
import requests

DATA_VERSION = os.getenv("DATA_VERSION", "osm-2026-08-20")

DB_HOST = os.getenv("PGHOST", "localhost")
DB_PORT = os.getenv("PGPORT", "5432")
DB_NAME = os.getenv("PGDATABASE", "vivido")
DB_USER = os.getenv("PGUSER", "vivido")

# Konteyner içinden `osrm-foot`, host'tan `localhost:5001`.
OSRM_FOOT_URL = os.getenv("OSRM_FOOT_URL", "http://osrm-foot:5000")

# Kategori başına KNN aday sayısı (§9.8 adım 1).
CANDIDATES_PER_CATEGORY = 5

# Yürüme hızı — yalnızca OSRM bir adaya rota bulamazsa yedek tahmin için.
WALK_M_PER_MIN = 72.0


def get_db_connection():
    passwords = [os.getenv("PGPASSWORD"), "degistir_beni_local_sifre", "vivido"]
    for pwd in passwords:
        if not pwd:
            continue
        try:
            return psycopg2.connect(
                host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=pwd
            )
        except Exception:
            continue
    raise Exception("Could not connect to PostgreSQL with any password")


def fetch_candidates(cur):
    """Her konut × kategori için en yakın N aday POI'yi tek sorguda çeker."""
    print(f"PostGIS KNN: konut × kategori başına en yakın {CANDIDATES_PER_CATEGORY} aday seçiliyor...")
    cur.execute(
        """
        SELECT p.id,
               c.code,
               poi.id,
               ST_X(poi.geom), ST_Y(poi.geom),
               ST_DistanceSphere(p.geom, poi.geom),
               ST_X(p.geom), ST_Y(p.geom)
        FROM properties p
        CROSS JOIN poi_categories c
        JOIN LATERAL (
            SELECT id, geom
            FROM pois
            WHERE pois.category_code = c.code
            ORDER BY pois.geom <-> p.geom
            LIMIT %s
        ) poi ON true
        WHERE c.active
        ORDER BY p.id;
        """,
        (CANDIDATES_PER_CATEGORY,),
    )

    # property_id -> { 'coord': (lon, lat), 'cands': {category: [(poi_id, lon, lat, metre)]} }
    per_property = {}
    for prop_id, cat, poi_id, poi_lon, poi_lat, metre, p_lon, p_lat in cur:
        entry = per_property.setdefault(prop_id, {"coord": (p_lon, p_lat), "cands": defaultdict(list)})
        entry["cands"][cat].append((poi_id, poi_lon, poi_lat, metre))
    return per_property


def osrm_table(session, origin, destinations):
    """Tek kaynak → n hedef yürüme süresi/mesafesi. Hata olursa None döner."""
    coords = ";".join(f"{lon:.6f},{lat:.6f}" for lon, lat in [origin, *destinations])
    dest_idx = ";".join(str(i) for i in range(1, len(destinations) + 1))
    url = (
        f"{OSRM_FOOT_URL}/table/v1/foot/{coords}"
        f"?sources=0&destinations={dest_idx}&annotations=duration,distance"
    )
    try:
        response = session.get(url, timeout=30)
        if response.status_code != 200:
            return None
        body = response.json()
        if body.get("code") != "Ok":
            return None
        return body["durations"][0], body.get("distances", [[None] * len(destinations)])[0]
    except Exception:
        return None


def main():
    conn = get_db_connection()
    cur = conn.cursor()

    per_property = fetch_candidates(cur)
    print(f"{len(per_property)} konut için adaylar hazır. OSRM ({OSRM_FOOT_URL}) sorgulanıyor...")

    session = requests.Session()
    rows = []
    osrm_failures = 0

    for processed, (prop_id, data) in enumerate(per_property.items(), start=1):
        origin = data["coord"]

        # Tüm kategorilerin adaylarını TEK /table çağrısında topla:
        # 8 kategori × 5 aday = en fazla 40 hedef + 1 kaynak = 41 koordinat,
        # --max-table-size 200 sınırının çok altında.
        flat = []          # (category, poi_id, metre)
        destinations = []  # (lon, lat)
        for cat, cands in data["cands"].items():
            for poi_id, lon, lat, metre in cands:
                flat.append((cat, poi_id, metre))
                destinations.append((lon, lat))

        if not destinations:
            continue

        result = osrm_table(session, origin, destinations)
        if result is None:
            osrm_failures += 1
            durations = [None] * len(destinations)
            distances = [None] * len(destinations)
        else:
            durations, distances = result

        # Kategori bazında en kısa süreli adayı seç.
        best = {}
        for i, (cat, poi_id, metre) in enumerate(flat):
            secs = durations[i] if i < len(durations) else None
            if secs is None:
                # OSRM rota bulamadı — kuş uçuşu yedek tahmin.
                minutes = metre / WALK_M_PER_MIN
                dist_m = metre
            else:
                minutes = secs / 60.0
                dist_m = distances[i] if i < len(distances) and distances[i] is not None else metre

            if cat not in best or minutes < best[cat][0]:
                best[cat] = (minutes, dist_m, poi_id)

        for cat, (minutes, dist_m, poi_id) in best.items():
            rows.append((prop_id, cat, poi_id, round(minutes, 1), int(round(dist_m)), DATA_VERSION))

        if processed % 500 == 0:
            print(f"  {processed}/{len(per_property)} konut işlendi...")

    print(f"Erişim matrisi tablosu temizleniyor ve {len(rows)} satır yazılıyor...")
    cur.execute("TRUNCATE TABLE property_poi_access CASCADE;")
    cur.executemany(
        """
        INSERT INTO property_poi_access
            (property_id, category_code, poi_id, duration_min, distance_m, data_version)
        VALUES (%s, %s, %s, %s, %s, %s);
        """,
        rows,
    )

    conn.commit()
    cur.close()
    conn.close()

    if osrm_failures:
        print(f"UYARI: {osrm_failures} konut için OSRM yanıt vermedi, kuş uçuşu tahmine düşüldü.")
    print(f"BAŞARILI: {len(rows)} satır erişim matrisi (property_poi_access) veritabanına aktarıldı!")


if __name__ == "__main__":
    sys.exit(main())
