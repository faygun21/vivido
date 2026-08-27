import 'dart:math' as math;

import '../../../core/network/api_client.dart';
import '../../map_data/domain/map_data_models.dart';
import '../../properties/domain/property_models.dart';
import '../domain/strength_poi_gateway.dart';

const _maxDensityPoisPerCategory = 8;

class ApiStrengthPoiGateway implements StrengthPoiGateway {
  const ApiStrengthPoiGateway(this._client);

  final ApiClient _client;

  @override
  Future<List<PoiMapItem>> getHighlightedPois({
    required double propertyLatitude,
    required double propertyLongitude,
    required List<PropertyScoreRow> strengths,
  }) async {
    try {
      final singleIds = strengths
          .where((row) => row.densityBonus == 0 && row.poiId != null)
          .map((row) => row.poiId!)
          .toSet()
          .toList(growable: false);
      final densityRows = strengths.where(
        (row) => row.densityBonus != 0 && row.searchRadiusM > 0,
      );

      final requests = <Future<List<PoiMapItem>>>[
        if (singleIds.isNotEmpty)
          _getList('/pois/by-id?ids=${singleIds.join(',')}'),
        for (final row in densityRows)
          _getList(
            Uri(
              path: '/pois/near',
              queryParameters: {
                'lat': propertyLatitude.toString(),
                'lon': propertyLongitude.toString(),
                'radiusM': row.searchRadiusM.toString(),
                'category': row.categoryCode,
              },
            ).toString(),
          ).then(
            (items) => _nearest(
              items,
              latitude: propertyLatitude,
              longitude: propertyLongitude,
            ).take(_maxDensityPoisPerCategory).toList(growable: false),
          ),
      ];
      if (requests.isEmpty) return const [];

      final groups = await Future.wait(requests);
      final unique = <String, PoiMapItem>{};
      for (final item in groups.expand((group) => group)) {
        unique[item.id] = item;
      }
      return unique.values.toList(growable: false);
    } on ApiException catch (error) {
      throw StrengthPoiFailure(error.detail ?? error.title);
    } on StrengthPoiFailure {
      rethrow;
    } on Object {
      throw const StrengthPoiFailure('Güçlü yön hizmet noktaları yüklenemedi.');
    }
  }

  Future<List<PoiMapItem>> _getList(String path) async {
    final response = await _client.get(path);
    if (response is! List<dynamic>) {
      throw const StrengthPoiFailure('POI yanıtı beklenen biçimde değil.');
    }
    return response
        .map((item) => PoiMapItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}

Iterable<PoiMapItem> _nearest(
  List<PoiMapItem> items, {
  required double latitude,
  required double longitude,
}) {
  final sorted = items.toList();
  sorted.sort(
    (a, b) => _distance(
      latitude,
      longitude,
      a.latitude,
      a.longitude,
    ).compareTo(_distance(latitude, longitude, b.latitude, b.longitude)),
  );
  return sorted;
}

double _distance(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusMetres = 6371000.0;
  final dLat = _radians(lat2 - lat1);
  final dLon = _radians(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * earthRadiusMetres * math.asin(math.sqrt(a));
}

double _radians(double degrees) => degrees * math.pi / 180;
