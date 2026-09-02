import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:maplibre/maplibre.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/models/models.dart';
import '../../../location/application/user_location_controller.dart';
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
const _highlightedPoiSourceId = 'vivido-highlighted-pois';
const _propertySourceId = 'vivido-properties';
const _poiPointLayerId = 'vivido-poi-points';
const _highlightedPoiLayerId = 'vivido-highlighted-poi-points';
// NOT: `_poiClusterLayerId` BİLEREK YOK — mor küme katmanı artık çizilmiyor
// (gerekçe stildeki açıklamada). Sabiti bırakmak, ileride birinin var
// olmayan bir katmanı sorgulamasına davetiye çıkarırdı.
const _propertyPointLayerId = 'vivido-property-points';
const _propertyClusterLayerId = 'vivido-property-clusters';
const _anchorCorridorSourceId = 'vivido-anchor-corridor';
const _anchorCorridorFillLayerId = 'vivido-anchor-corridor-fill';
const _anchorCorridorLineLayerId = 'vivido-anchor-corridor-line';
const _routeSourceId = 'vivido-active-route';
const _traveledRouteSourceId = 'vivido-traveled-route';
const _routeCasingLayerId = 'vivido-route-casing';
const _routeLineLayerId = 'vivido-route-line';
const _traveledRouteLayerId = 'vivido-traveled-route-line';
const _districtSourceId = 'vivido-district';
const _districtFillLayerId = 'vivido-district-fill';
const _districtLineLayerId = 'vivido-district-line';
const _propertyClusterCountLayerId = 'vivido-property-cluster-count';
const _propertyIconLayerId = 'vivido-property-icons';
const _poiIconLayerId = 'vivido-poi-icons';
const _propertyIconImageId = 'vivido-ev-ikon';

// ── Mahalle poligonları ────────────────────────────────────────────────
// Web `cankaya-mahalleler.geojson`'ı çiziyordu, mobil yalnızca ilçe
// sınırını. Kullanıcı haritada gezerken hangi mahallede olduğunu
// göremiyordu — oysa konut ilanında mahalle en çok bakılan alan.
const _neighborhoodSourceId = 'vivido-neighborhoods';
const _neighborhoodFillLayerId = 'vivido-neighborhood-fill';
const _neighborhoodLineLayerId = 'vivido-neighborhood-line';

// ── Favori konutlar ────────────────────────────────────────────────────
// AYRI bir kaynak, `properties`ten türetilmiyor: kullanıcı "Konutlar"
// katmanını kapatıp yalnızca favorilerini görmek isteyebilir (kalabalık
// bir haritada favorileri bulmanın en hızlı yolu bu). Türetilseydi konut
// katmanı kapandığında favoriler de kaybolurdu.
//
// KÜMELENMİYOR: konutlar binlerce olduğu için kümeleme şart, favoriler en
// fazla birkaç düzine ve kullanıcı onları TEK TEK görmek istiyor —
// "3" yazan bir balon, favorilerin nerede olduğu sorusunu cevaplamaz.
const _favoriteSourceId = 'vivido-favorites';
const _favoriteCircleLayerId = 'vivido-favorite-circles';
const _favoriteIconLayerId = 'vivido-favorite-icons';
const _favoriteIconImageId = 'vivido-yildiz-ikon';

// ── Etiketler ──────────────────────────────────────────────────────────
// ⚠️ MOBİLDE SOKAK VE YER ADLARI HİÇ ÇİZİLMİYORDU.
//
// Stilde `glyphs` tanımlıydı (küme sayıları çiziliyordu) ama
// `transportation_name` ve `place` kaynak katmanlarını okuyan hiçbir
// `symbol` katmanı yoktu. Sonuç: yollar var, isimleri yok; mahalleler
// var, adları yok. Harita "nerede olduğunu" söylemiyordu.
//
// Web bu iki katmanı `vectorLabelLayers()` içinde tanımlıyor
// (`CankayaMap.tsx`) — buradakiler onların birebir karşılığı.
const _roadLabelLayerId = 'vivido-yol-adlari';
const _placeLabelLayerId = 'vivido-yer-adlari';

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

/// Mahalle poligonları.
const _neighborhoodAssetPath = 'assets/geo/cankaya-mahalleler.geojson';

