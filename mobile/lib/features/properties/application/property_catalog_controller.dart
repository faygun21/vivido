import 'package:flutter/foundation.dart';

import '../domain/property_gateway.dart';
import '../domain/property_models.dart';

class PropertyCatalogController extends ChangeNotifier {
  PropertyCatalogController(this._gateway);

  final PropertyGateway _gateway;

  List<PropertySummary> items = const [];
  bool loading = false;
  String? errorMessage;

  /// Koridora hiç ev düşmediyse gösterilecek "en yakın ev" (bkz.
  /// [TopProperties.nearestFallback]).
  PropertySummary? nearestFallback;

  /// "Tüm evleri göster" açık mı? Kapalıyken (varsayılan) sunucu, profildeki
  /// özel yerlerden hesapladığı anchor koridoruna göre filtreliyor — web ile
  /// aynı davranış, aynı hesapla iki üründe aynı liste görünsün diye.
  bool showAll = false;

  bool _loaded = false;
  bool _disposed = false;
  int _loadVersion = 0;

  /// [showAll] değiştirildiğinde liste sunucudan YENİDEN çekilir: filtre
  /// istemcide değil sunucuda uygulanıyor, elde süzmek yanlış sonuç verirdi
  /// (koridor dışındaki evler zaten hiç gelmemiş oluyor).
  Future<void> setShowAll(bool value) async {
    if (showAll == value) return;
    showAll = value;
    await load(force: true);
  }

  Future<void> load({bool force = false}) async {
    if (!force && _loaded) return;
    final requestVersion = ++_loadVersion;
    loading = true;
    errorMessage = null;
    _notify();
    try {
      final response = await _gateway.getTopProperties(showAll: showAll);
      if (requestVersion != _loadVersion) return;
      items = response.items;
      nearestFallback = response.nearestFallback;
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
