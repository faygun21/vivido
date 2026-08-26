import 'property_models.dart';

abstract interface class PropertyGateway {
  Future<List<PropertySummary>> getTopProperties({int limit = 20});

  Future<PropertyDetail> getPropertyDetail(String id);
}

class PropertyDataFailure implements Exception {
  const PropertyDataFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
