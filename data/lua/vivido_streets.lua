-- ══════════════════════════════════════════════════════════════════════
--  Vivido — osm2pgsql flex style: adlı sokaklar
--
--  Görevi: Çankaya OSM kesitinden ADI OLAN yol parçalarını `osm_streets`
--          ara tablosuna aktarmak. Şemadaki gerçek `streets` tablosu
--          data/scripts/05_merge_streets_into_schema.sql ile doldurulur.
--
--  ⚠️ Neden ayrı bir style dosyası: vivido_pois.lua yalnızca `osm_pois` ve
--  `osm_buildings` tanımlıyor. osm2pgsql `define_table` ile verilen adı
--  DÜŞÜRÜP YENİDEN YARATIR — sokakları o dosyaya eklemek, zaten koşmuş ve
--  seed.sql'e girmiş POI/bina çıkarımını yeniden koşmayı zorunlu kılardı.
--  Ayrı dosya sayesinde bu adım tek başına, dakikalar içinde çalışır ve
--  mevcut ara tablolara DOKUNMAZ (K-01: tek şema kaynağı korunur).
-- ══════════════════════════════════════════════════════════════════════

local data_version = os.getenv("DATA_VERSION") or "osm-2026-08-20"

local streets = osm2pgsql.define_table({
    name = 'osm_streets',
    ids = { type = 'way', id_column = 'osm_id' },
    columns = {
        { column = 'name', type = 'text', not_null = true },
        { column = 'geom', type = 'linestring', projection = 4326, not_null = true },
        { column = 'data_version', type = 'text', not_null = true },
    }
})

-- Adres olarak anlamlı yol sınıfları.
--
-- `motorway` ve `trunk` BİLEREK DIŞARIDA: otoyol bir adres değildir ve
-- kenarındaki binaya "Anadolu Otoyolu" yazmak yanıltıcı olur. `footway`,
-- `path`, `steps` gibi yaya bağlantıları da dışarıda — çoğunun adı yok,
-- olanlar da ("Park Yolu") adres yerine geçmiyor.
local ADRESLIK_YOLLAR = {
    primary      = true,
    primary_link = true,
    secondary    = true,
    secondary_link = true,
    tertiary     = true,
    tertiary_link = true,
    unclassified = true,
    residential  = true,
    living_street = true,
    pedestrian   = true,
    service      = true,
}

function osm2pgsql.process_way(object)
    local highway = object.tags.highway
    if not highway or not ADRESLIK_YOLLAR[highway] then return end

    local name = object.tags.name
    if not name or name == '' then return end

    -- Kapalı halka (döner kavşak, otopark çevresi) adres olarak kullanılamaz.
    if object.is_closed then return end

    streets:insert({
        name = name,
        geom = object:as_linestring(),
        data_version = data_version
    })
end
