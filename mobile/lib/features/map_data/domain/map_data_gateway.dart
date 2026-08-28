import 'map_data_models.dart';

abstract interface class MapDataGateway {
  Future<List<PoiCategory>> getPoiCategories();

  Future<List<PoiMapItem>> getPois({
    required MapViewportBounds bounds,
    required Set<String> categories,
  });

  Future<AuthenticatedPropertiesMap> getAuthenticatedProperties({
    bool showAll = false,
  });

  Future<List<PropertyMapItem>> getPublicProperties(MapViewportBounds bounds);
}

class MapDataFailure implements Exception {
  const MapDataFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
