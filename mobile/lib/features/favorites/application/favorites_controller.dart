import 'package:flutter/foundation.dart';

import '../domain/favorite_models.dart';
import '../domain/favorites_gateway.dart';

class FavoritesController extends ChangeNotifier {
  FavoritesController(this._gateway);

  final FavoritesGateway _gateway;

  List<FavoriteEntry> items = const [];
  Set<String> busyPropertyIds = const {};
  bool loading = false;
  String? errorMessage;

  bool _loaded = false;
  bool _disposed = false;
  int _dataVersion = 0;

  bool contains(String propertyId) =>
      items.any((item) => item.propertyId == propertyId);

  Future<void> load({bool force = false}) async {
    if (!force && _loaded) return;
    final requestVersion = ++_dataVersion;
    loading = true;
    errorMessage = null;
    _notify();
    try {
      final loadedItems = await _gateway.getFavorites();
      if (requestVersion != _dataVersion) return;
      items = loadedItems;
      _loaded = true;
    } on FavoritesFailure catch (error) {
      if (requestVersion != _dataVersion) return;
      errorMessage = error.message;
    } on Object {
      if (requestVersion != _dataVersion) return;
      errorMessage = 'Favoriler yüklenemedi.';
    } finally {
      if (requestVersion == _dataVersion) {
        loading = false;
        _notify();
      }
    }
  }

  Future<bool> setFavorite(String propertyId, bool shouldBeFavorite) async {
    if (busyPropertyIds.contains(propertyId)) return false;
    busyPropertyIds = {...busyPropertyIds, propertyId};
    errorMessage = null;
    _notify();
    try {
      if (shouldBeFavorite) {
        await _gateway.addFavorite(propertyId);
      } else {
        await _gateway.removeFavorite(propertyId);
        items = items
            .where((item) => item.propertyId != propertyId)
            .toList(growable: false);
      }

      _loaded = false;
      final requestVersion = ++_dataVersion;
      try {
        final loadedItems = await _gateway.getFavorites();
        if (requestVersion == _dataVersion) {
          items = loadedItems;
          _loaded = true;
        }
      } on Object {
        if (requestVersion == _dataVersion) {
          errorMessage =
              'Favori durumu kaydedildi; liste şu anda yenilenemedi.';
        }
      }
      return true;
    } on FavoritesFailure catch (error) {
      errorMessage = error.message;
      return false;
    } on Object {
      errorMessage = 'Favori durumu güncellenemedi.';
      return false;
    } finally {
      busyPropertyIds = {...busyPropertyIds}..remove(propertyId);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
