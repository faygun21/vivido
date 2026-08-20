-- ══════════════════════════════════════════════════════════════════════
--  Vivido — osm2pgsql flex style file
--
--  Kaynak: docs/01-PROJE-PLANI.md §9.3 & db/schema/002_seed_reference.sql
--  Görevi: Çankaya OSM verisinden 8 POI kategorisini `pois` tablosuna
--          ve konut binalarını `buildings` tablosuna aktarmak.
-- ══════════════════════════════════════════════════════════════════════

local data_version = os.getenv("DATA_VERSION") or "osm-2026-08-20"

-- ─── Tablo Tanımları ───

local tables = {}

tables.pois = osm2pgsql.define_table({
    name = 'pois',
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'name', type = 'text' },
        { column = 'category_code', type = 'text', not_null = true },
        { column = 'geom', type = 'point', projection = 4326, not_null = true },
        { column = 'data_version', type = 'text', not_null = true },
    }
})

tables.buildings = osm2pgsql.define_table({
    name = 'buildings',
    ids = { type = 'way', id_column = 'osm_id' },
    columns = {
        { column = 'geom', type = 'polygon', projection = 4326, not_null = true },
        { column = 'levels', type = 'smallint' },
        { column = 'data_version', type = 'text', not_null = true },
    }
})

-- ─── POI Kategori Eşleme Mantığı ───

local function get_poi_category(tags)
    local shop = tags.shop
    local amenity = tags.amenity
    local highway = tags.highway
    local railway = tags.railway
    local leisure = tags.leisure
    local landuse = tags.landuse

    -- 1. Market
    if shop == 'supermarket' or shop == 'convenience' or shop == 'greengrocer' or shop == 'butcher' then
        return 'market'
    end

    -- 2. Eczane
    if amenity == 'pharmacy' then
        return 'pharmacy'
    end

    -- 3. Toplu Taşıma
    if highway == 'bus_stop' or amenity == 'bus_station' or railway == 'tram_stop' or (railway == 'station' and tags.station == 'subway') then
        return 'transit'
    end

    -- 4. Kafe & Restoran
    if amenity == 'cafe' or amenity == 'restaurant' or amenity == 'fast_food' or shop == 'bakery' then
        return 'food'
    end

    -- 5. Park & Yeşil Alan
    if leisure == 'park' or leisure == 'garden' or leisure == 'playground' or landuse == 'recreation_ground' then
        return 'park'
    end

    -- 6. Spor Salonu
    if leisure == 'fitness_centre' or leisure == 'sports_centre' or leisure == 'pitch' or leisure == 'swimming_pool' then
        return 'gym'
    end

    -- 7. Okul
    if amenity == 'school' or amenity == 'kindergarten' then
        return 'school'
    end

    -- 8. Sağlık
    if amenity == 'hospital' or amenity == 'clinic' or amenity == 'doctors' then
        return 'health'
    end

    return nil
end

-- ─── Konut Bina Filtresi ───

local function is_residential_building(building_tag)
    if not building_tag then return false end
    if building_tag == 'no' then return false end

    local residential_types = {
        residential = true,
        apartments = true,
        house = true,
        yes = true,
        detached = true,
        dormitory = true
    }
    return residential_types[building_tag] == true
end

-- ─── Process Node (Noktalar) ───

function osm2pgsql.process_node(object)
    local category = get_poi_category(object.tags)
    if category then
        tables.pois:insert({
            name = object.tags.name,
            category_code = category,
            geom = object:as_point(),
            data_version = data_version
        })
    end
end

-- ─── Process Way (Çizgiler / Poligonlar) ───

function osm2pgsql.process_way(object)
    local category = get_poi_category(object.tags)
    if category and object.is_closed then
        tables.pois:insert({
            name = object.tags.name,
            category_code = category,
            geom = object:as_polygon():centroid(),
            data_version = data_version
        })
    end

    if object.is_closed and is_residential_building(object.tags.building) then
        local levels_num = nil
        if object.tags['building:levels'] then
            levels_num = tonumber(object.tags['building:levels'])
        end

        tables.buildings:insert({
            geom = object:as_polygon(),
            levels = levels_num,
            data_version = data_version
        })
    end
end
