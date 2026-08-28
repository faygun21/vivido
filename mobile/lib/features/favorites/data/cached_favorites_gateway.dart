import '../domain/favorite_cache.dart';
import '../domain/favorites_gateway.dart';

class CachedFavoritesGateway implements FavoritesGateway {
  const CachedFavoritesGateway({
    required FavoritesGateway remote,
    required FavoriteCache cache,
    required String userId,
  }) : _remote = remote,
       _cache = cache,
       _userId = userId;

  final FavoritesGateway _remote;
  final FavoriteCache _cache;
  final String _userId;

  @override
  Future<FavoritesLoadResult> getFavorites() async {
    try {
      final result = await _remote.getFavorites();
      try {
        await _cache.write(_userId, result.items);
      } on Object {
        // Güncel sunucu verisi, önbellek yazma hatası yüzünden kaybedilmez.
      }
      return result;
    } on Object {
      final cached = await _cache.read(_userId);
      return FavoritesLoadResult(items: cached, fromCache: true);
    }
  }

  @override
  Future<void> addFavorite(String propertyId) =>
      _remote.addFavorite(propertyId);

  @override
  Future<void> removeFavorite(String propertyId) async {
    await _remote.removeFavorite(propertyId);
    final cached = await _cache.read(_userId);
    await _cache.write(
      _userId,
      cached
          .where((item) => item.propertyId != propertyId)
          .toList(growable: false),
    );
  }
}
