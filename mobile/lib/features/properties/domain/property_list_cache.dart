import 'property_gateway.dart';

abstract interface class PropertyListCache {
  Future<TopProperties> read(String userId, {required bool showAll});

  Future<void> write(
    String userId,
    TopProperties properties, {
    required bool showAll,
  });
}
