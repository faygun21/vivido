import '../domain/route_list_cache.dart';
import '../domain/route_models.dart';
import '../domain/routes_gateway.dart';

class CachedRoutesGateway implements RoutesGateway {
  const CachedRoutesGateway({
    required RoutesGateway remote,
    required RouteListCache cache,
    required String userId,
  }) : _remote = remote,
       _cache = cache,
       _userId = userId;

  final RoutesGateway _remote;
  final RouteListCache _cache;
  final String _userId;

  @override
  Future<List<RouteSummary>> getRoutes() async {
    try {
      final routes = await _remote.getRoutes();
      try {
        await _cache.write(_userId, routes);
      } on Object {
        // Güncel sunucu verisi, önbellek yazma hatası yüzünden kaybedilmez.
      }
      await Future.wait(routes.map(_cacheDetailBestEffort));
      return routes;
    } on Object {
      return _cache.read(_userId);
    }
  }

  @override
  Future<RouteDetail> getRoute(String id) async {
    try {
      final route = await _remote.getRoute(id);
      try {
        await _cache.writeDetail(_userId, route);
      } on Object {
        // Sunucudan gelen detay, önbellek hatası yüzünden kaybedilmez.
      }
      return route;
    } on Object {
      final cached = await _cache.readDetail(_userId, id);
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<RouteDetail> previewRoute({
    required RouteStart start,
    required List<int> propertyIds,
    required RouteTravelMode mode,
  }) =>
      _remote.previewRoute(start: start, propertyIds: propertyIds, mode: mode);

  @override
  Future<RouteDetail> createRoute({
    required String name,
    required RouteStart start,
    required List<int> propertyIds,
    required RouteTravelMode mode,
  }) async {
    final route = await _remote.createRoute(
      name: name,
      start: start,
      propertyIds: propertyIds,
      mode: mode,
    );
    try {
      await _cache.writeDetail(_userId, route);
    } on Object {
      // Rota sunucuda kaydedildi; önbellek hatası işlemi başarısız yapmaz.
    }
    await _refreshCacheBestEffort();
    return route;
  }

  @override
  Future<void> deleteRoute(String id) async {
    await _remote.deleteRoute(id);
    await _cache.deleteDetail(_userId, id);
    final cached = await _cache.read(_userId);
    await _cache.write(
      _userId,
      cached.where((route) => route.id != id).toList(growable: false),
    );
  }

  Future<void> _refreshCacheBestEffort() async {
    try {
      await _cache.write(_userId, await _remote.getRoutes());
    } on Object {
      // Rota sunucuda oluştu; yalnız önbellek yenilenemedi.
    }
  }

  Future<void> _cacheDetailBestEffort(RouteSummary summary) async {
    try {
      final route = await _remote.getRoute(summary.id);
      await _cache.writeDetail(_userId, route);
    } on Object {
      // Tek bir rota detayı indirilemese bile rota listesi kullanılabilir kalır.
    }
  }
}