/// Poligonlar bir kez okunup KODLANMIŞ hâlleriyle burada tutuluyor.
///
/// Harita her kurulduğunda 124 + 252 KB'lık dosyaları yeniden okuyup
/// ayrıştırmak gereksiz; sekmeler arasında gidip gelirken bu widget
/// defalarca yeniden kuruluyor. `updateGeoJsonSource` zaten String
/// beklediği için `jsonEncode` sonucunu saklıyoruz — her seferinde yeniden
/// kodlamaya da gerek kalmıyor.
String? _cachedDistrictGeoJson;
String? _cachedNeighborhoodGeoJson;

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
    this.highlightedPois = const [],
    this.properties = const [],
    this.favorites = const [],
    this.anchorCorridor,
    this.onBoundsChanged,
    this.onPoiTap,
    this.onPropertyTap,
    this.route,
    this.userLocation,
    this.followUserLocation = false,
    this.userBearing,
    this.followTarget,
    this.followBearing,
    this.traveledUpToIndex,
    this.onCameraFollowInterrupted,
    this.rounded = false,
    this.cameraPadding = const EdgeInsets.only(bottom: 90),
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
  final List<PoiMapItem> highlightedPois;
  final List<PropertyMapItem> properties;

  /// Favorilenmiş konutlar — konut katmanının ÜSTÜNDE, altın yıldızla.
  ///
  /// Sıra önemli: favori olan ev aynı koordinatta hem [properties] hem
  /// burada bulunuyor. Favori katmanı sonra çizildiği için turuncu ev
  /// pinini örtüyor ve kullanıcı o evin favorilendiğini tek bakışta
  /// görüyor.
  final List<PropertyMapItem> favorites;

  final AnchorCorridor? anchorCorridor;
  final MapBoundsCallback? onBoundsChanged;
  final PoiTapCallback? onPoiTap;
  final PropertyTapCallback? onPropertyTap;
  final RouteDetail? route;

  /// Kullanıcının canlı konumu. null ise nokta çizilmez — konum istenmemiş
  /// ya da alınamamış demektir.
  final UserLocation? userLocation;
  final bool followUserLocation;
  final double? userBearing;
  final Geographic? followTarget;
  final double? followBearing;
  final int? traveledUpToIndex;
  final VoidCallback? onCameraFollowInterrupted;

  /// Harita bir kartın İÇİNDEYSE köşeleri yuvarlanır.
  ///
  /// ⚠️ Varsayılan `false`. Harita her kullanıldığı yerde `ClipRRect(22)`
  /// ile sarılıydı — tam ekran harita sekmesinde bu, ekranın dört köşesinde
  /// krem renkli üçgen boşluklar bırakıyordu. Yuvarlak köşe bir KART
  /// özelliği; tam ekran bir yüzeyin köşesi olmaz.
  final bool rounded;

  /// Kamera takibinde odak noktasının ekranın neresine düşeceği.
  ///
  /// ⚠️ Harita TAM EKRAN, kontroller onun ÜSTÜNDE yüzüyor — bu yüzden
  /// kullanıcının konumu ekranın tam ortasına oturursa alttaki panelin
  /// arkasında kalıyor. Kamerayı yukarı itmek, haritayı küçültmekten iyi:
  /// navigasyon ekranı eskiden haritayı `Padding(112, 126)` ile
  /// kutulayarak çözüyordu ve ekranın üçte biri boşa gidiyordu.
  final EdgeInsets cameraPadding;

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
        !identical(oldWidget.highlightedPois, widget.highlightedPois) ||
        !identical(oldWidget.properties, widget.properties) ||
        !identical(oldWidget.favorites, widget.favorites) ||
        !identical(oldWidget.anchorCorridor, widget.anchorCorridor) ||
        !identical(oldWidget.route, widget.route) ||
        oldWidget.traveledUpToIndex != widget.traveledUpToIndex) {
      unawaited(_updateMapSources());
    }
    if (!identical(oldWidget.route, widget.route) &&
        widget.route != null &&
        !widget.followUserLocation &&
        widget.followTarget == null) {
      unawaited(_fitRoute());
    }
    final oldLocation = oldWidget.userLocation;
    final location = widget.userLocation;
    if (widget.followUserLocation &&
        location != null &&
        (oldLocation?.latitude != location.latitude ||
            oldLocation?.longitude != location.longitude ||
            oldWidget.userBearing != widget.userBearing)) {
      _followUser();
    }
    if (widget.followTarget != null &&
        (oldWidget.followTarget != widget.followTarget ||
            oldWidget.followBearing != widget.followBearing)) {
      _followUser();
    }
  }

  void _followUser() {
    final controller = _mapController;
    final location = widget.userLocation;
    final target =
        widget.followTarget ??
        (location == null
            ? null
            : Geographic(lon: location.longitude, lat: location.latitude));
    if (controller == null || target == null) return;
    unawaited(
      controller.animateCamera(
        center: target,
        zoom: 16.5,
        bearing: widget.followBearing ?? widget.userBearing ?? 0,
        pitch: 45,
        padding: widget.cameraPadding,
        nativeDuration: const Duration(milliseconds: 900),
      ),
    );
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
          id: _highlightedPoiSourceId,
          data: _poiFeatureCollection(widget.highlightedPois),
        ),
        style.updateGeoJsonSource(
          id: _propertySourceId,
          data: _propertyFeatureCollection(widget.properties),
        ),
        style.updateGeoJsonSource(
          id: _favoriteSourceId,
          data: _propertyFeatureCollection(widget.favorites),
        ),
        style.updateGeoJsonSource(
          id: _anchorCorridorSourceId,
          data: _anchorCorridorFeatureCollection(widget.anchorCorridor),
        ),
        style.updateGeoJsonSource(
          id: _routeSourceId,
          data: _routeFeatureCollection(widget.route),
        ),
        style.updateGeoJsonSource(
          id: _traveledRouteSourceId,
          data: _traveledRouteFeatureCollection(
            widget.route,
            widget.traveledUpToIndex,
          ),
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

    // Konut ikonu BEYAZ: altında turuncu dolu bir daire var (web ile aynı
    // desen). Eskiden `home_kahve.svg` accent rengine boyanıp BEYAZ bir
    // dairenin üstüne konuyordu — POI'ler renkli daire + beyaz ikon,
    // konutlar beyaz daire + renkli ikon; iki farklı dil.
    await register(
      _propertyIconImageId,
      'assets/icons/home_white.svg',
      Colors.white,
    );

    // Favori yıldızı — altın dairenin üstünde beyaz.
    await register(
      _favoriteIconImageId,
      'assets/icons/star_white.svg',
      Colors.white,
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
        final features =
            (parsed['features'] as List<Object?>? ?? const [])
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

  /// Mahalle poligonlarını varlıklardan okuyup haritaya yazar.
  ///
  /// İlçe sınırıyla aynı desen; ayrı bir metot çünkü ayrı bir kaynak ve
  /// biri yüklenemezken diğeri çizilebilmeli.
  Future<void> _loadNeighbourhoods() async {
    final style = _styleController;
    if (style == null) return;

    try {
      var geojson = _cachedNeighborhoodGeoJson;
      if (geojson == null) {
        final raw = await rootBundle.loadString(_neighborhoodAssetPath);
        // İlçe dosyasının aksine burada ayıklama gerekmiyor: mahalle
        // dosyasında yalnızca poligon var. Yine de aynı filtreyi
        // uyguluyoruz — dosya bir gün etiket noktası kazanırsa `fill`
        // katmanı sessizce bozulmasın.
        final parsed = jsonDecode(raw) as Map<String, Object?>;
        final features =
            (parsed['features'] as List<Object?>? ?? const [])
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
        _cachedNeighborhoodGeoJson = geojson;
      }

      await style.updateGeoJsonSource(id: _neighborhoodSourceId, data: geojson);
    } on Object {
      // Mahalle katmanı eksik kalırsa harita yine okunur; ilçe sınırı ve
      // sokak adları yerinde.
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

    // Favori katmanı konut katmanının ÜSTÜNDE çiziliyor, o yüzden önce
    // sorgulanıyor. İkisi de sorgulanmak zorunda: kullanıcı "Konutlar"
    // katmanını kapatıp yalnızca favorilerini bıraktığında konut katmanı
    // boş oluyor ve tek başına sorgulamak dokunuşu kaçırırdı.
    final propertyHits = controller.featuresAtPoint(
      event.screenPoint,
      layerIds: const [_favoriteCircleLayerId, _propertyPointLayerId],
    );
    final propertyId = propertyHits.firstOrNull?.properties['id']?.toString();
    if (propertyId != null) {
      for (final property in [...widget.favorites, ...widget.properties]) {
        if (property.id == propertyId) {
          widget.onPropertyTap?.call(property);
          return;
        }
      }
    }

    final highlightedPoiHits = controller.featuresAtPoint(
      event.screenPoint,
      layerIds: const [_highlightedPoiLayerId],
    );
    final highlightedPoiId =
        highlightedPoiHits.firstOrNull?.properties['id']?.toString();
    if (highlightedPoiId != null) {
      for (final poi in widget.highlightedPois) {
        if (poi.id == highlightedPoiId) {
          widget.onPoiTap?.call(poi);
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
      // Canlı konum — listenin BAŞINDA, yani en altta çiziliyor: anchor
      // pin'leri ve rota durakları onun üstünde kalsın, kullanıcı kendi
      // noktası yüzünden bir durağı kaçırmasın.
      if (widget.userLocation != null)
        Marker(
          point: Geographic(
            lon: widget.userLocation!.longitude,
            lat: widget.userLocation!.latitude,
          ),
          size: const Size(26, 26),
          child: _UserLocationMarker(
            bearing: widget.followBearing ?? widget.userBearing,
          ),
        ),
      for (final anchor in widget.anchors)
        Marker(
          point: Geographic(lon: anchor.lon, lat: anchor.lat),
          size: const Size.square(_pinSize),
          alignment: Alignment.center,
          child: MapPin(
            label: '${anchor.priority}',
            color: AppColors.accent,
            tooltip: anchor.label,
          ),
        ),
      if (widget.pendingPoint != null)
        Marker(
          point: widget.pendingPoint!,
          size: const Size.square(_pinSize),
          alignment: Alignment.center,
          child: const MapPin(
            icon: Icons.add,
            color: AppColors.accentSecondary,
            pulsing: true,
            tooltip: 'Yeni konum',
          ),
        ),
      if (widget.focus != null)
        Marker(
          point: Geographic(
            lon: widget.focus!.longitude,
            lat: widget.focus!.latitude,
          ),
          size: const Size.square(_pinSize + 16),
          alignment: Alignment.center,
          // Arama sonucu bir HEDEF, bir içerik değil: halka biçiminde ve
          // nabız atıyor. Dolu bir pin olsaydı konut pinleriyle karışır,
          // kullanıcı aradığı yeri bir ev sanırdı.
          child: const _FocusTarget(),
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
              color: AppColors.mapWalking,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.mapWalkingCore, width: 2),
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
          size: const Size.square(_pinSize),
          alignment: Alignment.center,
          child: const MapPin(
            icon: Icons.flag_rounded,
            color: AppColors.mapRouteCasing,
            tooltip: 'Rota başlangıcı',
          ),
        ),
      if (widget.route != null)
        for (final stop in widget.route!.stops)
          Marker(
            point: Geographic(
              lon: stop.property.longitude,
              lat: stop.property.latitude,
            ),
            size: const Size.square(_pinSize),
            alignment: Alignment.center,
            child: MapPin(
              label: '${stop.sequence}',
              color: AppColors.mapRoute,
              tooltip: '${stop.sequence}. durak',
            ),
          ),
    ];

    final map = ColoredBox(
      color: AppColors.mapLoading,
      child: MapLibreMap(
          onMapCreated: (controller) {
            _mapController = controller;
            _focusOnResult();
            if (widget.followUserLocation || widget.followTarget != null) {
              _followUser();
            }
          },
          onStyleLoaded: (style) {
            _styleController = style;
            unawaited(_loadMapIcons());
            unawaited(_loadDistrictBoundary());
            unawaited(_loadNeighbourhoods());
            unawaited(_updateMapSources());
            if (widget.route != null &&
                !widget.followUserLocation &&
                widget.followTarget == null) {
              unawaited(_fitRoute());
            } else if (widget.followUserLocation ||
                widget.followTarget != null) {
              _followUser();
            }
            _reportBounds();
          },
          options: MapOptions(
            initStyle: vividoMapStyle,
            initCenter: Geographic(lon: 32.85, lat: 39.87),
            initZoom: 10.7,
            minZoom: 8,
            maxZoom: 18,
            androidForegroundLoadColor: AppColors.mapLoading,
          ),
          onEvent: (event) {
            if (event is MapEventClick) {
              _handleMapClick(event);
            } else if (event is MapEventStartMoveCamera &&
                event.reason == CameraChangeReason.apiGesture) {
              widget.onCameraFollowInterrupted?.call();
            } else if (event is MapEventCameraIdle) {
              _reportBounds();
            }
          },
          layers: [
            PolygonLayer(
              polygons: analysisPolygons,
              color: AppColors.mapAnalysis.withValues(alpha: 0.10),
              outlineColor: AppColors.mapAnalysis,
            ),
            PolygonLayer(
              polygons: walkingPolygons,
              color: AppColors.mapWalking.withValues(alpha: 0.22),
              outlineColor: AppColors.mapWalkingEdge,
            ),
          ],
        children: [WidgetLayer(markers: markers), const SourceAttribution()],
      ),
    );

    // Yuvarlak köşe bir KART özelliği. Tam ekran harita sekmesinde bu,
    // ekranın dört köşesinde krem renkli üçgen boşluklar bırakıyordu —
    // harita "ekranın içinde yüzen bir kutu" gibi duruyor, ekranın kendisi
    // olmuyordu.
    if (!widget.rounded) return map;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: map,
    );
  }
}

/// Harita pinlerinin ortak boyu. Dokunma hedefi olarak da bu geçerli.
const double _pinSize = 32;

/// Harita üstündeki nokta işareti — `web/src/index.css` `.map-pin`.
///
/// ⚠️ TEK BİR PİN DİLİ
///
/// Eskiden dört ayrı işaret vardı ve hiçbiri diğerine benzemiyordu:
/// anchor 46 px'lik `Icons.location_on` damlası + üstüne yazılmış numara,
/// rota durağı aynı damlanın mavisi, rota başlangıcı 42 px'lik dolu mavi
/// daire, bekleyen nokta 46 px'lik kırmızı `add_location_alt`. Üç farklı
/// boyut, iki farklı biçim, dört farklı renk.
///
/// Hepsi tek bir biçime indi: beyaz çerçeveli dolu daire + içinde ya bir
/// numara ya bir simge. Rengi ANLAMI taşıyor — accent: kullanıcının kendi
/// yeri, mavi: rota, açık turuncu: henüz kaydedilmemiş.
class MapPin extends StatelessWidget {
  const MapPin({
    required this.color,
    this.label,
    this.icon,
    this.tooltip,
    this.pulsing = false,
    super.key,
  }) : assert(
         label != null || icon != null,
         'Pin ya bir numara ya bir simge taşımalı',
       );

  final Color color;
  final String? label;
  final IconData? icon;
  final String? tooltip;

  /// Henüz onaylanmamış bir nokta (kullanıcı formu doldurmayı bekliyor)
  /// nabız atarak "burada bir iş yarım kaldı" diyor.
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    Widget pin = Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child:
          label != null
              ? Text(
                label!,
                style: const TextStyle(
                  fontFamily: AppType.fontFamily,
                  color: Colors.white,
                  fontSize: 12,
                  height: 1,
                  fontWeight: AppType.bold,
                  fontFeatures: AppType.tabularFigures,
                ),
              )
              : Icon(icon, size: 14, color: Colors.white),
    );

    if (pulsing) pin = _Pulse(color: color, child: pin);
    if (tooltip != null) pin = Tooltip(message: tooltip!, child: pin);
    return Center(child: pin);
  }
}

