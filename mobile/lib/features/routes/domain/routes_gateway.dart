import 'route_models.dart';

abstract interface class RoutesGateway {
  Future<List<RouteSummary>> getRoutes();

  Future<RouteDetail> getRoute(String id);

  /// Rotayı hesaplar ama KAYDETMEZ.
  ///
  /// Eskiden tek bir "oluştur" adımı vardı ve rota, kullanıcı daha görmeden
  /// kayıtlı rotalara ekleniyordu. Beğenmediğinde silmek zorunda kalıyordu.
  /// Artık önce önizleniyor, kaydetmek ayrı ve isteğe bağlı bir adım.
  ///
  /// Ad gerekmiyor: isim yalnızca kaydederken sorulur.
  Future<RouteDetail> previewRoute({
    required RouteStart start,
    required List<int> propertyIds,
    required RouteTravelMode mode,
  });

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
