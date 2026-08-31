import '../../map_data/domain/map_data_models.dart';
import '../../properties/domain/property_models.dart';

const minRouteStops = 2;
const maxRouteStops = 8;

enum RouteTravelMode {
  car,
  foot;

  String get apiValue => name;

  String get label => this == RouteTravelMode.car ? 'Araç' : 'Yürüyerek';

  static RouteTravelMode fromJson(Object? value) =>
      value == 'foot' ? RouteTravelMode.foot : RouteTravelMode.car;
}

class RouteDraftProperty {
  const RouteDraftProperty({
    required this.id,
    required this.monthlyRent,
    required this.areaM2,
    required this.roomCount,
    required this.latitude,
    required this.longitude,
    required this.totalScore,
    this.neighborhood,
  });

  final int id;
  final double monthlyRent;
  final int areaM2;
  final String roomCount;
  final double latitude;
  final double longitude;
  final double totalScore;
  final String? neighborhood;

  factory RouteDraftProperty.fromMapItem(PropertyMapItem item) =>
      RouteDraftProperty(
        id: int.parse(item.id),
        monthlyRent: item.monthlyRent,
        areaM2: item.areaM2,
        roomCount: item.roomCount,
        latitude: item.latitude,
        longitude: item.longitude,
        totalScore: item.totalScore ?? 0,
      );

  factory RouteDraftProperty.fromSummary(PropertySummary item) =>
      RouteDraftProperty(
        id: int.parse(item.id),
        monthlyRent: item.monthlyRent,
        areaM2: item.areaM2,
        roomCount: item.roomCount,
        latitude: item.latitude,
        longitude: item.longitude,
        totalScore: item.totalScore,
        neighborhood: item.address.neighborhoodName,
      );

  factory RouteDraftProperty.fromDetail(PropertyDetail item) =>
      RouteDraftProperty(
        id: int.parse(item.id),
        monthlyRent: item.monthlyRent,
        areaM2: item.areaM2,
        roomCount: item.roomCount,
        latitude: item.latitude,
        longitude: item.longitude,
        totalScore: item.score.total,
        neighborhood: item.address.neighborhoodName,
      );
}

class RouteStart {
  const RouteStart({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;

  factory RouteStart.fromJson(Map<String, dynamic> json) => RouteStart(
    latitude: (json['lat'] as num).toDouble(),
    longitude: (json['lon'] as num).toDouble(),
    label: json['label'] as String? ?? 'Başlangıç',
  );

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lon': longitude,
    'label': label,
  };
}

class RouteSummary {
  const RouteSummary({
    required this.id,
    required this.name,
    required this.mode,
    required this.totalDistanceM,
    required this.totalDurationS,
    required this.createdAt,
    required this.stopCount,
  });

  final String id;
  final String name;
  final RouteTravelMode mode;
  final int totalDistanceM;
  final int totalDurationS;
  final DateTime createdAt;
  final int stopCount;

  factory RouteSummary.fromJson(Map<String, dynamic> json) => RouteSummary(
    id: json['id'].toString(),
    name: json['name'] as String? ?? 'İsimsiz rota',
    mode: RouteTravelMode.fromJson(json['mode']),
    totalDistanceM: (json['totalDistanceM'] as num? ?? 0).toInt(),
    totalDurationS: (json['totalDurationS'] as num? ?? 0).toInt(),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    stopCount: (json['stopCount'] as num? ?? 0).toInt(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'mode': mode.apiValue,
    'totalDistanceM': totalDistanceM,
    'totalDurationS': totalDurationS,
    'createdAt': createdAt.toIso8601String(),
    'stopCount': stopCount,
  };
}

class RouteStopProperty {
  const RouteStopProperty({
    required this.monthlyRent,
    required this.areaM2,
    required this.roomCount,
    required this.latitude,
    required this.longitude,
    this.neighborhood,
  });

  final double monthlyRent;
  final int areaM2;
  final String roomCount;
  final String? neighborhood;
  final double latitude;
  final double longitude;

