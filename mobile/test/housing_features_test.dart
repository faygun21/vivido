import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivido_mobile/core/network/api_client.dart';
import 'package:vivido_mobile/core/storage/token_store.dart';
import 'package:vivido_mobile/features/favorites/application/favorites_controller.dart';
import 'package:vivido_mobile/features/favorites/data/api_favorites_gateway.dart';
import 'package:vivido_mobile/features/favorites/domain/favorite_models.dart';
import 'package:vivido_mobile/features/favorites/domain/favorites_gateway.dart';
import 'package:vivido_mobile/features/properties/application/property_catalog_controller.dart';
import 'package:vivido_mobile/features/properties/data/api_property_gateway.dart';
import 'package:vivido_mobile/features/routes/application/routes_controller.dart';
import 'package:vivido_mobile/features/routes/data/api_routes_gateway.dart';
import 'package:vivido_mobile/features/routes/domain/route_models.dart';
import 'package:vivido_mobile/features/routes/domain/routes_gateway.dart';

void main() {
  group('Konut ve favori API sözleşmeleri', () {
    test('en uygun listeyi ve açıklanabilir detayı ayrıştırır', () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: MemoryTokenStore(),
        httpClient: MockClient((request) async {
          requests.add(request);
          return switch (request.url.path) {
            // ⚠️ Bu uç NESNE döner, dizi DEĞİL. Sahte yanıt eskiden düz
            // dizi veriyordu; gerçek API anchor filtresiyle nesneye
            // çevrilince mobil istemci patladı ama test yanlış şekli
            // kodladığı için yeşil kalmaya devam etti. Konutlar sekmesinin
            // hiç açılmamasının sebebi buydu.
            '/api/v1/properties/top' => _jsonResponse({
              'items': [_propertySummaryJson],
              'nearestFallback': null,
              'corridorPolygon': null,
            }),
            '/api/v1/properties/42' => _jsonResponse(_propertyDetailJson),
            _ => _jsonResponse({'title': 'Bulunamadı'}, statusCode: 404),
          };
        }),
      );
      addTearDown(client.close);
      final gateway = ApiPropertyGateway(client);

      final top = await gateway.getTopProperties(limit: 12);
      final detail = await gateway.getPropertyDetail('42');

      expect(requests.first.url.queryParameters['limit'], '12');
      // Anchor koridoru varsayılan olarak AÇIK (showAll=false) — web ile
      // aynı davranış.
      expect(requests.first.url.queryParameters['showAll'], 'false');
      expect(top.items.single.address.neighborhoodName, 'Ayrancı');
      expect(top.items.single.isFavorite, isTrue);
      expect(detail.features.hasParking, isTrue);
      expect(detail.score.rows.single.categoryCode, 'market');
      expect(detail.score.weakLink?.points, -2.5);
      expect(detail.score.budget.ratioToMax, 0.8);
    });

    test('koridor bosken en yakin ev onerisi tasinir', () async {
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: MemoryTokenStore(),
        httpClient: MockClient((request) async {
          return _jsonResponse({
            'items': <Object>[],
            'nearestFallback': _propertySummaryJson,
            'corridorPolygon': null,
          });
        }),
      );
      addTearDown(client.close);

      final top = await ApiPropertyGateway(client).getTopProperties();

      // "Uygun ev yok" ile "burada yok ama en yakını şu" farklı mesajlar;
      // arayüz ikisini ayırt edebilsin diye alan taşınıyor.
      expect(top.items, isEmpty);
      expect(top.nearestFallback?.address.neighborhoodName, 'Ayrancı');
    });

    test('tum evleri goster acikken sunucuya showAll gonderilir', () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: MemoryTokenStore(),
        httpClient: MockClient((request) async {
          requests.add(request);
          return _jsonResponse({
            'items': [_propertySummaryJson],
            'nearestFallback': null,
            'corridorPolygon': null,
          });
        }),
      );
      addTearDown(client.close);

      final controller = PropertyCatalogController(ApiPropertyGateway(client));
      await controller.load();
      await controller.setShowAll(true);

      // Filtre SUNUCUDA uygulanıyor; elde süzmek yanlış olurdu çünkü
      // koridor dışındaki evler zaten yanıtta hiç yok.
      expect(requests, hasLength(2));
      expect(requests.first.url.queryParameters['showAll'], 'false');
      expect(requests.last.url.queryParameters['showAll'], 'true');
      expect(controller.showAll, isTrue);
    });

    test('favori GET POST DELETE isteklerini doğru gönderir', () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: MemoryTokenStore(),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return _jsonResponse([
              {
                'propertyId': 42,
                'createdAt': '2026-08-26T08:00:00Z',
                'property': _propertySummaryJson,
              },
            ]);
          }
          return http.Response('', 204);
        }),
      );
      addTearDown(client.close);
      final gateway = ApiFavoritesGateway(client);

      final favorites = await gateway.getFavorites();
      await gateway.addFavorite('42');
      await gateway.removeFavorite('42');

      expect(favorites.single.property?.id, '42');
      expect(requests[1].method, 'POST');
      expect(jsonDecode(requests[1].body), {'propertyId': 42});
      expect(requests[2].method, 'DELETE');
      expect(requests[2].url.path, '/api/v1/profile/favorites/42');
    });
  });

  group('Rota API sözleşmeleri', () {
    test(
      'oluşturma gövdesini gönderir ve GeoJSON lon-lat sırasını korur',
      () async {
        late http.Request createRequest;
        final client = ApiClient(
          baseUrl: 'http://localhost/api/v1',
          tokenStore: MemoryTokenStore(),
          httpClient: MockClient((request) async {
            if (request.method == 'POST') createRequest = request;
            return _jsonResponse(_routeDetailJson, statusCode: 201);
          }),
        );
        addTearDown(client.close);
        final gateway = ApiRoutesGateway(client);

        final route = await gateway.createRoute(
          name: 'Cumartesi turu',
          start: const RouteStart(latitude: 39.9, longitude: 32.8, label: 'Ev'),
          propertyIds: const [42, 43],
          mode: RouteTravelMode.foot,
        );

        expect(jsonDecode(createRequest.body), {
          'name': 'Cumartesi turu',
          'start': {'lat': 39.9, 'lon': 32.8, 'label': 'Ev'},
          'propertyIds': [42, 43],
          'mode': 'foot',
        });
        expect(route.geometry.first, [32.8, 39.9]);
        expect(route.stops.first.legDistanceM, isNull);
        expect(route.stops.first.score, isNull);
        expect(route.start.label, 'Ev');
      },
    );

    test('rota controller tekrarları engeller ve 8 durak sınırını uygular', () {
      final controller = RoutesController(_FakeRoutesGateway());
      addTearDown(controller.dispose);

      expect(controller.addProperty(_draft(1)), isTrue);
      expect(controller.addProperty(_draft(1)), isTrue);
      for (var id = 2; id <= 8; id++) {
        expect(controller.addProperty(_draft(id)), isTrue);
      }
      expect(controller.draft.length, 8);
      expect(controller.addProperty(_draft(9)), isFalse);
      expect(controller.draft.length, 8);
    });

    test('rota oluşturur, kaydeder ve aktif rotayı günceller', () async {
      final gateway = _FakeRoutesGateway();
      final controller = RoutesController(gateway);
      addTearDown(controller.dispose);
      controller
        ..addProperty(_draft(42))
        ..addProperty(_draft(43));

      final created = await controller.createRoute(
        name: 'Test rotası',
        start: const RouteStart(
          latitude: 39.9,
          longitude: 32.8,
          label: 'Başlangıç',
        ),
        mode: RouteTravelMode.car,
      );

      expect(created, isTrue);
      expect(gateway.createdPropertyIds, [42, 43]);
      expect(controller.activeRoute?.id, 'route-created-1');
      expect(controller.savedRoutes.single.stopCount, 2);
      expect(controller.draft, isEmpty);
    });

    test(
      'rota kaydedildikten sonra liste yenileme hatası başarıyı geri almaz',
      () async {
        final gateway = _FakeRoutesGateway()..failGetRoutes = true;
        final controller = RoutesController(gateway);
        addTearDown(controller.dispose);
        controller
          ..addProperty(_draft(42))
          ..addProperty(_draft(43));

        final created = await controller.createRoute(
          name: 'Bağlantı testi',
          start: const RouteStart(
            latitude: 39.9,
            longitude: 32.8,
            label: 'Başlangıç',
          ),
          mode: RouteTravelMode.car,
        );

        expect(created, isTrue);
        expect(controller.activeRoute?.id, 'route-created-1');
        expect(controller.savedRoutes.single.id, 'route-created-1');
        expect(controller.errorMessage, isNull);
      },
    );

    test(
      'eski rota silinemese de yeniden oluşturulan rota aktif kalır',
      () async {
        final gateway =
            _FakeRoutesGateway()
              ..failDelete = true
              ..failGetRoutes = true;
        final controller = RoutesController(gateway);
        addTearDown(controller.dispose);
        final oldRoute = RouteDetail.fromJson({
          ..._routeDetailJson,
          'id': 'old-route',
          'stopCount': 3,
          'stops': [
            ..._routeDetailJson['stops']! as List<Object?>,
            {
              ...(_routeDetailJson['stops']! as List<Object?>).last
                  as Map<String, Object?>,
              'seq': 3,
              'propertyId': 44,
            },
          ],
        });
        controller
          ..activeRoute = oldRoute
          ..savedRoutes = [
            RouteSummary(
              id: oldRoute.id,
              name: oldRoute.name,
              mode: oldRoute.mode,
              totalDistanceM: oldRoute.totalDistanceM,
              totalDurationS: oldRoute.totalDurationS,
              createdAt: oldRoute.createdAt,
              stopCount: oldRoute.stopCount,
            ),
          ];

        final updated = await controller.reoptimizeWithout(42);

        expect(updated, isTrue);
        expect(controller.activeRoute?.id, 'route-created-1');
        expect(controller.activeRoute?.stops.length, 2);
        expect(controller.errorMessage, contains('önceki rota silinemedi'));
        expect(gateway.deletedIds, ['old-route']);
      },
    );
  });

  test('favori controller mutasyondan sonra sunucuyu yeniden okur', () async {
    final gateway = _FakeFavoritesGateway();
    final controller = FavoritesController(gateway);
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.items, isEmpty);
    expect(await controller.setFavorite('42', true), isTrue);
    expect(controller.contains('42'), isTrue);
    expect(await controller.setFavorite('42', false), isTrue);
    expect(controller.contains('42'), isFalse);
  });

  test(
    'favori silme kaydedildiyse liste yenileme hatası işlemi geri almaz',
    () async {
      final gateway = _FakeFavoritesGateway()..ids.add('42');
      final controller = FavoritesController(gateway);
      addTearDown(controller.dispose);
      await controller.load();
      gateway.failReads = true;

      final removed = await controller.setFavorite('42', false);

      expect(removed, isTrue);
      expect(controller.contains('42'), isFalse);
      expect(controller.errorMessage, contains('liste şu anda yenilenemedi'));
    },
  );
}

