import 'favorite_models.dart';

abstract interface class FavoriteCache {
  Future<List<FavoriteEntry>> read(String userId);

  Future<void> write(String userId, List<FavoriteEntry> favorites);

  Future<void> clear(String userId);
}