  factory RouteStopProperty.fromJson(Map<String, dynamic> json) =>
      RouteStopProperty(
        monthlyRent: (json['monthlyRent'] as num? ?? 0).toDouble(),
        areaM2: (json['areaM2'] as num? ?? 0).toInt(),
        roomCount: json['roomCount'] as String? ?? '-',
        neighborhood: json['neighborhood'] as String?,
        latitude: (json['lat'] as num? ?? 0).toDouble(),
        longitude: (json['lon'] as num? ?? 0).toDouble(),
      );

  Map<String, Object?> toJson() => {
    'monthlyRent': monthlyRent,
    'areaM2': areaM2,
    'roomCount': roomCount,
    'neighborhood': neighborhood,
    'lat': latitude,
    'lon': longitude,
  };
}

class RouteStop {
  const RouteStop({
    required this.sequence,
    required this.propertyId,
    required this.property,
    this.score,
    this.legDistanceM,
    this.legDurationS,
    this.visitedAt,
  });

  final int sequence;
  final int propertyId;
  final double? score;
  final int? legDistanceM;
  final int? legDurationS;
  final DateTime? visitedAt;
  final RouteStopProperty property;

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
    sequence: (json['seq'] as num).toInt(),
    propertyId: (json['propertyId'] as num).toInt(),
    score: (json['score'] as num?)?.toDouble(),
    legDistanceM: (json['legDistanceM'] as num?)?.toInt(),
    legDurationS: (json['legDurationS'] as num?)?.toInt(),
    visitedAt:
        json['visitedAt'] is String
            ? DateTime.tryParse(json['visitedAt'] as String)
            : null,
    property: RouteStopProperty.fromJson(
      json['property'] as Map<String, dynamic>? ?? const {},
    ),
  );

  Map<String, Object?> toJson() => {
    'seq': sequence,
    'propertyId': propertyId,
    'score': score,
    'legDistanceM': legDistanceM,
    'legDurationS': legDurationS,
    'visitedAt': visitedAt?.toIso8601String(),
    'property': property.toJson(),
  };
}

class RouteManeuver {
  const RouteManeuver({
    required this.type,
    required this.location,
    this.modifier,
    this.exit,
  });

  final String type;
  final String? modifier;
  final List<double> location;
  final int? exit;

  factory RouteManeuver.fromJson(Map<String, dynamic> json) => RouteManeuver(
    type: json['type'] as String? ?? '',
    modifier: json['modifier'] as String?,
    location: (json['location'] as List<dynamic>? ?? const [])
        .map((value) => (value as num).toDouble())
        .toList(growable: false),
    exit: (json['exit'] as num?)?.toInt(),
  );

  Map<String, Object?> toJson() => {
    'type': type,
    'modifier': modifier,
    'location': location,
    'exit': exit,
  };
}

class RouteStep {
  const RouteStep({
    required this.distance,
    required this.duration,
    required this.name,
    required this.maneuver,
    this.geometry = const [],
  });

  final double distance;
  final double duration;
  final String name;
  final RouteManeuver maneuver;

  /// Bu adımın GeoJSON çizgisi; koordinatlar [longitude, latitude] sırasındadır.
  final List<List<double>> geometry;

  factory RouteStep.fromJson(Map<String, dynamic> json) => RouteStep(
    distance: (json['distance'] as num? ?? 0).toDouble(),
    duration: (json['duration'] as num? ?? 0).toDouble(),
    name: json['name'] as String? ?? '',
    maneuver: RouteManeuver.fromJson(
      json['maneuver'] as Map<String, dynamic>? ?? const {},
    ),
    geometry: _coordinates(json['geometry']),
  );

  Map<String, Object?> toJson() => {
    'distance': distance,
    'duration': duration,
    'name': name,
    'maneuver': maneuver.toJson(),
    'geometry': {'type': 'LineString', 'coordinates': geometry},
  };
}

class RouteLeg {
  const RouteLeg({required this.sequence, required this.steps});

  final int sequence;
  final List<RouteStep> steps;