class _FakeFavoritesGateway implements FavoritesGateway {
  final Set<String> ids = {};
  bool failReads = false;

  @override
  Future<void> addFavorite(String propertyId) async => ids.add(propertyId);

  @override
  Future<List<FavoriteEntry>> getFavorites() async {
    if (failReads) throw StateError('list failed');
    return [
      for (final id in ids)
        FavoriteEntry(propertyId: id, createdAt: DateTime.utc(2026, 8, 26)),
    ];
  }

  @override
  Future<void> removeFavorite(String propertyId) async =>
      ids.remove(propertyId);
}

class _FakeRoutesGateway implements RoutesGateway {
  List<int>? createdPropertyIds;
  bool failGetRoutes = false;
  bool failDelete = false;
  int createCallCount = 0;
  final List<String> deletedIds = [];
  RouteDetail? lastCreated;

  @override
  Future<RouteDetail> createRoute({
    required String name,
    required RouteStart start,
    required List<int> propertyIds,
    required RouteTravelMode mode,
  }) async {
    createCallCount++;
    createdPropertyIds = propertyIds;
    final templateStops = _routeDetailJson['stops']! as List<Object?>;
    lastCreated = RouteDetail.fromJson({
      ..._routeDetailJson,
      'id': 'route-created-$createCallCount',
      'name': name,
      'mode': mode.apiValue,
      'start': start.toJson(),
      'stopCount': propertyIds.length,
      'stops': [
        for (var index = 0; index < propertyIds.length; index++)
          {
            ...(templateStops[index % templateStops.length]
                as Map<String, Object?>),
            'seq': index + 1,
            'propertyId': propertyIds[index],
          },
      ],
    });
    return lastCreated!;
  }

