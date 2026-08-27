import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivido_mobile/core/network/api_client.dart';
import 'package:vivido_mobile/core/storage/token_store.dart';
import 'package:vivido_mobile/features/properties/domain/property_models.dart';
import 'package:vivido_mobile/features/property_strengths/data/api_strength_poi_gateway.dart';

void main() {
  test('güçlü yönün gerçek POI ve yoğunluk noktalarını getirir', () async {
    final requests = <Uri>[];
    final client = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStore: MemoryTokenStore(),
      httpClient: MockClient((request) async {
        requests.add(request.url);
        if (request.url.path.endsWith('/pois/by-id')) {
          return _jsonResponse([_poi(11, latitude: 39.9, longitude: 32.8)]);
        }
        return _jsonResponse([
          for (var id = 20; id < 30; id++)
            _poi(id, latitude: 39.9 + (id - 20) / 1000, longitude: 32.8),
        ]);
      }),
    );
    addTearDown(client.close);
    final gateway = ApiStrengthPoiGateway(client);

    final pois = await gateway.getHighlightedPois(
      propertyLatitude: 39.9,
      propertyLongitude: 32.8,
      strengths: const [
        _StrengthRow(poiId: '11'),
        _StrengthRow(
          categoryCode: 'market',
          densityBonus: 1.2,
          searchRadiusM: 900,
        ),
      ],
    );

    expect(pois.length, 9);
    expect(pois.first.id, '11');
    expect(pois.skip(1).map((poi) => poi.id), [
      '20',
      '21',
      '22',
      '23',
      '24',
      '25',
      '26',
      '27',
    ]);
    expect(requests.first.queryParameters['ids'], '11');
    expect(requests.last.queryParameters['radiusM'], '900');
    expect(requests.last.queryParameters['category'], 'market');
  });
}

class _StrengthRow extends PropertyScoreRow {
  const _StrengthRow({
    super.categoryCode = 'park',
    super.densityBonus = 0,
    super.poiId,
    super.searchRadiusM = 0,
  }) : super(
         label: 'Güçlü yön',
         durationMin: 5,
         targetMin: 10,
         cutoffMin: 20,
         subScore: 95,
         weight: 1,
         contribution: 95,
         status: 'strong',
       );
}

Map<String, Object?> _poi(
  int id, {
  required double latitude,
  required double longitude,
}) => {
  'id': id,
  'name': 'POI $id',
  'categoryCode': 'market',
  'latitude': latitude,
  'longitude': longitude,
};

http.Response _jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
