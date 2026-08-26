import 'route_models.dart';

abstract interface class RoutesGateway {
  Future<List<RouteSummary>> getRoutes();

  Future<RouteDetail> getRoute(String id);

  Future<RouteDetail> createRoute({
    required String name,
    required RouteStart start,
    required List<int> propertyIds,
    required RouteTravelMode mode,
  });

  Future<void> deleteRoute(String id);
}

class RoutesFailure implements Exception {
  const RoutesFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
