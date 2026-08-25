import 'dart:math' as math;

const walkingMinuteOptions = <int>[5, 10, 15, 20, 30];
const defaultWalkingMinutes = 15;

const analysisRadiusOptionsKm = <double>[0.5, 1, 2, 3, 5];
const defaultAnalysisRadiusKm = 2.0;

const _walkingMetresPerMinute = 80.0;
const _earthRadiusMetres = 6371008.8;

final class AnalysisCoordinate {
  const AnalysisCoordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

double walkingRadiusMetres(int minutes) {
  if (!walkingMinuteOptions.contains(minutes)) {
    throw ArgumentError.value(minutes, 'minutes', 'Desteklenmeyen süre');
  }
  return minutes * _walkingMetresPerMinute;
}

List<AnalysisCoordinate> createRadiusRing({
  required AnalysisCoordinate center,
  required double radiusMetres,
  int segments = 72,
}) {
  if (!radiusMetres.isFinite || radiusMetres <= 0) {
    throw ArgumentError.value(
      radiusMetres,
      'radiusMetres',
      'Yarıçap sıfırdan büyük olmalıdır',
    );
  }
  if (segments < 3) {
    throw ArgumentError.value(segments, 'segments', 'En az 3 parça gerekir');
  }

  final angularDistance = radiusMetres / _earthRadiusMetres;
  final latitude = _toRadians(center.latitude);
  final longitude = _toRadians(center.longitude);
  final ring = <AnalysisCoordinate>[];

  for (var index = 0; index < segments; index += 1) {
    final bearing = 2 * math.pi * index / segments;
    final targetLatitude = math.asin(
      math.sin(latitude) * math.cos(angularDistance) +
          math.cos(latitude) * math.sin(angularDistance) * math.cos(bearing),
    );
    final targetLongitude =
        longitude +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(latitude),
          math.cos(angularDistance) -
              math.sin(latitude) * math.sin(targetLatitude),
        );

    ring.add(
      AnalysisCoordinate(
        latitude: _toDegrees(targetLatitude),
        longitude: _toDegrees(targetLongitude),
      ),
    );
  }

  return [...ring, ring.first];
}

double _toRadians(double value) => value * math.pi / 180;

double _toDegrees(double value) => value * 180 / math.pi;
