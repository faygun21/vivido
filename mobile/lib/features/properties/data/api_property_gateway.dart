import '../../../core/network/api_client.dart';
import '../domain/property_gateway.dart';
import '../domain/property_models.dart';

class ApiPropertyGateway implements PropertyGateway {
  const ApiPropertyGateway(this._client);

  final ApiClient _client;

  @override
  Future<List<PropertySummary>> getTopProperties({int limit = 20}) async {
    try {
      final json = await _client.get('/properties/top?limit=$limit');
      return (json as List<dynamic>)
          .map((item) => PropertySummary.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on ApiException catch (error) {
      throw PropertyDataFailure(error.detail ?? error.title);
    }
  }

  @override
  Future<PropertyDetail> getPropertyDetail(String id) async {
    try {
      final json = await _client.get('/properties/$id') as Map<String, dynamic>;
      return PropertyDetail.fromJson(json);
    } on ApiException catch (error) {
      throw PropertyDataFailure(error.detail ?? error.title);
    }
  }
}
