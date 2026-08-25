import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/models/models.dart';
import '../../../location_analysis/domain/location_analysis.dart';
import '../../../location_search/domain/location_search_models.dart';
import '../../../map_data/domain/map_data_models.dart';
import '../../../map_data/presentation/poi_category_colors.dart';

typedef MapPointCallback = void Function(double lat, double lon);
typedef MapBoundsCallback = void Function(MapViewportBounds bounds);
typedef PoiTapCallback = void Function(PoiMapItem poi);
typedef PropertyTapCallback = void Function(PropertyMapItem property);

const _poiSourceId = 'vivido-pois';
const _propertySourceId = 'vivido-properties';
const _poiPointLayerId = 'vivido-poi-points';
const _poiClusterLayerId = 'vivido-poi-clusters';
const _propertyPointLayerId = 'vivido-property-points';
const _propertyClusterLayerId = 'vivido-property-clusters';

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
        !identical(oldWidget.properties, widget.properties)) {
      unawaited(_updateMapSources());
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
      ]);
    } on Object {
      // Stil yeniden yüklenirken eski controller kısa süreliğine geçersiz
      // olabilir. Yeni onStyleLoaded çağrısı güncel veriyi tekrar yazar.
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

    final clusterHits = controller.featuresAtPoint(
      event.screenPoint,
      layerIds: const [_propertyClusterLayerId, _poiClusterLayerId],
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
            unawaited(_updateMapSources());
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
  'sources': {
    'karolar': {
      'type': 'vector',
      'tiles': ['${AppConfig.tileBaseUrl}/data/v3/{z}/{x}/{y}.pbf'],
      'minzoom': 0,
      'maxzoom': 14,
      'attribution': '© OpenStreetMap katkıcıları · © OpenMapTiles',
    },
    _poiSourceId: {
      'type': 'geojson',
      'data': {'type': 'FeatureCollection', 'features': <Object>[]},
      'cluster': true,
      'clusterMaxZoom': 14,
      'clusterRadius': 42,
    },
    _propertySourceId: {
      'type': 'geojson',
      'data': {'type': 'FeatureCollection', 'features': <Object>[]},
      'cluster': true,
      'clusterMaxZoom': 15,
      'clusterRadius': 45,
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
    {
      'id': _propertyClusterLayerId,
      'type': 'circle',
      'source': _propertySourceId,
      'filter': ['has', 'point_count'],
      'paint': {
        'circle-color': '#ea580c',
        'circle-opacity': 0.85,
        'circle-stroke-width': 2,
        'circle-stroke-color': '#ffffff',
        'circle-radius': [
          'step',
          ['get', 'point_count'],
          16,
          25,
          20,
          100,
          26,
          500,
          32,
        ],
      },
    },
    {
      'id': _propertyPointLayerId,
      'type': 'circle',
      'source': _propertySourceId,
      'filter': [
        '!',
        ['has', 'point_count'],
      ],
      'paint': {
        'circle-radius': 8,
        'circle-color': '#c2410c',
        'circle-stroke-color': '#ffffff',
        'circle-stroke-width': 2,
      },
    },
    {
      'id': _poiClusterLayerId,
      'type': 'circle',
      'source': _poiSourceId,
      'filter': ['has', 'point_count'],
      'maxzoom': 14,
      'paint': {
        'circle-color': '#7c3aed',
        'circle-opacity': 0.76,
        'circle-stroke-width': 2,
        'circle-stroke-color': '#ffffff',
        'circle-radius': [
          'step',
          ['get', 'point_count'],
          16,
          10,
          20,
          50,
          26,
        ],
      },
    },
    {
      'id': _poiPointLayerId,
      'type': 'circle',
      'source': _poiSourceId,
      'filter': [
        '!',
        ['has', 'point_count'],
      ],
      'minzoom': 14,
      'paint': {
        'circle-radius': 6,
        'circle-color': _poiColorExpression(),
        'circle-stroke-color': '#ffffff',
        'circle-stroke-width': 1.5,
      },
    },
  ],
});
