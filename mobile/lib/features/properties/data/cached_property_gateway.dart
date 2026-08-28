import '../domain/property_gateway.dart';
import '../domain/property_list_cache.dart';
import '../domain/property_models.dart';

class CachedPropertyGateway implements PropertyGateway {
  const CachedPropertyGateway({
    required PropertyGateway remote,
    required PropertyListCache cache,
    required String userId,
  }) : _remote = remote,
       _cache = cache,
       _userId = userId;

  final PropertyGateway _remote;
  final PropertyListCache _cache;
  final String _userId;

  @override
  Future<TopProperties> getTopProperties({
    int limit = 20,
    bool showAll = false,
  }) async {
    try {
      final result = await _remote.getTopProperties(
        limit: limit,
        showAll: showAll,
      );
      try {
        await _cache.write(_userId, result, showAll: showAll);
      } on Object {
        // Güncel sunucu verisi, önbellek yazma hatası yüzünden kaybedilmez.
      }
      return result;
    } on Object {
      return _cache.read(_userId, showAll: showAll);
    }
  }

  @override
  Future<PropertyDetail> getPropertyDetail(String id) =>
      _remote.getPropertyDetail(id);
}
