import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivido_mobile/core/network/api_client.dart';
import 'package:vivido_mobile/core/storage/token_store.dart';
import 'package:vivido_mobile/features/map_data/application/map_data_controller.dart';
import 'package:vivido_mobile/features/map_data/data/api_map_data_gateway.dart';
import 'package:vivido_mobile/features/map_data/domain/map_data_gateway.dart';
import 'package:vivido_mobile/features/map_data/domain/map_data_models.dart';

void main() {
  group('ApiMapDataGateway', () {
    test(
      'POI ve konut endpointlerini doğru bbox ve kategorilerle çağırır',
      () async {
        final requests = <Uri>[];
        final client = ApiClient(
          baseUrl: 'http://localhost/api/v1',
          tokenStore: MemoryTokenStore(),
          httpClient: MockClient((request) async {
            requests.add(request.url);
            return switch (request.url.path) {
              '/api/v1/pois/categories' => _jsonResponse([
                {'code': 'market', 'displayNameTr': 'Market'},
                {'code': 'park', 'displayNameTr': 'Park / Yeşil Alan'},
              ]),
              '/api/v1/pois' => _jsonResponse([
                {
                  'id': 12,
                  'name': 'Deneme Marketi',
                  'categoryCode': 'market',
                  'latitude': 39.9,
                  'longitude': 32.8,
                },
              ]),
              // ⚠️ Girişli uç NESNE döner (anchor koridoru eklenince
              // değişti). Sahte yanıt eskiden düz dizi veriyordu; gerçek
              // API değişince mobil "beklenen biçimde değil" hatasına
              // düşüp haritada 0 konut gösteriyordu ama test yanlış şekli
              // kodladığı için yeşil kalmaya devam etti.
              //
              // Hemen aşağıdaki `/properties/map` (misafir ucu) HÂLÂ
              // dizi döndürüyor — ikisi bilerek farklı.
              '/api/v1/properties' => _jsonResponse({
                'items': [
                  {
                    'id': '42',
                    'monthlyRent': 18000,
                    'areaM2': 90,
                    'roomCount': '2+1',
                    'latitude': 39.91,
                    'longitude': 32.81,
                    'totalScore': 87.5,
                  },
                ],
                'corridorPolygon': null,
              }),
              '/api/v1/properties/map' => _jsonResponse([
                {
                  'id': 43,
                  'externalRef': 'SYN-43',
                  'monthlyRent': 16000,
                  'areaM2': 80,
                  'roomCount': '2+1',
                  'latitude': 39.92,
                  'longitude': 32.82,
                  'buildingAge': 4,
                  'hasElevator': true,
                  'isSynthetic': true,
                },
              ]),
              _ => _jsonResponse({'title': 'Bulunamadı'}, statusCode: 404),
            };
          }),
        );
        addTearDown(client.close);
        final gateway = ApiMapDataGateway(client);
        const bounds = MapViewportBounds(
          west: 32.7,
          south: 39.8,
          east: 32.9,
          north: 40,
        );

        final categories = await gateway.getPoiCategories();
        final pois = await gateway.getPois(
          bounds: bounds,
          categories: {'park', 'market'},
        );
        final authenticated = await gateway.getAuthenticatedProperties();
        final public = await gateway.getPublicProperties(bounds);

        expect(categories.map((item) => item.code), ['market', 'park']);
        expect(pois.single.name, 'Deneme Marketi');
        expect(authenticated.single.totalScore, 87.5);
        expect(public.single.isSynthetic, isTrue);
        expect(public.single.hasElevator, isTrue);

        final poiRequest = requests.singleWhere(
          (uri) => uri.path == '/api/v1/pois',
        );
        expect(poiRequest.queryParameters['categories'], 'market,park');
        expect(poiRequest.queryParameters['west'], '32.700000');
        final publicRequest = requests.singleWhere(
          (uri) => uri.path == '/api/v1/properties/map',
        );
        expect(publicRequest.queryParameters['north'], '40.000000');
      },
    );

    test('girisli uc dizi donerse ANLASILIR bir hata verir', () async {
      // Sözleşme yeniden değişirse (ya da eski bir sunucuya bağlanılırsa)
      // sessizce "0 konut" göstermek yerine hata üretmeli: sessizlik,
      // bu regresyonun günlerce fark edilmemesinin sebebiydi.
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: MemoryTokenStore(),
        httpClient: MockClient((_) async => _jsonResponse(<Object>[])),
      );
      addTearDown(client.close);

      expect(
        () => ApiMapDataGateway(client).getAuthenticatedProperties(),
        throwsA(isA<MapDataFailure>()),
      );
    });

    test('items alani eksikse hata verir', () async {
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: MemoryTokenStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({'corridorPolygon': null}),
        ),
      );
      addTearDown(client.close);

      expect(
        () => ApiMapDataGateway(client).getAuthenticatedProperties(),
        throwsA(isA<MapDataFailure>()),
      );
    });
  });

  group('MapDataController', () {
    test(
      'oturumlu kullanıcıda kategorileri ve skorlanmış konutları yükler',
      () async {
        final gateway = _FakeMapDataGateway();
        final controller = MapDataController(
          gateway: gateway,
          authenticated: true,
          viewportDebounce: const Duration(days: 1),
        );
        addTearDown(controller.dispose);

        await controller.initialize();
        controller.updateViewport(_bounds);
        await controller.refreshViewport();

        expect(controller.selectedCategories, {'market', 'park'});
        expect(controller.properties.single.totalScore, 91);
        expect(controller.pois.single.categoryCode, 'market');
        expect(gateway.authenticatedPropertyCalls, 1);
        expect(gateway.publicPropertyCalls, 0);
      },
    );

    test('misafirde görünür alandaki temel konutları yükler', () async {
      final gateway = _FakeMapDataGateway();
      final controller = MapDataController(
        gateway: gateway,
        authenticated: false,
        viewportDebounce: const Duration(days: 1),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.properties, isEmpty);

      controller.updateViewport(_bounds);
      await controller.refreshViewport();

      expect(controller.properties.single.buildingAge, 7);
      expect(gateway.authenticatedPropertyCalls, 0);
      expect(gateway.publicPropertyCalls, 1);
    });
  });
}

