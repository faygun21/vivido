import '../../../core/network/api_client.dart';
import '../domain/map_data_gateway.dart';
import '../domain/map_data_models.dart';

class ApiMapDataGateway implements MapDataGateway {
  const ApiMapDataGateway(this._client);

  final ApiClient _client;

  @override
  Future<List<PoiCategory>> getPoiCategories() =>
      _getList('/pois/categories', PoiCategory.fromJson);

  @override
  Future<List<PoiMapItem>> getPois({
    required MapViewportBounds bounds,
    required Set<String> categories,
  }) {
    final sortedCategories = categories.toList()..sort();
    return _getList(
      _path('/pois', {
        ..._boundsQuery(bounds),
        'categories': sortedCategories.join(','),
      }),
      PoiMapItem.fromJson,
    );
  }

  @override
  Future<AuthenticatedPropertiesMap> getAuthenticatedProperties({
    bool showAll = false,
  }) async {
    try {
      final response = await _client.get('/properties?showAll=$showAll');
      if (response is! Map<String, dynamic>) {
        throw const MapDataFailure(
          'Konut harita verisi beklenen biçimde değil.',
        );
      }
      return AuthenticatedPropertiesMap.fromJson(response);
    } on ApiException catch (error) {
      throw MapDataFailure(error.detail ?? error.title);
    } on MapDataFailure {
      rethrow;
    } on Object {
      throw const MapDataFailure('Konut harita verisi okunamadı.');
    }
  }

  @override
  Future<List<PropertyMapItem>> getPublicProperties(MapViewportBounds bounds) =>
      _getList(
        _path('/properties/map', _boundsQuery(bounds)),
        PropertyMapItem.fromJson,
      );

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final response = await _client.get(path);
      if (response is! List<dynamic>) {
        throw const MapDataFailure('Harita verisi beklenen biçimde değil.');
      }
      return response
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on ApiException catch (error) {
      throw MapDataFailure(error.detail ?? error.title);
    } on MapDataFailure {
      rethrow;
    } on Object {
      throw const MapDataFailure('Harita verisi okunamadı.');
    }
  }
}

Map<String, String> _boundsQuery(MapViewportBounds bounds) => {
  'west': bounds.west.toStringAsFixed(6),
  'south': bounds.south.toStringAsFixed(6),
  'east': bounds.east.toStringAsFixed(6),
  'north': bounds.north.toStringAsFixed(6),
};

String _path(String path, Map<String, Object> query) =>
    Uri(path: path, queryParameters: query).toString();
