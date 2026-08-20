/**
 * Ortam yapılandırması. Tek nokta — `import.meta.env` başka yerde okunmaz.
 */

/**
 * API kök adresi.
 *
 * ⚠️ `.env` içindeki değer ZATEN `/api/v1` ile biter.
 * İstek yollarına tekrar `/api/v1` eklemeyin — `/auth/login` yeterli.
 */
export const API_BASE_URL: string =
  import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:5000/api/v1';

/**
 * ⭐ Kendi vektör karo sunucumuz (tercih edilen altlık).
 *
 * `cankaya.mbtiles` (Planetiler çıktısı, OpenMapTiles şeması) tileserver-gl
 * ile sunulur; sokaklar, binalar, su ve yeşil alanlar buradan gelir.
 * Boş bırakılırsa harita yalnızca GeoJSON katmanlarıyla çizilir.
 *
 *   docker compose --profile routing up -d tileserver
 *   VITE_TILE_URL=http://localhost:8080/data/cankaya.json
 */
export const TILE_URL: string =
  import.meta.env.VITE_TILE_URL ?? '';

/**
 * Karo sunucusunun yazı tipi (glyph) uç noktası.
 *
 * MapLibre'da metin çizen her `symbol` katmanı buna muhtaç. Karo sunucusu
 * yoksa etiket katmanları hiç eklenmez — dış bir font kaynağına bağlanmıyoruz.
 */
export const GLYPHS_URL: string =
  import.meta.env.VITE_GLYPHS_URL ?? 'http://localhost:8080/fonts/{fontstack}/{range}.pbf';

/**
 * Son çare altlık: public OSM raster karoları.
 *
 * ⚠️ `docs/01-PROJE-PLANI.md` §3 "Public OSM tile **kullanılmaz**" diyor.
 * Yalnızca `TILE_URL` yokken ve geliştirici sokakları görmek istediğinde
 * elle açılır; demoya girmemeli. Doğru çözüm yukarıdaki `TILE_URL`'dir.
 */
export const USE_RASTER_BASEMAP: boolean =
  import.meta.env.VITE_USE_RASTER_BASEMAP === 'true';

/**
 * Harita atfı — GÖRÜNÜR olmak zorunda, kapatılamaz.
 *
 * İki ayrı yükümlülük var:
 *  · OSM verisi **ODbL 1.0** → "© OpenStreetMap katkıcıları"
 *  · Planetiler'ın OpenMapTiles profiliyle üretilen vektör karolar
 *    **CC-BY** ile yeniden kullanılabilir ve OpenMapTiles'a görünür
 *    kredi ister (Planetiler çıktısında da bu uyarı basılıyor).
 */
export const MAP_ATTRIBUTION =
  '© OpenStreetMap katkıcıları · © OpenMapTiles';

/*
 * MSW (sahte API) anahtarı BURADA DEĞİL, `main.tsx` içinde satır içi kontrol
 * edilir. Sebep: buraya bir sabit koyup oradan okursak Vite modül sınırını
 * aşarak sabit katlaması yapamıyor ve MSW'nin ~420 kB'lık parçası üretim
 * çıktısına giriyor (çalışmasa bile indirilir). `import.meta.env.DEV`
 * doğrudan `main.tsx` içinde yazıldığında derleyici tüm dalı eliyor.
 */
