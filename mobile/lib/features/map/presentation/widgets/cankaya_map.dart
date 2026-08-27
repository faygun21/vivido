import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:maplibre/maplibre.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/models.dart';
import '../../../location_analysis/domain/location_analysis.dart';
import '../../../location_search/domain/location_search_models.dart';
import '../../../map_data/domain/map_data_models.dart';
import '../../../map_data/presentation/poi_category_colors.dart';
import '../../../routes/domain/route_models.dart';

typedef MapPointCallback = void Function(double lat, double lon);
typedef MapBoundsCallback = void Function(MapViewportBounds bounds);
typedef PoiTapCallback = void Function(PoiMapItem poi);
typedef PropertyTapCallback = void Function(PropertyMapItem property);

const _poiSourceId = 'vivido-pois';
const _propertySourceId = 'vivido-properties';
const _poiPointLayerId = 'vivido-poi-points';
// NOT: `_poiClusterLayerId` KALDIRILDI — mor küme katmanı artık çizilmiyor
// (gerekçe stildeki açıklamada). Sabiti bırakmak, ileride birinin var
// olmayan bir katmanı sorgulamasına davetiye çıkarırdı.
const _propertyPointLayerId = 'vivido-property-points';
const _propertyClusterLayerId = 'vivido-property-clusters';
const _routeSourceId = 'vivido-active-route';
const _routeCasingLayerId = 'vivido-route-casing';
const _routeLineLayerId = 'vivido-route-line';
const _districtSourceId = 'vivido-district';
const _districtFillLayerId = 'vivido-district-fill';
const _districtLineLayerId = 'vivido-district-line';
const _propertyClusterCountLayerId = 'vivido-property-cluster-count';
const _propertyIconLayerId = 'vivido-property-icons';
const _poiIconLayerId = 'vivido-poi-icons';
const _propertyIconImageId = 'vivido-ev-ikon';

/// Kategorisi eşleşmeyen POI'ler için — ikon katmanı `icon-image` bulamazsa
/// MapLibre o simgeyi hiç çizmez, altındaki renkli daire yine görünür.
const _poiFallbackIconId = 'vivido-poi-ikon-market';

String _poiIconId(String categoryCode) => 'vivido-poi-ikon-$categoryCode';

/// İkonların haritaya kaydedildiği piksel boyu.
///
/// Kaynak SVG'ler 24×24 viewBox; 3× çözünürlükte rasterleştiriyoruz ki
/// yüksek yoğunluklu ekranlarda bulanık durmasınlar. Ekrandaki boy
/// `72 × icon-size` olarak hesaplanıyor (katman tanımlarındaki notlara bakın).
const int _iconRenderPx = 72;
const double _iconRenderPxD = 72;

/// Çankaya sınırı — `pubspec.yaml` altında kayıtlı varlık.
const _districtAssetPath = 'assets/geo/cankaya.geojson';

/// Sınır poligonu bir kez okunup KODLANMIŞ hâliyle burada tutuluyor.
///
/// Harita her kurulduğunda 124 KB'lık dosyayı yeniden okuyup ayrıştırmak
/// gereksiz; sekmeler arasında gidip gelirken bu widget defalarca yeniden
/// kuruluyor. `updateGeoJsonSource` zaten String beklediği için `jsonEncode`
/// sonucunu saklıyoruz — her seferinde yeniden kodlamaya da gerek kalmıyor.
String? _cachedDistrictGeoJson;

class CankayaMap extends StatefulWidget {
  const CankayaMap({
    required this.anchors,
    this.onMapTap,
    this.pendingPoint,
    this.focus,
    this.analysisCenter,
    this.walkingMinutes = defaultWalkingMinutes,
    this.analysisRadiusKm = defaultAnalysisRadiusKm,
    this.pois = const [],
    this.properties = const [],
    this.onBoundsChanged,
    this.onPoiTap,
    this.onPropertyTap,
    this.route,
    super.key,
  });

  final List<Anchor> anchors;
  final MapPointCallback? onMapTap;
  final Geographic? pendingPoint;
  final LocationSearchResult? focus;
  final AnalysisCoordinate? analysisCenter;
  final int walkingMinutes;
  final double analysisRadiusKm;
  final List<PoiMapItem> pois;
  final List<PropertyMapItem> properties;
  final MapBoundsCallback? onBoundsChanged;
  final PoiTapCallback? onPoiTap;
  final PropertyTapCallback? onPropertyTap;
  final RouteDetail? route;