  factory RouteLeg.fromJson(Map<String, dynamic> json) => RouteLeg(
    sequence: (json['seq'] as num? ?? 0).toInt(),
    steps: (json['steps'] as List<dynamic>? ?? const [])
        .map((item) => RouteStep.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  Map<String, Object?> toJson() => {
    'seq': sequence,
    'steps': steps.map((step) => step.toJson()).toList(growable: false),
  };
}

class RouteDetail {
  const RouteDetail({
    required this.id,
    required this.name,
    required this.start,
    required this.mode,
    required this.totalDistanceM,
    required this.totalDurationS,
    required this.stopCount,
    required this.geometry,
    required this.stops,
    required this.legs,
    required this.createdAt,
    this.isSaved = true,
  });

  final String id;
  final String name;
  final RouteStart start;
  final RouteTravelMode mode;
  final int totalDistanceM;
  final int totalDurationS;
  final int stopCount;
  final List<List<double>> geometry;
  final List<RouteStop> stops;
  final List<RouteLeg> legs;
  final DateTime createdAt;

  /// Rota veritabanına kaydedildi mi?
  ///
  /// `POST /routes/preview` hesaplanmış ama KAYDEDİLMEMİŞ bir rota döner:
  /// `id` boş, bu alan `false`. Arayüz buna bakıp "Rotayı kaydet" düğmesini
  /// gösteriyor — aksi hâlde kullanıcı kaydetmediği bir rotayı kaydedilmiş
  /// sanardı. Sunucu alanı göndermezse `true` varsayılıyor: eski kayıtlı
  /// rotalar (GET /routes/{id}) bu alanı taşımıyor olabilir.
  final bool isSaved;

  /// Durakların konut id'leri, ziyaret sırasıyla. Yeniden optimize ederken
  /// sunucuya bu liste gönderiliyor.
  List<int> get propertyIds =>
      stops.map((stop) => stop.propertyId).toList(growable: false);

  factory RouteDetail.fromJson(Map<String, dynamic> json) => RouteDetail(
    id: json['id'].toString(),
    name: json['name'] as String? ?? 'İsimsiz rota',
    start: RouteStart.fromJson(
      json['start'] as Map<String, dynamic>? ?? const {},
    ),
    mode: RouteTravelMode.fromJson(json['mode']),
    totalDistanceM: (json['totalDistanceM'] as num? ?? 0).toInt(),
    totalDurationS: (json['totalDurationS'] as num? ?? 0).toInt(),
    stopCount: (json['stopCount'] as num? ?? 0).toInt(),
    geometry: _coordinates(json['geometry']),
    stops: (json['stops'] as List<dynamic>? ?? const [])
        .map((item) => RouteStop.fromJson(item as Map<String, dynamic>))
        .toList(growable: false)
      ..sort((left, right) => left.sequence.compareTo(right.sequence)),
    legs: (json['legs'] as List<dynamic>? ?? const [])
        .map((item) => RouteLeg.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    isSaved: json['isSaved'] as bool? ?? true,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'start': start.toJson(),
    'mode': mode.apiValue,
    'totalDistanceM': totalDistanceM,
    'totalDurationS': totalDurationS,
    'stopCount': stopCount,
    'geometry': {'type': 'LineString', 'coordinates': geometry},
    'stops': stops.map((stop) => stop.toJson()).toList(growable: false),
    'legs': legs.map((leg) => leg.toJson()).toList(growable: false),
    'createdAt': createdAt.toIso8601String(),
    'isSaved': isSaved,
  };
}

List<List<double>> _coordinates(Object? geometry) {
  if (geometry is! Map<String, dynamic>) return const [];
  return (geometry['coordinates'] as List<dynamic>? ?? const [])
      .whereType<List<dynamic>>()
      .where((pair) => pair.length >= 2)
      .map(
        (pair) => <double>[
          (pair[0] as num).toDouble(),
          (pair[1] as num).toDouble(),
        ],
      )
      .toList(growable: false);
}
