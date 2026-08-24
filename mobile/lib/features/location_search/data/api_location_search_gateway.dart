import '../../../core/network/api_client.dart';
import '../domain/location_search_models.dart';

abstract interface class LocationSearchGateway {
  Future<LocationSearchResponse> search(String query, {int limit = 5});
}

class ApiLocationSearchGateway implements LocationSearchGateway {
  const ApiLocationSearchGateway(this._client);

  final ApiClient _client;

  @override
  Future<LocationSearchResponse> search(String query, {int limit = 5}) async {
    assert(limit >= 1 && limit <= 10);
    final encodedQuery = Uri.encodeQueryComponent(query.trim());
    final json = await _client.get(
      '/locations/search?q=$encodedQuery&limit=$limit',
    );
    return LocationSearchResponse.fromJson(json as Map<String, dynamic>);
  }
}
