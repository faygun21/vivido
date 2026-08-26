import 'favorite_models.dart';

abstract interface class FavoritesGateway {
  Future<List<FavoriteEntry>> getFavorites();

  Future<void> addFavorite(String propertyId);

  Future<void> removeFavorite(String propertyId);
}

class FavoritesFailure implements Exception {
  const FavoritesFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