const _bounds = MapViewportBounds(
  west: 32.7,
  south: 39.8,
  east: 32.9,
  north: 40,
);

class _FakeMapDataGateway implements MapDataGateway {
  int authenticatedPropertyCalls = 0;
  int publicPropertyCalls = 0;

  @override
  Future<List<PoiCategory>> getPoiCategories() async => const [
    PoiCategory(code: 'market', displayNameTr: 'Market'),
    PoiCategory(code: 'park', displayNameTr: 'Park / Yeşil Alan'),
  ];

  @override
  Future<List<PoiMapItem>> getPois({
    required MapViewportBounds bounds,
    required Set<String> categories,
  }) async => const [
    PoiMapItem(
      id: '1',
      name: 'Market',
      categoryCode: 'market',
      latitude: 39.9,
      longitude: 32.8,
    ),
  ];

  @override
  Future<List<PropertyMapItem>> getAuthenticatedProperties() async {
    authenticatedPropertyCalls++;
    return const [
      PropertyMapItem(
        id: '2',
        latitude: 39.9,
        longitude: 32.8,
        monthlyRent: 20000,
        areaM2: 100,
        roomCount: '3+1',
        totalScore: 91,
      ),
    ];
  }

  @override
  Future<List<PropertyMapItem>> getPublicProperties(
    MapViewportBounds bounds,
  ) async {
    publicPropertyCalls++;
    return const [
      PropertyMapItem(
        id: '3',
        latitude: 39.91,
        longitude: 32.81,
        monthlyRent: 17000,
        areaM2: 85,
        roomCount: '2+1',
        buildingAge: 7,
        hasElevator: true,
        isSynthetic: true,
      ),
    ];
  }
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
