import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivido_mobile/core/network/api_client.dart';
import 'package:vivido_mobile/core/storage/token_store.dart';
import 'package:vivido_mobile/features/location_search/application/location_search_controller.dart';
import 'package:vivido_mobile/features/location_search/data/api_location_search_gateway.dart';
import 'package:vivido_mobile/features/location_search/domain/location_search_models.dart';

void main() {
  test('mobil gateway sorguyu kodlar ve Photon sonucunu ayrıştırır', () async {
    final client = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStore: MemoryTokenStore(),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/locations/search');
        expect(request.url.queryParameters['q'], '1602. sokak');
        expect(request.url.queryParameters['limit'], '5');
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'photon:W:1602',
                'label': '1602. Sokak, Üniversiteler, Çankaya',
                'kind': 'address',
                'latitude': 39.89,
                'longitude': 32.80,
                'bounds': {
                  'south': 39.88,
                  'west': 32.79,
                  'north': 39.90,
                  'east': 32.81,
                },
                'neighborhood': 'Üniversiteler',
                'source': 'photon',
              },
            ],
            'attribution': '© OpenStreetMap contributors',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);

    final response = await ApiLocationSearchGateway(client)
        .search('1602. sokak');

    expect(response.items, hasLength(1));
    expect(response.items.single.source, 'photon');
    expect(response.items.single.bounds?.east, 32.81);
  });

  test('arama controllerı sonucu seçer ve servis hatasını açıklar', () async {
    final gateway = _FakeGateway();
    final controller = LocationSearchController(gateway);
    addTearDown(controller.dispose);

    await controller.search('Atakule');
    expect(controller.results, hasLength(1));
    controller.select(controller.results.single);
    expect(controller.selected?.label, 'Atakule, Çankaya');
    expect(controller.results, isEmpty);
    expect(controller.searched, isFalse);

    gateway.error = const ApiException(
      statusCode: 503,
      title: 'Konum arama kullanılamıyor',
      code: 'LOCATION_SEARCH_UNAVAILABLE',
    );
    await controller.search('Kızılay');
    expect(controller.errorMessage, contains('ulaşılamıyor'));
  });
}

class _FakeGateway implements LocationSearchGateway {
  Object? error;

  @override
  Future<LocationSearchResponse> search(String query, {int limit = 5}) async {
    if (error case final current?) throw current;
    return const LocationSearchResponse(
      attribution: '© OpenStreetMap contributors',
      items: [
        LocationSearchResult(
          id: 'photon:W:1',
          label: 'Atakule, Çankaya',
          kind: 'place',
          latitude: 39.886,
          longitude: 32.856,
          source: 'photon',
        ),
      ],
    );
  }
}
