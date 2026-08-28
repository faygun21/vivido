import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/property_gateway.dart';
import '../domain/property_list_cache.dart';
import '../domain/property_models.dart';

class SecurePropertyListCache implements PropertyListCache {
  SecurePropertyListCache({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'vivido.properties.cache.v1';
  final FlutterSecureStorage _storage;

  String _key(String userId, bool showAll) =>
      '$_prefix.$userId.${showAll ? 'all' : 'corridor'}';

  @override
  Future<TopProperties> read(String userId, {required bool showAll}) async {
    final key = _key(userId, showAll);
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return const TopProperties.empty();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final fallback = json['nearestFallback'] as Map<String, dynamic>?;
      return TopProperties(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map(
              (item) => PropertySummary.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        nearestFallback:
            fallback == null ? null : PropertySummary.fromJson(fallback),
      );
    } on Object {
      await _storage.delete(key: key);
      return const TopProperties.empty();
    }
  }

  @override
  Future<void> write(
    String userId,
    TopProperties properties, {
    required bool showAll,
  }) => _storage.write(
    key: _key(userId, showAll),
    value: jsonEncode({
      'items': properties.items.map((item) => item.toJson()).toList(),
      'nearestFallback': properties.nearestFallback?.toJson(),
    }),
  );
}
