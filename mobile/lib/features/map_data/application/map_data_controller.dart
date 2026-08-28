import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/map_data_gateway.dart';
import '../domain/map_data_models.dart';

class MapDataController extends ChangeNotifier {
  MapDataController({
    required MapDataGateway gateway,
    required this.authenticated,
    Duration viewportDebounce = const Duration(milliseconds: 250),
  }) : _gateway = gateway,
       _viewportDebounce = viewportDebounce;

  final MapDataGateway _gateway;
  final bool authenticated;
  final Duration _viewportDebounce;

  List<PoiCategory> categories = const [];
  Set<String> selectedCategories = const {};
  List<PoiMapItem> pois = const [];
  List<PropertyMapItem> properties = const [];
  AnchorCorridor? anchorCorridor;
  bool showAllProperties = false;
  bool propertiesVisible = true;
  bool isLoading = false;
  bool isViewportLoading = false;
  String? errorMessage;

  MapViewportBounds? _bounds;
  Timer? _viewportTimer;
  int _requestVersion = 0;
  bool _disposed = false;

  Future<void> initialize() async {
    isLoading = true;
    errorMessage = null;
    _notify();

    final errors = <String>[];

    try {
      categories = await _gateway.getPoiCategories();
      final availableCodes = categories.map((item) => item.code).toSet();
      selectedCategories = selectedCategories.intersection(availableCodes);
    } on MapDataFailure catch (error) {
      errors.add(error.message);
    }

    try {
      // Bu istek kategori isteğinden önce başlatılıp daha sonra beklendiğinde,
      // çevrimdışı cihazda erken tamamlanan hata Dart tarafından geçici olarak
      // "Unhandled Exception" sayılıyordu. İstek kendi try bloğunda başlatılıp
      // hemen beklenerek hata her zaman denetleyici içinde tutulur.
      final propertyData =
          authenticated
              ? await _gateway.getAuthenticatedProperties(
                showAll: showAllProperties,
              )
              : const AuthenticatedPropertiesMap(items: []);
      properties = propertyData.items;
      anchorCorridor = propertyData.corridor;
    } on MapDataFailure catch (error) {
      errors.add(error.message);
    }

    isLoading = false;
    errorMessage = errors.isEmpty ? null : errors.toSet().join('\n');
    _notify();

    if (_bounds != null) await refreshViewport();
  }

  PoiCategory? categoryFor(String code) {
    for (final category in categories) {
      if (category.code == code) return category;
    }
    return null;
  }

  void updateViewport(MapViewportBounds bounds) {
    if (!bounds.isValid || _bounds?.cacheKey == bounds.cacheKey) return;
    _bounds = bounds;
    _scheduleViewportRefresh();
  }

  void toggleCategory(String code) {
    final next = selectedCategories.toSet();
    next.contains(code) ? next.remove(code) : next.add(code);
    selectedCategories = next;
    if (next.isEmpty) pois = const [];
    _notify();
    _scheduleViewportRefresh(immediate: true);
  }

  void toggleProperties() {
    propertiesVisible = !propertiesVisible;
    _notify();
    if (propertiesVisible && !authenticated && properties.isEmpty) {
      _scheduleViewportRefresh(immediate: true);
    }
  }

  Future<void> toggleShowAllProperties() async {
    if (!authenticated || isLoading) return;
    showAllProperties = !showAllProperties;
    await initialize();
  }

  Future<void> retry() async {
    await initialize();
  }

  Future<void> refreshViewport() async {
    final bounds = _bounds;
    if (bounds == null || !bounds.isValid) return;

    final version = ++_requestVersion;
    isViewportLoading = true;
    errorMessage = null;
    _notify();

    try {
      final poiFuture =
          selectedCategories.isEmpty
              ? Future.value(const <PoiMapItem>[])
              : _gateway.getPois(
                bounds: bounds,
                categories: selectedCategories,
              );
      final propertyFuture =
          authenticated
              ? Future.value(properties)
              : _gateway.getPublicProperties(bounds);
      final result = await Future.wait<Object>([poiFuture, propertyFuture]);
      if (version != _requestVersion || _disposed) return;

      pois = result[0] as List<PoiMapItem>;
      if (!authenticated) {
        properties = result[1] as List<PropertyMapItem>;
      }
    } on MapDataFailure catch (error) {
      if (version == _requestVersion) errorMessage = error.message;
    } finally {
      if (version == _requestVersion) {
        isViewportLoading = false;
        _notify();
      }
    }
  }

  void _scheduleViewportRefresh({bool immediate = false}) {
    _viewportTimer?.cancel();
    _viewportTimer = Timer(
      immediate ? Duration.zero : _viewportDebounce,
      refreshViewport,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    _viewportTimer?.cancel();
    super.dispose();
  }
}