  @override
  State<CankayaMap> createState() => _CankayaMapState();
}

class _CankayaMapState extends State<CankayaMap> {
  MapController? _mapController;
  StyleController? _styleController;

  @override
  void didUpdateWidget(covariant CankayaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focus?.id != widget.focus?.id) {
      _focusOnResult();
    }
    if (!identical(oldWidget.pois, widget.pois) ||
        !identical(oldWidget.properties, widget.properties) ||
        !identical(oldWidget.route, widget.route)) {
      unawaited(_updateMapSources());
    }
    if (!identical(oldWidget.route, widget.route) && widget.route != null) {
      unawaited(_fitRoute());
    }
  }

  Future<void> _updateMapSources() async {
    final style = _styleController;
    if (style == null) return;

    try {
      await Future.wait([
        style.updateGeoJsonSource(
          id: _poiSourceId,
          data: _poiFeatureCollection(widget.pois),
        ),
        style.updateGeoJsonSource(
          id: _propertySourceId,
          data: _propertyFeatureCollection(widget.properties),
        ),
        style.updateGeoJsonSource(
          id: _routeSourceId,
          data: _routeFeatureCollection(widget.route),
        ),
      ]);
    } on Object {
      // Stil yeniden yüklenirken eski controller kısa süreliğine geçersiz
      // olabilir. Yeni onStyleLoaded çağrısı güncel veriyi tekrar yazar.
    }
  }

  /// Konut ve POI ikonlarını harita motoruna imaj olarak kaydeder.
  ///
  /// ⚠️ `addImageFromWidget` + `SvgPicture.asset` KULLANMAYIN — denendi,
  /// yarış durumu üretiyor:
  ///
  /// `addImageFromWidget` widget'ı TEK BİR çizim geçişinde piksele döküyor.
  /// `SvgPicture.asset` ise dosyayı ASENKRON yüklüyor ve hazır olana kadar
  /// boş bir kutu çiziyor. Önbellek soğuksa (uygulamanın ilk açılışı, temiz
  /// kurulum, yavaş cihaz) o tek geçiş BOŞ kareyi yakalıyor ve haritaya
  /// içi boş bir imaj kaydediliyor. Belirti: konutlar içi boş beyaz nokta,
  /// POI'ler ikonsuz renkli daire. Uygulama yeniden kurulunca önbellek
  /// ısındığı için "kendiliğinden düzeliyor" gibi görünüyor — düzelmiyor,
  /// sadece yarışı kazanıyor.
  ///
  /// Bu yüzden SVG önce `vg.loadPicture` ile AÇIKÇA çözülüyor (await), sonra
  /// tuvale senkron çiziliyor. Widget ağacı yok, bekleyecek bir şey yok.
  ///
  /// Web'deki AYNI dosyalar kullanılıyor; ikonu mobil için yeniden çizmek
  /// iki üründe iki farklı simge demek olurdu. SVG'ler siyah dolgulu,
  /// `saveLayer` + `srcIn` ile paletin rengine boyanıyorlar.
  Future<void> _loadMapIcons() async {
    final style = _styleController;
    if (style == null) return;

    Future<void> register(String id, String asset, Color color) async {
      PictureInfo? info;
      try {
        info = await vg.loadPicture(SvgAssetLoader(asset), null);

        final source = info.size;
        if (source.isEmpty) return;

        await style.addImageFromCanvas(
          id: id,
          width: _iconRenderPx,
          height: _iconRenderPx,
          painter: (canvas) {
            // Renklendirme katmanı: srcIn, altındaki çizimin ALFA'sını
            // koruyup rengini değiştiriyor. Doğrudan `drawPicture` üstüne
            // renk basmak simgenin boşluklarını da doldururdu.
            canvas.saveLayer(
              const Rect.fromLTWH(0, 0, _iconRenderPxD, _iconRenderPxD),
              Paint()..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
            );
            canvas.scale(
              _iconRenderPxD / source.width,
              _iconRenderPxD / source.height,
            );
            canvas.drawPicture(info!.picture);
            canvas.restore();
          },
        );
      } on Object {
        // Tek bir ikon yüklenemezse harita çalışmaya devam etsin: ilgili
        // katman o simgeyi çizmez, altındaki renkli daire yerinde kalır.
      } finally {
        // `loadPicture` dokümantasyonu elden çıkarmayı ÇAĞIRANA bırakıyor.
        info?.picture.dispose();
      }
    }

    await register(
      _propertyIconImageId,
      'assets/icons/home_kahve.svg',
      AppColors.accent,
    );

    for (final entry in poiCategoryIconAssets.entries) {
      // POI ikonu BEYAZ: altında kategori renginde dolu bir daire var,
      // ikonu da renkli yapmak ikisini birbirine karıştırırdı.
      await register(_poiIconId(entry.key), entry.value, Colors.white);
    }
  }

  /// Çankaya sınırını varlıklardan okuyup haritaya yazar.
  ///
  /// ⚠️ `cankaya.geojson` sınır poligonunun YANINDA bir de etiket `Point`'i
  /// taşıyor (2 özellik). Filtrelemezsek `fill` katmanı bir noktayı boyamaya
  /// çalışır; MapLibre bunu sessizce yok sayar ama `line` katmanı da onu
  /// çizmeye kalkar. Web tarafında da aynı filtre var.
  Future<void> _loadDistrictBoundary() async {
    final style = _styleController;
    if (style == null) return;

    try {
      var geojson = _cachedDistrictGeoJson;
      if (geojson == null) {
        final raw = await rootBundle.loadString(_districtAssetPath);
        final parsed = jsonDecode(raw) as Map<String, Object?>;
        final features = (parsed['features'] as List<Object?>? ?? const [])
            .whereType<Map<String, Object?>>()
            .where((feature) {
              final type =
                  (feature['geometry'] as Map<String, Object?>?)?['type'];
              return type == 'Polygon' || type == 'MultiPolygon';
            })
            .toList();
        geojson = jsonEncode({
          'type': 'FeatureCollection',
          'features': features,
        });
        _cachedDistrictGeoJson = geojson;
      }

      await style.updateGeoJsonSource(id: _districtSourceId, data: geojson);
    } on Object {
      // Sınır çizilemezse harita yine çalışır — yalnızca ilçe hattı eksik
      // kalır. Kullanıcıyı bununla rahatsız etmenin anlamı yok.
    }
  }

  void _reportBounds() {
    final controller = _mapController;
    if (controller == null || widget.onBoundsChanged == null) return;
    try {
      final bounds = controller.getVisibleRegion();
      widget.onBoundsChanged!(
        MapViewportBounds(
          west: bounds.longitudeWest,
          south: bounds.latitudeSouth,
          east: bounds.longitudeEast,
          north: bounds.latitudeNorth,
        ),
      );
    } on Object {
      // Native harita ilk kareyi çizmeden visible region hazır olmayabilir.
    }
  }

  void _handleMapClick(MapEventClick event) {
    final controller = _mapController;
    if (controller == null) {
      widget.onMapTap?.call(event.point.lat, event.point.lon);
      return;
    }

    final propertyHits = controller.featuresAtPoint(
      event.screenPoint,
      layerIds: const [_propertyPointLayerId],
    );
    final propertyId = propertyHits.firstOrNull?.properties['id']?.toString();
    if (propertyId != null) {
      for (final property in widget.properties) {
        if (property.id == propertyId) {
          widget.onPropertyTap?.call(property);
          return;
        }
      }
    }

    final poiHits = controller.featuresAtPoint(
      event.screenPoint,
      layerIds: const [_poiPointLayerId],
    );
    final poiId = poiHits.firstOrNull?.properties['id']?.toString();
    if (poiId != null) {
      for (final poi in widget.pois) {
        if (poi.id == poiId) {
          widget.onPoiTap?.call(poi);
          return;
        }
      }
    }

    // Yalnızca KONUT kümesi sorgulanıyor: POI küme katmanı stilden
    // kaldırıldı ve var olmayan bir katman id'si sorgulamak her haritaya
    // dokunuşta hataya düşürürdü.
    final clusterHits = controller.featuresAtPoint(
      event.screenPoint,
      layerIds: const [_propertyClusterLayerId],
    );
    if (clusterHits.isNotEmpty) {
      final camera = controller.getCamera();
      unawaited(
        controller.animateCamera(
          center: event.point,
          zoom: (camera.zoom + 2).clamp(8, 18).toDouble(),
          nativeDuration: const Duration(milliseconds: 400),
        ),
      );
      return;
    }

    widget.onMapTap?.call(event.point.lat, event.point.lon);
  }

  void _focusOnResult() {
    final controller = _mapController;
    final result = widget.focus;
    if (controller == null || result == null) return;

    final bounds = result.bounds;
    if (bounds != null) {
      unawaited(
        controller.fitBounds(
          bounds: LngLatBounds(
            longitudeWest: bounds.west,
            longitudeEast: bounds.east,
            latitudeSouth: bounds.south,
            latitudeNorth: bounds.north,
          ),
          padding: const EdgeInsets.fromLTRB(40, 150, 40, 70),
          nativeDuration: const Duration(milliseconds: 700),
          webMaxZoom: 16,
        ),
      );
      return;
    }

    unawaited(
      controller.animateCamera(
        center: Geographic(lon: result.longitude, lat: result.latitude),
        zoom: 16,
        nativeDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  Future<void> _fitRoute() async {
    final controller = _mapController;
    final route = widget.route;
    if (controller == null || route == null) return;

    final coordinates = <List<double>>[
      if (route.geometry.isNotEmpty) ...route.geometry,
      if (route.geometry.isEmpty) ...[
        [route.start.longitude, route.start.latitude],
        for (final stop in route.stops)
          [stop.property.longitude, stop.property.latitude],
      ],
    ];
    if (coordinates.isEmpty) return;

    var west = coordinates.first[0];
    var east = coordinates.first[0];
    var south = coordinates.first[1];
    var north = coordinates.first[1];
    for (final point in coordinates.skip(1)) {
      west = point[0] < west ? point[0] : west;
      east = point[0] > east ? point[0] : east;
      south = point[1] < south ? point[1] : south;
      north = point[1] > north ? point[1] : north;
    }
    if ((east - west).abs() < 0.002) {
      west -= 0.002;
      east += 0.002;
    }
    if ((north - south).abs() < 0.002) {
      south -= 0.002;
      north += 0.002;
    }

    try {
      await controller.fitBounds(
        bounds: LngLatBounds(
          longitudeWest: west,
          longitudeEast: east,
          latitudeSouth: south,
          latitudeNorth: north,
        ),
        padding: const EdgeInsets.all(46),
        nativeDuration: const Duration(milliseconds: 650),
        webMaxZoom: 16,
      );
    } on Object {
      // Sekme veya sayfa hızlı kapatıldığında native harita controller'ı
      // dispose edilmiş olabilir; geç gelen kamera işlemi uygulamayı bozmasın.
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysisCenter = widget.analysisCenter;
    final analysisPolygons =
        analysisCenter == null
            ? const <Feature<Polygon>>[]
            : <Feature<Polygon>>[
              _polygonFeature(
                center: analysisCenter,
                radiusMetres: widget.analysisRadiusKm * 1000,
              ),
            ];
    final walkingPolygons =
        analysisCenter == null
            ? const <Feature<Polygon>>[]
            : <Feature<Polygon>>[
              _polygonFeature(
                center: analysisCenter,
                radiusMetres: walkingRadiusMetres(widget.walkingMinutes),
              ),
            ];
    final markers = <Marker>[
      for (final anchor in widget.anchors)
        Marker(
          point: Geographic(lon: anchor.lon, lat: anchor.lat),
          size: const Size(42, 48),
          alignment: Alignment.bottomCenter,
          child: _AnchorPin(priority: anchor.priority),
        ),
      if (widget.pendingPoint != null)
        Marker(
          point: widget.pendingPoint!,
          size: const Size(46, 52),
          alignment: Alignment.bottomCenter,
          child: const Icon(
            Icons.add_location_alt,
            size: 46,
            color: Color(0xFFEF4444),
          ),
        ),
      if (widget.focus != null)
        Marker(
          point: Geographic(
            lon: widget.focus!.longitude,
            lat: widget.focus!.latitude,
          ),
          size: const Size(52, 56),
          alignment: Alignment.bottomCenter,
          child: const Icon(
            Icons.location_searching,
            size: 50,
            color: Color(0xFFB3261E),
            shadows: [
              Shadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      if (analysisCenter != null)
        Marker(
          point: Geographic(
            lon: analysisCenter.longitude,
            lat: analysisCenter.latitude,
          ),
          size: const Size.square(22),
          alignment: Alignment.center,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFF7C2D12), width: 2),
              ),
            ),
          ),
        ),
      if (widget.route != null)
        Marker(
          point: Geographic(
            lon: widget.route!.start.longitude,
            lat: widget.route!.start.latitude,
          ),
          size: const Size.square(42),
          alignment: Alignment.center,
          child: const _RouteStartPin(),
        ),
      if (widget.route != null)
        for (final stop in widget.route!.stops)
          Marker(
            point: Geographic(
              lon: stop.property.longitude,
              lat: stop.property.latitude,
            ),
            size: const Size(42, 48),
            alignment: Alignment.bottomCenter,
            child: _RouteStopPin(sequence: stop.sequence),
          ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: const Color(0xFFE8F0ED),
        child: MapLibreMap(
          onMapCreated: (controller) {
            _mapController = controller;
            _focusOnResult();
          },
          onStyleLoaded: (style) {
            _styleController = style;
            unawaited(_loadMapIcons());
            unawaited(_loadDistrictBoundary());
            unawaited(_updateMapSources());
            if (widget.route != null) unawaited(_fitRoute());
            _reportBounds();
          },
          options: MapOptions(
            initStyle: _mapStyle,
            initCenter: Geographic(lon: 32.85, lat: 39.87),
            initZoom: 10.7,
            minZoom: 8,
            maxZoom: 18,
            androidForegroundLoadColor: const Color(0xFFE8F0ED),
          ),
          onEvent: (event) {
            if (event is MapEventClick) {
              _handleMapClick(event);
            } else if (event is MapEventCameraIdle) {
              _reportBounds();
            }
          },
          layers: [
            PolygonLayer(
              polygons: analysisPolygons,
              color: const Color(0x1A0F766E),
              outlineColor: const Color(0xFF0F766E),
            ),
            PolygonLayer(
              polygons: walkingPolygons,
              color: const Color(0x38F59E0B),
              outlineColor: const Color(0xFFB45309),
            ),
          ],
          children: [WidgetLayer(markers: markers), const SourceAttribution()],
        ),
      ),
    );
  }
}

Feature<Polygon> _polygonFeature({
  required AnalysisCoordinate center,
  required double radiusMetres,
}) {
  final ring = createRadiusRing(center: center, radiusMetres: radiusMetres);
  return Feature(
    geometry: Polygon.from([
      [
        for (final point in ring)
          Geographic(lon: point.longitude, lat: point.latitude),
      ],
    ]),
  );
}

class _AnchorPin extends StatelessWidget {
  const _AnchorPin({required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(
          Icons.location_on,
          size: 46,
          color: Theme.of(context).colorScheme.primary,
          shadows: const [
            Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '$priority',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteStartPin extends StatelessWidget {
  const _RouteStartPin();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF1D4ED8),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
    ),
    child: const Icon(Icons.flag, color: Colors.white, size: 22),
  );
}

class _RouteStopPin extends StatelessWidget {
  const _RouteStopPin({required this.sequence});

  final int sequence;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.topCenter,
    children: [
      const Icon(
        Icons.location_on,
        size: 46,
        color: Color(0xFF1D4ED8),
        shadows: [
          Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          '$sequence',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    ],
  );
}

String _poiFeatureCollection(List<PoiMapItem> pois) => jsonEncode({
  'type': 'FeatureCollection',
  'features': [
    for (final poi in pois)
      {
        'type': 'Feature',
        'properties': {
          'id': poi.id,
          'name': poi.name,
          'category': poi.categoryCode,
          // İkon id'si burada, ÖZELLİK olarak hesaplanıyor. Alternatifi
          // katman içinde uzun bir `match` ifadesi yazmaktı; kategori
          // listesi büyüdükçe stil okunamaz hâle gelirdi. Tanımsız
          // kategorilerde bilinen bir id'ye düşüyoruz — MapLibre var
          // olmayan bir `icon-image` gördüğünde o simgeyi hiç çizmez.
          'iconId': poiCategoryIconAssets.containsKey(poi.categoryCode)
              ? _poiIconId(poi.categoryCode)
              : _poiFallbackIconId,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [poi.longitude, poi.latitude],
        },
      },
  ],
});

String _propertyFeatureCollection(List<PropertyMapItem> properties) =>
    jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        for (final property in properties)
          {
            'type': 'Feature',
            'properties': {'id': property.id},
            'geometry': {
              'type': 'Point',
              'coordinates': [property.longitude, property.latitude],
            },
          },
      ],
    });

String _routeFeatureCollection(RouteDetail? route) => jsonEncode({
  'type': 'FeatureCollection',
  'features': [
    if (route != null && route.geometry.length >= 2)
      {
        'type': 'Feature',
        'properties': {'id': route.id},
        'geometry': {'type': 'LineString', 'coordinates': route.geometry},
      },
  ],
});

List<Object> _poiColorExpression() {
  final expression = <Object>[
    'match',
    <Object>['get', 'category'],
  ];
  for (final code in poiCategoryColors.keys) {
    expression
      ..add(code)
      ..add(poiCategoryColorHex(code));
  }
  expression.add(poiCategoryColorHex('unknown'));
  return expression;
}

String get _mapStyle => jsonEncode({
  'version': 8,
  'name': 'Vivido Çankaya',
  // ⚠️ GLYPHS OLMADAN HİÇBİR METİN ÇİZİLMEZ.
  //
  // Küme dairelerinin içi boştu ve haritada kaç konut olduğu okunamıyordu.
  // Sebep eksik bir katman değil, stilde `glyphs` tanımının hiç
  // olmamasıydı: MapLibre `text-field` içeren her `symbol` katmanı için
  // font atlası ister, kaynak yoksa katmanı sessizce boş çizer.
  //
  // Karo sunucusu bu fontu zaten sunuyor (web de aynı kaynağı kullanıyor).
  'glyphs': '${AppConfig.tileBaseUrl}/fonts/{fontstack}/{range}.pbf',
  'sources': {
    'karolar': {
      'type': 'vector',
      'tiles': ['${AppConfig.tileBaseUrl}/data/v3/{z}/{x}/{y}.pbf'],
      'minzoom': 0,
      'maxzoom': 14,
      'attribution': '© OpenStreetMap katkıcıları · © OpenMapTiles',
    },
    // KÜMELEME EŞİKLERİ — bu sayılar POI/konutların ne kadar yakınlaşınca
    // tek tek görüneceğini belirliyor ve fazla yüksekti: kullanıcı
    // POI'leri görebilmek için sokak seviyesine kadar inmek zorunda
    // kalıyordu. `clusterMaxZoom` bu değerin ÜSTÜNDE kümelemeyi bırakır,
    // yani tekil noktalar ancak ondan sonra belirir.
    _poiSourceId: {
      'type': 'geojson',
      'data': {'type': 'FeatureCollection', 'features': <Object>[]},
      'cluster': true,
      'clusterMaxZoom': 13,
      'clusterRadius': 42,
    },
    _propertySourceId: {
      'type': 'geojson',
      'data': {'type': 'FeatureCollection', 'features': <Object>[]},
      'cluster': true,
      'clusterMaxZoom': 14,
      'clusterRadius': 45,
    },
    _routeSourceId: {
      'type': 'geojson',
      'data': {'type': 'FeatureCollection', 'features': <Object>[]},
    },
    // Çankaya sınırı. Boş başlıyor; varlık dosyası okununca
    // `_loadDistrictBoundary()` dolduruyor (stil senkron kurulmak zorunda,
    // varlık okuma ise asenkron).
    _districtSourceId: {
      'type': 'geojson',
      'data': {'type': 'FeatureCollection', 'features': <Object>[]},
    },
  },
  'layers': [
    {
      'id': 'arka-plan',
      'type': 'background',
      'paint': {'background-color': '#eef2f0'},
    },
    {
      'id': 'yesil-alan',
      'type': 'fill',
      'source': 'karolar',
      'source-layer': 'landcover',
      'paint': {'fill-color': '#d7e7d4', 'fill-opacity': 0.72},
    },
    {
      'id': 'park',
      'type': 'fill',
      'source': 'karolar',
      'source-layer': 'park',
      'paint': {'fill-color': '#c8e3c1', 'fill-opacity': 0.72},
    },
    {
      'id': 'su',
      'type': 'fill',
      'source': 'karolar',
      'source-layer': 'water',
      'paint': {'fill-color': '#b8d8e4'},
    },
    {
      'id': 'binalar',
      'type': 'fill',
      'source': 'karolar',
      'source-layer': 'building',
      'minzoom': 13,
      'paint': {
        'fill-color': '#d7d1c8',
        'fill-outline-color': '#c1b9ae',
        'fill-opacity': 0.78,
      },
    },
    {
      'id': 'yol-zemin',
      'type': 'line',
      'source': 'karolar',
      'source-layer': 'transportation',
      'paint': {
        'line-color': '#c8c8c8',
        'line-width': [
          'interpolate',
          ['linear'],
          ['zoom'],
          9,
          1.2,
          16,
          7,
        ],
      },
    },
    {
      'id': 'yollar',
      'type': 'line',
      'source': 'karolar',
      'source-layer': 'transportation',
      'paint': {
        'line-color': '#ffffff',
        'line-width': [
          'interpolate',
          ['linear'],
          ['zoom'],
          9,
          0.7,
          16,
          5,
        ],
      },
    },
    // ── Çankaya sınırı ──────────────────────────────────────────────────
    // Yolların ÜSTÜNDE (görünsün) ama rota ve pin'lerin ALTINDA (onları
    // örtmesin). Renk ve kalınlık `web/src/shared/map/CankayaMap.tsx`
    // `ilce-sinir` katmanıyla aynı; iki üründe sınır aynı görünsün.
    //
    // Hafif dolgu, ilçe DIŞINI değil içini vurguluyor: kullanıcı haritayı
    // kaydırdığında kapsama alanının nerede bittiğini görebilsin. Opaklık
    // düşük tutuldu, altındaki sokaklar okunur kalıyor.
    {
      'id': _districtFillLayerId,
      'type': 'fill',
      'source': _districtSourceId,
      'paint': {'fill-color': '#0b3d35', 'fill-opacity': 0.05},
    },
    {
      'id': _districtLineLayerId,
      'type': 'line',
      'source': _districtSourceId,
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {'line-color': '#0b3d35', 'line-width': 2.4},
    },
    {
      'id': _routeCasingLayerId,
      'type': 'line',
      'source': _routeSourceId,
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {'line-color': '#ffffff', 'line-width': 8, 'line-opacity': 0.95},
    },
    {
      'id': _routeLineLayerId,
      'type': 'line',
      'source': _routeSourceId,
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {'line-color': '#2563eb', 'line-width': 5, 'line-opacity': 0.95},
    },
    // ── Konut kümesi ────────────────────────────────────────────────────
    // Eski hâlde daireler ÇOK BÜYÜKTÜ (16–32 px yarıçap) ve içleri boştu:
    // uzaklaşınca ekran, altındaki haritayı tamamen örten dev turuncu
    // lekelerle doluyordu ve hiçbiri kaç ev olduğunu söylemiyordu.
    //
    // Artık çaplar küçüldü, kademeler konut sayısına göre daha erken
    // ayrışıyor ve içine sayı yazılıyor (bkz. `_propertyClusterCountLayerId`).
    // Renk paletten geliyor — `--accent` (#C0421D) ile aynı aile.
    {
      'id': _propertyClusterLayerId,
      'type': 'circle',
      'source': _propertySourceId,
      'filter': ['has', 'point_count'],
      'paint': {
        'circle-color': '#C0421D',
        'circle-opacity': 0.92,
        'circle-stroke-width': 2.5,
        'circle-stroke-color': '#ffffff',
        'circle-radius': [
          'step',
          ['get', 'point_count'],
          13,
          10,
          16,
          50,
          19,
          200,
          23,
        ],
      },
    },
    // Kümedeki konut sayısı. `point_count_abbreviated` büyük sayıları
    // kısaltıyor (1200 -> 1.2k), yoksa rozete sığmazdı.
    {
      'id': _propertyClusterCountLayerId,
      'type': 'symbol',
      'source': _propertySourceId,
      'filter': ['has', 'point_count'],
      'layout': {
        'text-field': ['get', 'point_count_abbreviated'],
        'text-font': ['Noto Sans Regular'],
        'text-size': 12,
        'text-allow-overlap': true,
      },
      'paint': {'text-color': '#ffffff'},
    },
    // ── Tekil konut ─────────────────────────────────────────────────────
    // Beyaz zeminli yuvarlak + üstünde ev ikonu. Daire ikonun okunmasını
    // sağlıyor: ikon doğrudan haritaya basılsaydı açık zeminde kaybolurdu.
    {
      'id': _propertyPointLayerId,
      'type': 'circle',
      'source': _propertySourceId,
      'filter': [
        '!',
        ['has', 'point_count'],
      ],
      'paint': {
        'circle-radius': 11,
        'circle-color': '#ffffff',
        'circle-stroke-color': '#C0421D',
        'circle-stroke-width': 2,
      },
    },
    {
      'id': _propertyIconLayerId,
      'type': 'symbol',
      'source': _propertySourceId,
      'filter': [
        '!',
        ['has', 'point_count'],
      ],
      // İKON BOYUTU HESABI: imajlar 3× çözünürlükte kaydediliyor
      // (24 × 3 = 72 px), `icon-size` ise o piksel boyutunu ölçekliyor.
      // Yani ekrandaki boy = 72 × icon-size. Daire yarıçapı 11 (çap 22 px),
      // ikonun içinde rahat durması için ~13 px hedefliyoruz: 13/72 ≈ 0.18.
      'layout': {
        'icon-image': _propertyIconImageId,
        'icon-size': 0.18,
        'icon-allow-overlap': true,
      },
    },
    // ⚠️ POI KÜME DAİRESİ (mor halka) BİLEREK YOK.
    //
    // Uzaklaşınca mor küme daireleri çiziliyordu; bunlar hem kalabalık
    // yapıyor hem de altlarındaki gerçek kategori renklerini örtüp kafa
    // karıştırıyordu (market kırmızı, park yeşil… hepsi morun altında
    // kayboluyordu). Web bunu `64cafd8` ile kaldırdı, mobil geride kalmıştı.
    // Artık uzaklaşınca HİÇBİR ŞEY çizilmiyor; zoom 14+ olunca POI'ler
    // doğrudan kendi kategori renkleriyle beliriyor (aşağıdaki katman).
    //
    // Kaynaktaki `cluster: true` DURUYOR: kümeleme, çizilmese de
    // `point_count` özelliğini üretiyor ve aşağıdaki filtre ona dayanıyor.
    //
    // Nokta, kategori rengiyle dolu bir daire; üstüne (daha da yakınlaşınca)
    // kategori ikonu biniyor. İkonu doğrudan haritaya basmak yerine renkli
    // daire üzerinde göstermek iki işi birden yapıyor: renk kategoriyi
    // uzaktan, ikon yakından anlatıyor.
    {
      'id': _poiPointLayerId,
      'type': 'circle',
      'source': _poiSourceId,
      'filter': [
        '!',
        ['has', 'point_count'],
      ],
      'minzoom': 13,
      'paint': {
        // Yakınlaştıkça büyüyor: küçük daireye ikon sığmıyor, o yüzden
        // ikon katmanı dairenin yeterince büyüdüğü zoom'da devreye giriyor.
        'circle-radius': [
          'interpolate',
          ['linear'],
          ['zoom'],
          13,
          5,
          14.5,
          10,
        ],
        'circle-color': _poiColorExpression(),
        'circle-stroke-color': '#ffffff',
        'circle-stroke-width': 1.5,
      },
    },
    {
      'id': _poiIconLayerId,
      'type': 'symbol',
      'source': _poiSourceId,
      'filter': [
        '!',
        ['has', 'point_count'],
      ],
      // Daireden GEÇ beliriyor: küçük dairenin üstünde ikon okunmaz,
      // sadece lekelenir. Daire 14.5'te 10 yarıçapa ulaşıyor, ikon da
      // orada başlıyor.
      'minzoom': 14.5,
      // Ekrandaki boy = 72 × icon-size (bkz. konut ikonundaki hesap).
      // POI dairesi zoom 15.5'te 10 yarıçapında (çap 20 px); ikon ~11 px
      // olsun: 11/72 ≈ 0.15.
      'layout': {
        'icon-image': ['get', 'iconId'],
        'icon-size': 0.15,
        'icon-allow-overlap': true,
      },
    },
  ],
});
