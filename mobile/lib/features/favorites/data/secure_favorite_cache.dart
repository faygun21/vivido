import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/favorite_cache.dart';
import '../domain/favorite_models.dart';

class SecureFavoriteCache implements FavoriteCache {
  SecureFavoriteCache({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'vivido.favorites.cache.v1';
  final FlutterSecureStorage _storage;

  String _key(String userId) => '$_prefix.$userId';

  @override
  Future<List<FavoriteEntry>> read(String userId) async {
    final raw = await _storage.read(key: _key(userId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final json = jsonDecode(raw) as List<dynamic>;
      return json
          .map((item) => FavoriteEntry.fromJson(item as Map<String, dynamic>))
          .where((item) => item.property != null)
          .toList(growable: false);
    } on Object {
      await clear(userId);
      return const [];
    }
  }

  @override
  Future<void> write(String userId, List<FavoriteEntry> favorites) =>
      _storage.write(
        key: _key(userId),
        value: jsonEncode(favorites.map((item) => item.toJson()).toList()),
      );

  @override
  Future<void> clear(String userId) => _storage.delete(key: _key(userId));
}