  @override
  Future<void> deleteRoute(String id) async {
    deletedIds.add(id);
    if (failDelete) throw StateError('delete failed');
  }

  @override
  Future<RouteDetail> getRoute(String id) async =>
      RouteDetail.fromJson(_routeDetailJson);

  @override
  Future<List<RouteSummary>> getRoutes() async {
    if (failGetRoutes) throw StateError('list failed');
    final route = lastCreated;
    return [
      if (route == null)
        RouteSummary.fromJson(_routeDetailJson)
      else
        RouteSummary(
          id: route.id,
          name: route.name,
          mode: route.mode,
          totalDistanceM: route.totalDistanceM,
          totalDurationS: route.totalDurationS,
          createdAt: route.createdAt,
          stopCount: route.stopCount,
        ),
    ];
  }
}

RouteDraftProperty _draft(int id) => RouteDraftProperty(
  id: id,
  monthlyRent: 18000,
  areaM2: 90,
  roomCount: '2+1',
  latitude: 39.9,
  longitude: 32.8,
  totalScore: 80,
);

const _propertyAddressJson = <String, Object?>{
  'streetName': 'Hoşdere Caddesi',
  'neighborhoodName': 'Ayrancı',
  'districtName': 'Çankaya',
  'cityName': 'Ankara',
  'formatted': 'Hoşdere Caddesi, Ayrancı, Çankaya / Ankara',
};

