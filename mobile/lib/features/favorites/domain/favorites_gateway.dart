import 'favorite_models.dart';

abstract interface class FavoritesGateway {
  Future<FavoritesLoadResult> getFavorites();

  Future<void> addFavorite(String propertyId);

  Future<void> removeFavorite(String propertyId);
}

class FavoritesLoadResult {
  const FavoritesLoadResult({required this.items, this.fromCache = false});

  final List<FavoriteEntry> items;
  final bool fromCache;
}

class FavoritesFailure implements Exception {
  const FavoritesFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
