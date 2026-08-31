import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivido_mobile/core/models/models.dart';
import 'package:vivido_mobile/core/network/api_client.dart';
import 'package:vivido_mobile/core/network/network_status_controller.dart';
import 'package:vivido_mobile/core/storage/token_store.dart';
import 'package:vivido_mobile/features/auth/application/session_controller.dart';
import 'package:vivido_mobile/features/auth/data/secure_offline_credential_store.dart';
import 'package:vivido_mobile/features/auth/domain/offline_credential_store.dart';
import 'package:vivido_mobile/features/favorites/application/favorites_controller.dart';
import 'package:vivido_mobile/features/favorites/data/cached_favorites_gateway.dart';
import 'package:vivido_mobile/features/favorites/domain/favorite_cache.dart';
import 'package:vivido_mobile/features/favorites/domain/favorite_models.dart';
import 'package:vivido_mobile/features/favorites/domain/favorites_gateway.dart';
import 'package:vivido_mobile/features/properties/domain/property_models.dart';
import 'package:vivido_mobile/features/properties/data/cached_property_gateway.dart';
import 'package:vivido_mobile/features/properties/domain/property_gateway.dart';
import 'package:vivido_mobile/features/properties/domain/property_list_cache.dart';
import 'package:vivido_mobile/features/routes/data/cached_routes_gateway.dart';
import 'package:vivido_mobile/features/routes/domain/route_list_cache.dart';
import 'package:vivido_mobile/features/routes/domain/route_models.dart';
import 'package:vivido_mobile/features/routes/domain/routes_gateway.dart';

