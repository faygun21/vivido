class MapViewportBounds {
  const MapViewportBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;

  bool get isValid =>
      west >= -180 &&
      east <= 180 &&
      south >= -90 &&
      north <= 90 &&
      west < east &&
      south < north;

  String get cacheKey =>
      '${west.toStringAsFixed(4)},${south.toStringAsFixed(4)},'
      '${east.toStringAsFixed(4)},${north.toStringAsFixed(4)}';
}

class PoiCategory {
  const PoiCategory({required this.code, required this.displayNameTr});

  final String code;
  final String displayNameTr;

  factory PoiCategory.fromJson(Map<String, dynamic> json) => PoiCategory(
    code: json['code'] as String,
    displayNameTr: json['displayNameTr'] as String,
  );
}

class PoiMapItem {
  const PoiMapItem({
    required this.id,
    required this.categoryCode,
    required this.latitude,
    required this.longitude,
    this.name,
  });

  final String id;
  final String? name;
  final String categoryCode;
  final double latitude;
  final double longitude;

  factory PoiMapItem.fromJson(Map<String, dynamic> json) => PoiMapItem(
    id: json['id'].toString(),
    name: json['name'] as String?,
    categoryCode: json['categoryCode'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}

/// Hem giriş yapan kullanıcının skorlanmış `/properties` yanıtını hem de
/// misafirin bbox tabanlı `/properties/map` yanıtını temsil eder.
class PropertyMapItem {
  const PropertyMapItem({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.monthlyRent,
    required this.areaM2,
    required this.roomCount,
    this.externalRef,
    this.totalScore,
    this.buildingAge,
    this.hasElevator,
    this.isSynthetic = false,
  });

  final String id;
  final String? externalRef;
  final double latitude;
  final double longitude;
  final double monthlyRent;
  final int areaM2;
  final String roomCount;
  final double? totalScore;
  final int? buildingAge;
  final bool? hasElevator;
  final bool isSynthetic;

  factory PropertyMapItem.fromJson(Map<String, dynamic> json) =>
      PropertyMapItem(
        id: json['id'].toString(),
        externalRef: json['externalRef'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        monthlyRent: (json['monthlyRent'] as num).toDouble(),
        areaM2: (json['areaM2'] as num).toInt(),
        roomCount: json['roomCount'] as String,
        totalScore: (json['totalScore'] as num?)?.toDouble(),
        buildingAge: (json['buildingAge'] as num?)?.toInt(),
        hasElevator: json['hasElevator'] as bool?,
        isSynthetic: json['isSynthetic'] as bool? ?? false,
      );
}

/// Backend'in anchor'lar arasındaki gerçek OSRM rotalarını genişleterek
/// ürettiği GeoJSON MultiPolygon koridoru.
class AnchorCorridor {
  const AnchorCorridor({required this.coordinates});

  /// GeoJSON sırası korunur: polygon -> ring -> point -> [longitude, latitude].
  final List<List<List<List<double>>>> coordinates;

  factory AnchorCorridor.fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'MultiPolygon') {
      throw const FormatException('Anchor koridoru MultiPolygon olmalıdır.');
    }
    final polygons = json['coordinates'] as List<dynamic>?;
    if (polygons == null) {
      throw const FormatException('Anchor koridoru koordinatları eksik.');
    }
    return AnchorCorridor(
      coordinates: [
        for (final polygon in polygons)
          [
            for (final ring in polygon as List<dynamic>)
              [
                for (final point in ring as List<dynamic>)
                  [
                    ((point as List<dynamic>)[0] as num).toDouble(),
                    (point[1] as num).toDouble(),
                  ],
              ],
          ],
      ],
    );
  }

  Map<String, Object> toGeoJson() => {
    'type': 'MultiPolygon',
    'coordinates': coordinates,
  };
}

class AuthenticatedPropertiesMap {
  const AuthenticatedPropertiesMap({
    required this.items,
    this.corridor,
  });

  final List<PropertyMapItem> items;
  final AnchorCorridor? corridor;

  factory AuthenticatedPropertiesMap.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>?;
    if (rawItems == null) {
      throw const FormatException('Konut harita listesi eksik.');
    }
    final rawCorridor = json['corridorPolygon'];
    return AuthenticatedPropertiesMap(
      items: rawItems
          .map((item) => PropertyMapItem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      corridor: rawCorridor is Map<String, dynamic>
          ? AnchorCorridor.fromJson(rawCorridor)
          : null,
    );
  }
}