const _propertySummaryJson = <String, Object?>{
  'id': '42',
  'externalRef': 'SYN-42',
  'monthlyRent': 20000,
  'areaM2': 95,
  'roomCount': '3+1',
  'latitude': 39.9,
  'longitude': 32.8,
  'totalScore': 82.5,
  'band': 'good',
  'address': _propertyAddressJson,
  'topStrength': 'Market erişimi',
  'topWeakness': 'Park erişimi',
  'isFavorite': true,
};

const _propertyDetailJson = <String, Object?>{
  'id': '42',
  'externalRef': 'SYN-42',
  'monthlyRent': 20000,
  'areaM2': 95,
  'roomCount': '3+1',
  'latitude': 39.9,
  'longitude': 32.8,
  'address': _propertyAddressJson,
  'features': {
    'floorNo': 3,
    'totalFloors': 8,
    'buildingAge': 6,
    'hasElevator': true,
    'hasParking': true,
    'isFurnished': false,
    'petsAllowed': true,
    'rentPerM2': 210.5,
    'deposit': 20000,
  },
  'score': {
    'total': 82.5,
    'band': 'good',
    'rows': [_scoreRowJson],
    'strengths': [_scoreRowJson],
    'weaknesses': <Object>[],
    'budget': {
      'monthlyRent': 20000,
      'minMonthlyBudget': 15000,
      'maxMonthlyBudget': 25000,
      'ratioToMax': 0.8,
      'status': 'fits',
      'message': 'Bütçe aralığında.',
    },
    'weakLink': {
      'categoryCode': 'park',
      'label': 'Park',
      'points': -2.5,
      'weightedAverage': 85,
      'message': 'Park erişimi toplamı sınırladı.',
    },
  },
  'isFavorite': true,
  'isSynthetic': true,
};

const _scoreRowJson = <String, Object?>{
  'categoryCode': 'market',
  'label': 'Market',
  'durationMin': 5,
  'targetMin': 8,
  'cutoffMin': 20,
  'subScore': 92,
  'weight': 0.4,
  'contribution': 36.8,
  'status': 'strong',
  'poiCountInRadius': 4,
  'densityFactor': 1.05,
};

const _routeDetailJson = <String, Object?>{
  'id': 'route-1',
  'name': 'Test rotası',
  'mode': 'foot',
  'totalDistanceM': 4200,
  'totalDurationS': 3600,
  'createdAt': '2026-08-26T09:00:00Z',
  'stopCount': 2,
  'start': {'lat': 39.9, 'lon': 32.8, 'label': 'Ev'},
  'geometry': {
    'type': 'LineString',
    'coordinates': [
      [32.8, 39.9],
      [32.82, 39.91],
    ],
  },
  'stops': [
    {
      'seq': 1,
      'propertyId': 42,
      'score': null,
      'legDistanceM': null,
      'legDurationS': null,
      'visitedAt': null,
      'property': {
        'monthlyRent': 20000,
        'areaM2': 95,
        'roomCount': '3+1',
        'neighborhood': 'Ayrancı',
        'lat': 39.91,
        'lon': 32.82,
      },
    },
    {
      'seq': 2,
      'propertyId': 43,
      'score': 78,
      'legDistanceM': 1800,
      'legDurationS': 1300,
      'visitedAt': null,
      'property': {
        'monthlyRent': 18000,
        'areaM2': 80,
        'roomCount': '2+1',
        'neighborhood': 'Kavaklıdere',
        'lat': 39.92,
        'lon': 32.84,
      },
    },
  ],
  'legs': <Object>[],
};

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
