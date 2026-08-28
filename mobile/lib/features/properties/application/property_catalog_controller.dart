import 'package:flutter/foundation.dart';

import '../domain/property_gateway.dart';
import '../domain/property_models.dart';

enum PropertySortOption {
  score,
  rentDescending,
  rentAscending,
  areaDescending,
  areaAscending,
}

class RankedProperty {
  const RankedProperty({required this.property, required this.rank});

  final PropertySummary property;
  final int rank;
}

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
  Set<String> selectedRoomCounts = const {};
  PropertySortOption sortOption = PropertySortOption.score;

  List<String> get roomCountOptions =>
      items.map((item) => item.roomCount).toSet().toList()..sort();

  bool get hasActiveFilter => selectedRoomCounts.isNotEmpty;
  bool get hasCustomView =>
      hasActiveFilter || sortOption != PropertySortOption.score;

  List<RankedProperty> get visibleItems {
    final filtered = <RankedProperty>[
      for (var index = 0; index < items.length; index++)
        if (selectedRoomCounts.isEmpty ||
            selectedRoomCounts.contains(items[index].roomCount))
          RankedProperty(property: items[index], rank: index + 1),
    ];
    switch (sortOption) {
      case PropertySortOption.score:
        return filtered;
      case PropertySortOption.rentDescending:
        filtered.sort(
          (left, right) =>
              right.property.monthlyRent.compareTo(left.property.monthlyRent),
        );
        break;
      case PropertySortOption.rentAscending:
        filtered.sort(
          (left, right) =>
              left.property.monthlyRent.compareTo(right.property.monthlyRent),
        );
        break;
      case PropertySortOption.areaDescending:
        filtered.sort(
          (left, right) =>
              right.property.areaM2.compareTo(left.property.areaM2),
        );
        break;
      case PropertySortOption.areaAscending:
        filtered.sort(
          (left, right) =>
              left.property.areaM2.compareTo(right.property.areaM2),
        );
        break;
    }
    return filtered;
  }

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

  void toggleRoomCount(String value) {
    final next = Set<String>.of(selectedRoomCounts);
    next.contains(value) ? next.remove(value) : next.add(value);
    selectedRoomCounts = next;
    _notify();
  }

  void setSortOption(PropertySortOption value) {
    if (sortOption == value) return;
    sortOption = value;
    _notify();
  }

  void clearFilters() {
    if (selectedRoomCounts.isEmpty) return;
    selectedRoomCounts = const {};
    _notify();
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