void main() {
  group('R-78 çevrimdışı favoriler', () {
    test('çevrimiçi favorileri kullanıcıya özel cache içine yazar', () async {
      final cache = _MemoryFavoriteCache();
      final remote = _FakeFavoritesGateway(items: [_favorite]);
      final gateway = CachedFavoritesGateway(
        remote: remote,
        cache: cache,
        userId: 'user-1',
      );

      final result = await gateway.getFavorites();

      expect(result.fromCache, isFalse);
      expect((await cache.read('user-1')).single.property?.id, '42');
      expect(await cache.read('user-2'), isEmpty);
    });

    test('sunucu yokken cihazdaki temel favori bilgisini gösterir', () async {
      final cache = _MemoryFavoriteCache()..values['user-1'] = [_favorite];
      final gateway = CachedFavoritesGateway(
        remote: _FakeFavoritesGateway(failReads: true),
        cache: cache,
        userId: 'user-1',
      );
      final controller = FavoritesController(gateway);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.showingCachedData, isTrue);
      expect(controller.items.single.property?.address.formatted, 'Ayrancı');
      expect(controller.errorMessage, isNull);
    });

    test('bağlantı kaybı ve geri gelişi ortak duruma yansır', () async {
      final monitor = _FakeConnectivityMonitor();
      final controller = NetworkStatusController(monitor);
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.isOffline, isFalse);

      monitor.controller.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.isOffline, isTrue);

      monitor.controller.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.isOffline, isFalse);
    });

    test('soğuk başlangıçta internet yoksa kayıtlı oturumu silmez', () async {
      final tokenStore = MemoryTokenStore(_session);
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: tokenStore,
        httpClient: MockClient((_) async => throw http.ClientException('yok')),
      );
      final controller = SessionController(
        client: client,
        repository: VividoRepository(client),
      );
      addTearDown(controller.dispose);

      await controller.bootstrap();

      expect(controller.phase, SessionPhase.authenticated);
      expect(controller.isAuthenticated, isTrue);
      expect(tokenStore.session, isNotNull);
      expect(controller.errorMessage, contains('Çevrimdışı'));
    });

    test(
      'sunucu yokken daha önce etkinleştirilen hesapla giriş yapar',
      () async {
        final tokenStore = MemoryTokenStore();
        final client = ApiClient(
          baseUrl: 'http://localhost/api/v1',
          tokenStore: tokenStore,
          httpClient: MockClient(
            (_) async => throw http.ClientException('yok'),
          ),
        );
        final controller = SessionController(
          client: client,
          repository: VividoRepository(client),
          offlineCredentials: _MemoryOfflineCredentialStore(
            email: 'offline@vivido.test',
            password: 'Guvenli123!',
            session: _session,
          ),
        );
        addTearDown(controller.dispose);

        final success = await controller.login(
          email: 'OFFLINE@VIVIDO.TEST',
          password: 'Guvenli123!',
        );

        expect(success, isTrue);
        expect(controller.phase, SessionPhase.authenticated);
        expect(controller.user?.id, 'user-1');
        expect(tokenStore.session?.user.id, 'user-1');
        expect(controller.errorMessage, contains('Çevrimdışı giriş'));
      },
    );

    test('çevrimdışı girişte yanlış parolayı kabul etmez', () async {
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: MemoryTokenStore(),
        httpClient: MockClient((_) async => throw http.ClientException('yok')),
      );
      final controller = SessionController(
        client: client,
        repository: VividoRepository(client),
        offlineCredentials: _MemoryOfflineCredentialStore(
          email: 'offline@vivido.test',
          password: 'Guvenli123!',
          session: _session,
        ),
      );
      addTearDown(controller.dispose);

      final success = await controller.login(
        email: 'offline@vivido.test',
        password: 'yanlis',
      );

      expect(success, isFalse);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.errorMessage, contains('hatalı'));
    });

    test(
      'Android istemcisinden gelen bilinmeyen ağ hatasında yerel girişi dener',
      () async {
        final client = ApiClient(
          baseUrl: 'http://localhost/api/v1',
          tokenStore: MemoryTokenStore(),
          httpClient: MockClient((_) async => throw StateError('ağ kapalı')),
        );
        final controller = SessionController(
          client: client,
          repository: VividoRepository(client),
          offlineCredentials: _MemoryOfflineCredentialStore(
            email: 'offline@vivido.test',
            password: 'Guvenli123!',
            session: _session,
          ),
        );
        addTearDown(controller.dispose);

        final success = await controller.login(
          email: 'offline@vivido.test',
          password: 'Guvenli123!',
        );

        expect(success, isTrue);
        expect(controller.phase, SessionPhase.authenticated);
      },
    );

    test('güvenli depo doğru parolayı doğrular ve yanlışı reddeder', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SecureOfflineCredentialStore();

      await store.enroll(
        email: 'offline@vivido.test',
        password: 'Guvenli123!',
        session: _session,
      );

      expect(await store.hasEnrollment('OFFLINE@VIVIDO.TEST'), isTrue);
      expect(
        (await store.unlock(
          email: 'offline@vivido.test',
          password: 'Guvenli123!',
        ))?.user.id,
        'user-1',
      );
      expect(
        await store.unlock(email: 'offline@vivido.test', password: 'yanlis'),
        isNull,
      );
    });

    test('sunucu yokken cihazdaki konut listesini gösterir', () async {
      final cache =
          _MemoryPropertyListCache()
            ..value = TopProperties(items: [_favorite.property!]);
      final gateway = CachedPropertyGateway(
        remote: _FakePropertyGateway(failReads: true),
        cache: cache,
        userId: 'user-1',
      );

      final result = await gateway.getTopProperties();

      expect(result.items.single.id, '42');
    });

    test('sunucu yokken cihazdaki kayıtlı rota özetlerini gösterir', () async {
      final cache = _MemoryRouteListCache()..values['user-1'] = [_route];
      final gateway = CachedRoutesGateway(
        remote: _FakeRoutesGateway(failReads: true),
        cache: cache,
        userId: 'user-1',
      );

      final routes = await gateway.getRoutes();

      expect(routes.single.name, 'Ev turu');
      expect(routes.single.stopCount, 2);
    });

    test('sunucu yokken önbellekteki kayıtlı rota detayını açar', () async {
      final cache =
          _MemoryRouteListCache()..details['user-1:route-1'] = _routeDetail;
      final gateway = CachedRoutesGateway(
        remote: _FakeRoutesGateway(failReads: true),
        cache: cache,
        userId: 'user-1',
      );

      final route = await gateway.getRoute('route-1');

      expect(route.name, 'Ev turu');
      expect(route.stops.single.propertyId, 42);
      expect(route.geometry, isNotEmpty);
    });

    test(
      'rota listesi yüklenince detayları çevrimdışı kullanım için saklar',
      () async {
        final cache = _MemoryRouteListCache();
        final gateway = CachedRoutesGateway(
          remote: _FakeRoutesGateway(),
          cache: cache,
          userId: 'user-1',
        );

        await gateway.getRoutes();

        expect(cache.details['user-1:route-1']?.name, 'Ev turu');
      },
    );
  });
}

const _session = AuthSession(
  user: AuthUser(id: 'user-1', email: 'offline@vivido.test'),
  accessToken: 'access',
  refreshToken: 'refresh',
  expiresIn: 900,
);

final _favorite = FavoriteEntry(
  propertyId: '42',
  createdAt: DateTime.utc(2026, 8, 28),
  property: const PropertySummary(
    id: '42',
    externalRef: 'SYN-42',
    monthlyRent: 18000,
    areaM2: 90,
    roomCount: '2+1',
    latitude: 39.9,
    longitude: 32.8,
    totalScore: 87,
    band: 'good',
    address: PropertyAddress(
      districtName: 'Çankaya',
      cityName: 'Ankara',
      formatted: 'Ayrancı',
    ),
    isFavorite: true,
  ),
);

final _route = RouteSummary(
  id: 'route-1',
  name: 'Ev turu',
  mode: RouteTravelMode.car,
  totalDistanceM: 4200,
  totalDurationS: 900,
  createdAt: DateTime.utc(2026, 8, 28),
  stopCount: 2,
);

