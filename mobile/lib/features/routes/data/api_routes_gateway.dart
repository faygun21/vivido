import '../../../core/network/api_client.dart';
import '../domain/route_models.dart';
import '../domain/routes_gateway.dart';

class ApiRoutesGateway implements RoutesGateway {
  const ApiRoutesGateway(this._client);

  final ApiClient _client;

  @override
  Future<List<RouteSummary>> getRoutes() async {
    try {
      final json = await _client.get('/routes');
      return (json as List<dynamic>)
          .map((item) => RouteSummary.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on ApiException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<RouteDetail> getRoute(String id) async {
    try {
      final json = await _client.get('/routes/$id') as Map<String, dynamic>;
      return RouteDetail.fromJson(json);
    } on ApiException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<RouteDetail> previewRoute({
    required RouteStart start,
    required List<int> propertyIds,
    required RouteTravelMode mode,
  }) async {
    try {
      // `name` GÖNDERİLMİYOR: sunucu tarafında ad yalnızca kaydederken
      // zorunlu (RoutesController.PreviewRoute). İsim sormadan önizleme
      // yapabilmemizin sebebi bu.
      final json =
          await _client.post('/routes/preview', {
                'start': start.toJson(),
                'propertyIds': propertyIds,
                'mode': mode.apiValue,
              })
              as Map<String, dynamic>;
      return RouteDetail.fromJson(json);
    } on ApiException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<RouteDetail> createRoute({
    required String name,
    required RouteStart start,
    required List<int> propertyIds,
    required RouteTravelMode mode,
  }) async {
    try {
      final json =
          await _client.post('/routes', {
                'name': name.trim(),
                'start': start.toJson(),
                'propertyIds': propertyIds,
                'mode': mode.apiValue,
              })
              as Map<String, dynamic>;
      return RouteDetail.fromJson(json);
    } on ApiException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> deleteRoute(String id) async {
    try {
      await _client.delete('/routes/$id');
    } on ApiException catch (error) {
      throw _failure(error);
    }
  }

  RoutesFailure _failure(ApiException error) =>
      RoutesFailure(_routeMessage(error), code: error.code);

  String _routeMessage(ApiException error) => switch (error.code) {
    'OSRM_UNAVAILABLE' =>
      'Rota servisine şu anda ulaşılamıyor. Birazdan tekrar dene.',
    'ROUTE_STOP_LIMIT_EXCEEDED' =>
      'Rota için 2 ile 8 arasında konut seçmelisin.',
    'ROUTE_VALIDATION_ERROR' ||
    'VALIDATION_ERROR' => error.detail ?? 'Rota bilgilerini kontrol et.',
    _ => error.detail ?? error.title,
  };
}