/// Pinin arkasında genişleyip sönen halka.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Yavaş, sürekli yanıp sönen büyük yüzeylerden kaçınılmalı; bu halka
    // 26 px ve "hareketi azalt" açıkken hiç çalışmıyor.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: (1 - t) * 0.5,
              child: Container(
                width: 26 + 22 * t,
                height: 26 + 22 * t,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// Arama sonucunu işaretleyen halka.
///
/// İçi BOŞ: altındaki şeyi (bir bina, bir kavşak) örtmemesi gerekiyor —
/// kullanıcı oraya tam olarak neyin olduğunu görmek için gitti.
class _FocusTarget extends StatelessWidget {
  const _FocusTarget();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 3),
        color: AppColors.accent.withValues(alpha: 0.14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
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

/// "Buradayım" noktası — haritalardaki alışılmış mavi daire.
///
/// Vurgu rengi (terracotta) BİLEREK kullanılmadı: o renk konut ve rota
/// öğelerinin rengi. Kullanıcının kendi konumu bir içerik değil, bir
/// referans noktası; ayrı bir renkte olması onu içerikten ayırıyor.
class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker({this.bearing});

  final double? bearing;

  @override
  Widget build(BuildContext context) {
    if (bearing != null) {
      return Transform.rotate(
        angle: bearing! * math.pi / 180,
        child: const Icon(
          Icons.navigation,
          color: AppColors.live,
          size: 26,
          shadows: [Shadow(color: Colors.white, blurRadius: 4)],
        ),
      );
    }
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.live,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
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
          'iconId':
              poiCategoryIconAssets.containsKey(poi.categoryCode)
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

String _traveledRouteFeatureCollection(RouteDetail? route, int? endIndex) {
  final geometry = route?.geometry ?? const <List<double>>[];
  final safeEnd =
      endIndex == null || geometry.isEmpty
          ? -1
          : endIndex.clamp(0, geometry.length - 1);
  final traveled =
      safeEnd < 1
          ? const <List<double>>[]
          : geometry.take(safeEnd + 1).toList(growable: false);
  return jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      if (route != null && traveled.length >= 2)
        {
          'type': 'Feature',
          'properties': {'id': '${route.id}-traveled'},
          'geometry': {'type': 'LineString', 'coordinates': traveled},
        },
    ],
  });
}