final _routeDetail = RouteDetail.fromJson({
  'id': 'route-1',
  'name': 'Ev turu',
  'start': {'lat': 39.9, 'lon': 32.8, 'label': 'Başlangıç'},
  'mode': 'car',
  'totalDistanceM': 4200,
  'totalDurationS': 900,
  'stopCount': 1,
  'geometry': {
    'type': 'LineString',
    'coordinates': [
      [32.8, 39.9],
      [32.81, 39.91],
    ],
  },
  'stops': [
    {
      'seq': 1,
      'propertyId': 42,
      'property': {
        'monthlyRent': 18000,
        'areaM2': 90,
        'roomCount': '2+1',
        'neighborhood': 'Ayrancı',
        'lat': 39.91,
        'lon': 32.81,
      },
    },
  ],
  'legs': const [],
  'createdAt': '2026-08-28T00:00:00Z',
  'isSaved': true,
});

class _MemoryFavoriteCache implements FavoriteCache {
  final Map<String, List<FavoriteEntry>> values = {};

  @override
  Future<void> clear(String userId) async => values.remove(userId);

  @override
  Future<List<FavoriteEntry>> read(String userId) async =>
      values[userId] ?? const [];

  @override
  Future<void> write(String userId, List<FavoriteEntry> favorites) async {
    values[userId] = favorites;
  }
}

class _FakeFavoritesGateway implements FavoritesGateway {
  _FakeFavoritesGateway({this.items = const [], this.failReads = false});

  final List<FavoriteEntry> items;
  final bool failReads;

  @override
  Future<void> addFavorite(String propertyId) async {}

  @override
  Future<FavoritesLoadResult> getFavorites() async {
    if (failReads) throw const FavoritesFailure('Bağlantı yok.');
    return FavoritesLoadResult(items: items);
  }

  @override
  Future<void> removeFavorite(String propertyId) async {}
}

class _FakeConnectivityMonitor implements ConnectivityMonitor {
  final StreamController<List<ConnectivityResult>> controller =
      StreamController.broadcast();

  @override
  Future<List<ConnectivityResult>> check() async => [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get changes => controller.stream;
}

class _MemoryPropertyListCache implements PropertyListCache {
  TopProperties value = const TopProperties.empty();

  @override
  Future<TopProperties> read(String userId, {required bool showAll}) async =>
      value;

  @override
  Future<void> write(
    String userId,
    TopProperties properties, {
    required bool showAll,
  }) async {
    value = properties;
  }
}

class _FakePropertyGateway implements PropertyGateway {
  _FakePropertyGateway({this.failReads = false});

  final bool failReads;

  @override
  Future<PropertyDetail> getPropertyDetail(String id) =>
      throw UnimplementedError();

  @override
  Future<TopProperties> getTopProperties({
    int limit = 20,
    bool showAll = false,
  }) async {
    if (failReads) throw const PropertyDataFailure('Bağlantı yok.');
    return TopProperties(items: [_favorite.property!]);
  }
}

class _MemoryRouteListCache implements RouteListCache {
  final Map<String, List<RouteSummary>> values = {};
  final Map<String, RouteDetail> details = {};

  @override
  Future<List<RouteSummary>> read(String userId) async =>
      values[userId] ?? const [];

  @override
  Future<void> write(String userId, List<RouteSummary> routes) async {
    values[userId] = routes;
  }

  @override
  Future<RouteDetail?> readDetail(String userId, String routeId) async =>
      details['$userId:$routeId'];

  @override
  Future<void> writeDetail(String userId, RouteDetail route) async {
    details['$userId:${route.id}'] = route;
  }

  @override
  Future<void> deleteDetail(String userId, String routeId) async {
    details.remove('$userId:$routeId');
  }
}

class _FakeRoutesGateway implements RoutesGateway {
  _FakeRoutesGateway({this.failReads = false});

  final bool failReads;

  @override
  Future<List<RouteSummary>> getRoutes() async {
    if (failReads) throw const RoutesFailure('Bağlantı yok.');
    return [_route];
  }

  @override
  Future<RouteDetail> getRoute(String id) async {
    if (failReads) throw const RoutesFailure('Bağlantı yok.');
    return _routeDetail;
  }

  @override
  Future<RouteDetail> createRoute({
    required String name,
    required RouteStart start,
    required List<int> propertyIds,
    required RouteTravelMode mode,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteRoute(String id) => throw UnimplementedError();

  @override
  Future<RouteDetail> previewRoute({
    required RouteStart start,
    required List<int> propertyIds,
    required RouteTravelMode mode,
  }) => throw UnimplementedError();
}

class _MemoryOfflineCredentialStore implements OfflineCredentialStore {
  _MemoryOfflineCredentialStore({
    required this.email,
    required this.password,
    required this.session,
  });

  String email;
  String password;
  AuthSession session;

  @override
  Future<void> enroll({
    required String email,
    required String password,
    required AuthSession session,
  }) async {
    this.email = email.toLowerCase();
    this.password = password;
    this.session = session;
  }

  @override
  Future<bool> hasEnrollment(String email) async =>
      this.email == email.trim().toLowerCase();

  @override
  Future<AuthSession?> unlock({
    required String email,
    required String password,
  }) async =>
      this.email == email.trim().toLowerCase() && this.password == password
          ? session
          : null;
}
