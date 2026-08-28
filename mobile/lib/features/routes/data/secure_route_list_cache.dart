import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/route_list_cache.dart';
import '../domain/route_models.dart';

class SecureRouteListCache implements RouteListCache {
  SecureRouteListCache({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _prefix = 'vivido.routes.cache.v1';
  static const _detailPrefix = 'vivido.routes.detail.cache.v1';
  final FlutterSecureStorage _storage;

  String _key(String userId) => '$_prefix.$userId';
  String _detailKey(String userId, String routeId) =>
      '$_detailPrefix.$userId.$routeId';

  @override
  Future<List<RouteSummary>> read(String userId) async {
    final key = _key(userId);
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => RouteSummary.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on Object {
      await _storage.delete(key: key);
      return const [];
    }
  }

  @override
  Future<void> write(String userId, List<RouteSummary> routes) =>
      _storage.write(
        key: _key(userId),
        value: jsonEncode(routes.map((item) => item.toJson()).toList()),
      );

  @override
  Future<RouteDetail?> readDetail(String userId, String routeId) async {
    final key = _detailKey(userId, routeId);
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return RouteDetail.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      await _storage.delete(key: key);
      return null;
    }
  }

  @override
  Future<void> writeDetail(String userId, RouteDetail route) => _storage.write(
    key: _detailKey(userId, route.id),
    value: jsonEncode(route.toJson()),
  );

  @override
  Future<void> deleteDetail(String userId, String routeId) =>
      _storage.delete(key: _detailKey(userId, routeId));
}