String _anchorCorridorFeatureCollection(AnchorCorridor? corridor) =>
    jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        if (corridor != null)
          {
            'type': 'Feature',
            'properties': {'kind': 'anchor-corridor'},
            'geometry': corridor.toGeoJson(),
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

/// Çankaya harita stili (MapLibre Style Spec v8).
///
/// PUBLIC çünkü test edilmesi gerekiyor: bu stil bir zamanlar sokak
/// adlarını, yer adlarını, mahalle poligonlarını ve favori katmanını
/// hiç içermiyordu ve kimse fark etmedi — eksik bir katman çalışma
/// zamanında hata vermiyor, sadece "çizilmiyor". Kapalı bir sabit,
/// bunu yakalayan bir test yazmayı imkânsız kılıyordu.
String get vividoMapStyle => jsonEncode({
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
    _highlightedPoiSourceId: {
      'type': 'geojson',
      'data': {'type': 'FeatureCollection', 'features': <Object>[]},
    },
    _propertySourceId: {
      'type': 'geojson',
      'data': {'type': 'FeatureCollection', 'features': <Object>[]},
      'cluster': true,
      'clusterMaxZoom': 14,
      'clusterRadius': 45,
    },
    // Favoriler KÜMELENMİYOR — gerekçe sabitin yanındaki notta.
    _favoriteSourceId: {
      'type': 'geojson',
      'data': {'type': 'FeatureCollection', 'features': <Object>[]},
    },
    _anchorCorridorSourceId: {
      'type': 'geojson',
      'data': {'type': 'FeatureCollection', 'features': <Object>[]},
    },
    // Mahalle poligonları. İlçe sınırı gibi boş başlıyor;
    // `_loadNeighbourhoods()` dolduruyor.
    _neighborhoodSourceId: {
      'type': 'geojson',
      'data': {'type': 'FeatureCollection', 'features': <Object>[]},
    },
    _routeSourceId: {
      'type': 'geojson',
      'data': {'type': 'FeatureCollection', 'features': <Object>[]},
    },
    _traveledRouteSourceId: {
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
        // Binalar BELİREREK geliyor (web ile aynı). Sabit 0.78 opaklıkta
        // z13'te aniden ortaya çıkan bir bina katmanı, yakınlaştırmayı
        // "kırılmış" gösteriyordu.
        'fill-opacity': [
          'interpolate',
          ['linear'],
          ['zoom'],
          13,
          0.25,
          16,
          0.85,
        ],
      },
    },
    // ── Yol hiyerarşisi ────────────────────────────────────────────────
    // ⚠️ Eskiden TEK bir gri zemin + TEK bir beyaz çizgi vardı: otoyol da
    // ara sokak da aynı görünüyordu ve harita "nereden geçilir" sorusuna
    // cevap vermiyordu. Web ana arterleri kehribar renkte ayırıyor
    // (`yollar-ana`); ikisi de aynı desene geçti.
    {
      'id': 'yol-zemin',
      'type': 'line',
      'source': 'karolar',
      'source-layer': 'transportation',
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {
        'line-color': '#d6d2cb',
        'line-width': [
          'interpolate',
          ['linear'],
          ['zoom'],
          9,
          1.4,
          16,
          7.5,
        ],
      },
    },
    {
      'id': 'yollar-kucuk',
      'type': 'line',
      'source': 'karolar',
      'source-layer': 'transportation',
      'filter': [
        '!',
        [
          'in',
          ['get', 'class'],
          [
            'literal',
            ['motorway', 'trunk', 'primary'],
          ],
        ],
      ],
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {
        'line-color': '#ffffff',
        'line-width': [
          'interpolate',
          ['linear'],
          ['zoom'],
          11,
          0.4,
          16,
          3,
        ],
      },
    },
    {
      'id': 'yollar-ana',
      'type': 'line',
      'source': 'karolar',
      'source-layer': 'transportation',
      'filter': [
        'in',
        ['get', 'class'],
        [
          'literal',
          ['motorway', 'trunk', 'primary'],
        ],
      ],
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {
        'line-color': '#f7c873',
        'line-width': [
          'interpolate',
          ['linear'],
          ['zoom'],
          9,
          0.8,
          16,
          6,
        ],
      },
    },
    // ── Mahalleler ──────────────────────────────────────────────────────
    // İlçe sınırının ALTINDA (o daha kalın ve daha önemli), yolların
    // ÜSTÜNDE. Opaklık düşük: altındaki sokaklar okunur kalmalı — mahalle
    // bir zemin bilgisi, içeriğin önüne geçmemeli.
    {
      'id': _neighborhoodFillLayerId,
      'type': 'fill',
      'source': _neighborhoodSourceId,
      'paint': {
        'fill-color': '#7fb3a8',
        'fill-opacity': 0.16,
      },
    },
    {
      'id': _neighborhoodLineLayerId,
      'type': 'line',
      'source': _neighborhoodSourceId,
      'paint': {
        'line-color': '#4a8578',
        'line-width': 0.8,
        'line-opacity': 0.9,
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
      'id': _anchorCorridorFillLayerId,
      'type': 'fill',
      'source': _anchorCorridorSourceId,
      'paint': {'fill-color': '#0f766e', 'fill-opacity': 0.13},
    },
    {
      'id': _anchorCorridorLineLayerId,
      'type': 'line',
      'source': _anchorCorridorSourceId,
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {
        'line-color': '#0f766e',
        'line-width': 2,
        'line-opacity': 0.85,
        'line-dasharray': [2, 2],
      },
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
    {
      'id': _traveledRouteLayerId,
      'type': 'line',
      'source': _traveledRouteSourceId,
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {'line-color': '#94A3B8', 'line-width': 5, 'line-opacity': 0.9},
    },
    // ── SOKAK VE YER ADLARI ─────────────────────────────────────────────
    // ⚠️ BU İKİ KATMAN MOBİLDE HİÇ YOKTU. Stilde `glyphs` tanımlıydı
    // (küme sayıları çiziliyordu) ama etiket katmanı yazılmamıştı: yollar
    // vardı, adları yoktu.
    //
    // Web'deki `vectorLabelLayers()` ile birebir aynı ayarlar.
    //
    // ⚠️ PİNLERİN ALTINDA — webden bilinçli sapma. Web etiketleri en üste
    // koyuyor; geniş bir ekranda sorun değil. Telefonda konut pini 22 px
    // ve etiket onun üstüne binince pin okunmuyor. Etiketin halesi (halo)
    // pinin altında kalsa da okunmasını sağlıyor.
    {
      'id': _roadLabelLayerId,
      'type': 'symbol',
      'source': 'karolar',
      'source-layer': 'transportation_name',
      // z14'ten önce sokak adları birbirine giriyor ve harita okunmaz
      // hâle geliyor; MapLibre çakışanları eliyor ama kalanlar da
      // rastgele görünüyor.
      'minzoom': 14,
      'layout': {
        'text-field': ['get', 'name'],
        'text-font': ['Noto Sans Regular'],
        'text-size': 11,
        // Yol boyunca kıvrılarak yazılıyor — yatay bir etiket, hangi
        // yola ait olduğunu söylemez.
        'symbol-placement': 'line',
      },
      'paint': {
        'text-color': '#4a4a4a',
        // Hale ŞART: beyaz yolun üstündeki gri metin, altındaki çizgiyle
        // aynı tonda kalıyor ve okunmuyor.
        'text-halo-color': '#ffffff',
        'text-halo-width': 1.2,
      },
    },
    {
      'id': _placeLabelLayerId,
      'type': 'symbol',
      'source': 'karolar',
      'source-layer': 'place',
      'layout': {
        'text-field': ['get', 'name'],
        'text-font': ['Noto Sans Regular'],
        // Yakınlaştıkça büyüyor: uzaktan semt adı bir yön işareti,
        // yakından bir yer adı.
        'text-size': [
          'interpolate',
          ['linear'],
          ['zoom'],
          10,
          11,
          15,
          15,
        ],
      },
      'paint': {
        'text-color': '#2b3a36',
        'text-halo-color': '#ffffff',
        'text-halo-width': 1.4,
      },
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
        'circle-color': '#EA580C',
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
    // TURUNCU dolu daire + üstünde BEYAZ ev ikonu — POI'lerle aynı desen
    // (renkli daire + beyaz simge) ve web ile aynı.
    //
    // ⚠️ Eskiden tersti: beyaz daire + turuncu ikon. Haritada iki farklı
    // işaret dili vardı — POI'ler dolu renkli, konutlar içi boş. Konut
    // pini POI'den daha az "var" görünüyordu, oysa ürünün ana nesnesi o.
    {
      'id': _propertyPointLayerId,
      'type': 'circle',
      'source': _propertySourceId,
      'filter': [
        '!',
        ['has', 'point_count'],
      ],
      'paint': {
        'circle-radius': 12,
        'circle-color': '#EA580C',
        'circle-stroke-color': '#ffffff',
        'circle-stroke-width': 1.5,
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
      // Yani ekrandaki boy = 72 × icon-size. Daire yarıçapı 12 (çap 24 px),
      // ikonun içinde rahat durması için ~13 px hedefliyoruz: 13/72 ≈ 0.18.
      'layout': {
        'icon-image': _propertyIconImageId,
        'icon-size': 0.18,
        'icon-allow-overlap': true,
      },
    },
    // ── ⭐ FAVORİLER ────────────────────────────────────────────────────
    // Konut katmanının hemen ÜSTÜNDE. Sıra önemli: favori olan ev aynı
    // koordinatta iki kaynakta birden bulunuyor; favori katmanı sonra
    // çizildiği için turuncu ev pinini örtüyor ve kullanıcı o evin
    // favorilendiğini tek bakışta görüyor.
    //
    // ⚠️ FAVORİ HARİTADA YILDIZ, DÜĞMEDE KALP.
    // Favoriye ekleme düğmesi kalp (alışılmış işaret). Haritada kalp,
    // kırmızı-turuncu konut pinleriyle aynı renk ailesine düşüp
    // ayrışmıyor; altın bir yıldız uzaktan bile okunuyor. Renk `#d97706`:
    // haritadaki hiçbir dolu daireyle çakışmıyor (konut `#ea580c`, okul
    // POI `#f59e0b`, yemek `#f97316`). Yarıçap da konutunkinden (12) büyük
    // (15) — üst üste bindiklerinde favori bir halka gibi taşıyor.
    {
      'id': _favoriteCircleLayerId,
      'type': 'circle',
      'source': _favoriteSourceId,
      'paint': {
        'circle-radius': 15,
        'circle-color': '#D97706',
        'circle-stroke-color': '#ffffff',
        'circle-stroke-width': 2,
      },
    },
    {
      'id': _favoriteIconLayerId,
      'type': 'symbol',
      'source': _favoriteSourceId,
      // Çap 30 px, ikon ~16 px: 16/72 ≈ 0.22.
      'layout': {
        'icon-image': _favoriteIconImageId,
        'icon-size': 0.22,
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
      // POI dairesi 14.5'te 10 yarıçapında (çap 20 px); ikon ~11 px
      // olsun: 11/72 ≈ 0.15.
      'layout': {
        'icon-image': ['get', 'iconId'],
        'icon-size': 0.15,
        'icon-allow-overlap': true,
      },
    },
    // Seçili konutun "güçlü yön" POI'leri — ayrı kaynak, ayrı katman.
    // En SONDA duruyor ki normal POI noktalarının üstünde kalsın:
    // vurgulanan POI, vurgulanmayanın altında kaybolmamalı.
    {
      'id': _highlightedPoiLayerId,
      'type': 'circle',
      'source': _highlightedPoiSourceId,
      'paint': {
        'circle-radius': 7,
        'circle-color': _poiColorExpression(),
        'circle-stroke-color': '#ffffff',
        'circle-stroke-width': 2,
      },
    },
  ],
});
