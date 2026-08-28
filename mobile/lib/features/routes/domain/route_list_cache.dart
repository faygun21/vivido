import 'route_models.dart';

abstract interface class RouteListCache {
  Future<List<RouteSummary>> read(String userId);

  Future<void> write(String userId, List<RouteSummary> routes);

  Future<RouteDetail?> readDetail(String userId, String routeId);

  Future<void> writeDetail(String userId, RouteDetail route);

  Future<void> deleteDetail(String userId, String routeId);
}
