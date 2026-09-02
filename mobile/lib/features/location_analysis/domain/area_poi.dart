import 'dart:math' as math;

import '../../map_data/domain/map_data_models.dart';
import 'location_analysis.dart';

/// Analiz alanı içindeki bir hizmet noktası ve merkeze uzaklığı.
///
/// Uzaklık İSTEMCİDE hesaplanıyor. Sunucu `/pois/near` uçları zaten yarıçap
/// içinde filtreliyor ama mesafeyi döndürmüyor; her POI için ayrı bir
/// mesafe isteği atmak (bir kategoride 40 nokta olabiliyor) hem yavaş hem
/// gereksiz. Kuş uçuşu mesafe bu ekran için yeterli: kullanıcı "market 300
/// metre" bilgisiyle karar veriyor, 280 mi 310 mu olduğuyla değil.
///
/// ⚠️ YÜRÜME SÜRESİ DE TAHMİN. `walkingRadiusMetres` ile aynı sabiti
/// (80 m/dk) kullanıyor — alanın yarıçapı bu hızla çizildiği için listedeki
/// süreler çemberle TUTARLI olmak zorunda. Farklı bir sabit kullansaydık
/// çemberin kenarındaki bir nokta "18 dk" diyebilirdi, oysa çember 15 dk.
final class AreaPoi {
  const AreaPoi({required this.poi, required this.distanceM});

  final PoiMapItem poi;

  /// Analiz merkezine kuş uçuşu mesafe (metre).
  final double distanceM;

  /// Yaklaşık yürüme süresi (dakika). En az 1 — "0 dk" bir bilgi değil.
  int get walkingMinutes => math.max(1, (distanceM / 80).round());
}

/// Merkeze göre sıralanmış alan içi POI listesi üretir.
List<AreaPoi> rankByDistance({
  required AnalysisCoordinate center,
  required List<PoiMapItem> pois,
  required double radiusM,
}) {
  final ranked = <AreaPoi>[];
  for (final poi in pois) {
    final distance = haversineMetres(
      center.latitude,
      center.longitude,
      poi.latitude,
      poi.longitude,
    );
    // Sunucu yarıçapı bbox/PostGIS ile uyguluyor; kenar durumlarda birkaç
    // metre taşan sonuçlar gelebiliyor. Listede "yürüme alanı içinde"
    // diyorsak gerçekten içinde olmalı.
    if (distance > radiusM) continue;
    ranked.add(AreaPoi(poi: poi, distanceM: distance));
  }
  ranked.sort((left, right) => left.distanceM.compareTo(right.distanceM));
  return ranked;
}

const _earthRadiusMetres = 6371008.8;

double haversineMetres(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _radians(lat2 - lat1);
  final dLon = _radians(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * _earthRadiusMetres * math.asin(math.sqrt(a).clamp(0, 1));
}

double _radians(double degrees) => degrees * math.pi / 180;

class AreaPoiFailure implements Exception {
  const AreaPoiFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AreaPoiGateway {
  /// Verilen merkezin [radiusM] metre çevresindeki belirli kategorideki
  /// hizmet noktalarını getirir.
  Future<List<PoiMapItem>> getPoisNear({
    required double latitude,
    required double longitude,
    required double radiusM,
    required String categoryCode,
  });
}
