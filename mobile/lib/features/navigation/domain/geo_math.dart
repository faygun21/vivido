import 'dart:math' as math;

const _earthRadiusM = 6371008.8;

/// İki [latitude, longitude] noktası arasındaki büyük daire mesafesi (metre).
double haversineM(double lat1, double lon1, double lat2, double lon2) {
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return _earthRadiusM *
      2 *
      math.atan2(math.sqrt(a), math.sqrt(math.max(0, 1 - a)));
}

/// GeoJSON sırasındaki [longitude, latitude] noktasının doğru parçasına
/// uzaklığını, en yakın noktayı ve parçadaki 0–1 ilerlemeyi döndürür.
({double distanceM, List<double> closest, double t}) distanceToSegmentM(
  List<double> point,
  List<double> a,
  List<double> b,
) {
  if (point.length < 2 || a.length < 2 || b.length < 2) {
    return (distanceM: double.infinity, closest: const [], t: 0);
  }
  const metresPerDegreeLat = 111320.0;
  final lonScale =
      metresPerDegreeLat * math.cos(point[1] * math.pi / 180).abs();
  final ax = (a[0] - point[0]) * lonScale;
  final ay = (a[1] - point[1]) * metresPerDegreeLat;
  final bx = (b[0] - point[0]) * lonScale;
  final by = (b[1] - point[1]) * metresPerDegreeLat;
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  final t =
      lengthSquared == 0
          ? 0.0
          : (-(ax * dx + ay * dy) / lengthSquared).clamp(0.0, 1.0);
  final x = ax + t * dx;
  final y = ay + t * dy;
  return (
    distanceM: math.sqrt(x * x + y * y),
    closest: [point[0] + x / lonScale, point[1] + y / metresPerDegreeLat],
    t: t,
  );
}

/// GeoJSON [longitude, latitude] çizgisine en kısa mesafeyi döndürür.
({double distanceM, int segmentIndex, List<double> closest})
distanceToPolylineM(List<double> point, List<List<double>> polyline) {
  if (polyline.isEmpty) {
    return (distanceM: double.infinity, segmentIndex: -1, closest: const []);
  }
  if (polyline.length == 1) {
    return (
      distanceM: haversineM(
        point[1],
        point[0],
        polyline.first[1],
        polyline.first[0],
      ),
      segmentIndex: 0,
      closest: List<double>.from(polyline.first),
    );
  }
  var bestDistance = double.infinity;
  var bestIndex = 0;
  var bestPoint = const <double>[];
  for (var index = 0; index < polyline.length - 1; index++) {
    final result = distanceToSegmentM(
      point,
      polyline[index],
      polyline[index + 1],
    );
    if (result.distanceM < bestDistance) {
      bestDistance = result.distanceM;
      bestIndex = index;
      bestPoint = result.closest;
    }
  }
  return (distanceM: bestDistance, segmentIndex: bestIndex, closest: bestPoint);
}

/// GeoJSON [longitude, latitude] noktaları arasındaki pusula yönü.
double bearingDeg(List<double> from, List<double> to) {
  final lat1 = from[1] * math.pi / 180;
  final lat2 = to[1] * math.pi / 180;
  final dLon = (to[0] - from[0]) * math.pi / 180;
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}
