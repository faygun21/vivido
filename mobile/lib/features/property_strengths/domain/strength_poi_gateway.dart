import '../../map_data/domain/map_data_models.dart';
import '../../properties/domain/property_models.dart';

abstract interface class StrengthPoiGateway {
  Future<List<PoiMapItem>> getHighlightedPois({
    required double propertyLatitude,
    required double propertyLongitude,
    required List<PropertyScoreRow> strengths,
  });
}

class StrengthPoiFailure implements Exception {
  const StrengthPoiFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
