import 'package:flutter/foundation.dart';

import '../domain/property_gateway.dart';
import '../domain/property_models.dart';

class PropertyCatalogController extends ChangeNotifier {
  PropertyCatalogController(this._gateway);

  final PropertyGateway _gateway;

  List<PropertySummary> items = const [];
  bool loading = false;
  String? errorMessage;

  bool _loaded = false;
  bool _disposed = false;
  int _loadVersion = 0;

  Future<void> load({bool force = false}) async {
    if (!force && _loaded) return;
    final requestVersion = ++_loadVersion;
    loading = true;
    errorMessage = null;
    _notify();
    try {
      final loadedItems = await _gateway.getTopProperties();
      if (requestVersion != _loadVersion) return;
      items = loadedItems;
      _loaded = true;
    } on PropertyDataFailure catch (error) {
      if (requestVersion != _loadVersion) return;
      errorMessage = error.message;
    } on Object {
      if (requestVersion != _loadVersion) return;
      errorMessage = 'Konut listesi yüklenemedi.';
    } finally {
      if (requestVersion == _loadVersion) {
        loading = false;
        _notify();
      }
    }
  }

  void updateFavorite(String propertyId, bool isFavorite) {
    _loadVersion++;
    loading = false;
    _loaded = true;
    items = [
      for (final item in items)
        if (item.id == propertyId)
          item.copyWith(isFavorite: isFavorite)
        else
          item,
    ];
    _notify();
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
