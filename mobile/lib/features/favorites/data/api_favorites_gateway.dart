import '../../../core/network/api_client.dart';
import '../domain/favorite_models.dart';
import '../domain/favorites_gateway.dart';

class ApiFavoritesGateway implements FavoritesGateway {
  const ApiFavoritesGateway(this._client);

  final ApiClient _client;

  @override
  Future<FavoritesLoadResult> getFavorites() async {
    try {
      final json = await _client.get('/profile/favorites');
      return FavoritesLoadResult(
        items: (json as List<dynamic>)
            .map((item) => FavoriteEntry.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );
    } on ApiException catch (error) {
      throw FavoritesFailure(error.detail ?? error.title);
    }
  }

  @override
  Future<void> addFavorite(String propertyId) async {
    final numericId = int.tryParse(propertyId);
    if (numericId == null) {
      throw const FavoritesFailure('Geçersiz konut kimliği.');
    }
    try {
      await _client.post('/profile/favorites', {'propertyId': numericId});
    } on ApiException catch (error) {
      throw FavoritesFailure(error.detail ?? error.title);
    }
  }

  @override
  Future<void> removeFavorite(String propertyId) async {
    try {
      await _client.delete('/profile/favorites/$propertyId');
    } on ApiException catch (error) {
      throw FavoritesFailure(error.detail ?? error.title);
    }
  }
}
