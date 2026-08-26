import 'package:flutter/foundation.dart';

import '../domain/route_models.dart';
import '../domain/routes_gateway.dart';

class RoutesController extends ChangeNotifier {
  RoutesController(this._gateway);

  final RoutesGateway _gateway;

  List<RouteDraftProperty> draft = const [];
  List<RouteSummary> savedRoutes = const [];
  RouteDetail? activeRoute;
  bool loading = false;
  bool saving = false;
  String? openingRouteId;
  Set<String> deletingRouteIds = const {};
  String? errorMessage;

  bool _routesLoaded = false;
  bool _disposed = false;
  int _routesDataVersion = 0;
  int _openRequestVersion = 0;

  bool containsProperty(int propertyId) =>
      draft.any((item) => item.id == propertyId);

  bool addProperty(RouteDraftProperty property) {
    if (containsProperty(property.id)) return true;
    if (draft.length >= maxRouteStops) {
      errorMessage = 'Bir rotaya en fazla 8 konut ekleyebilirsin.';
      _notify();
      return false;
    }
    draft = [...draft, property];
    errorMessage = null;
    _notify();
    return true;
  }

  void removeProperty(int propertyId) {
    draft = draft.where((item) => item.id != propertyId).toList();
    _notify();
  }

  void clearDraft() {
    draft = const [];
    errorMessage = null;
    _notify();
  }

  Future<void> loadRoutes({bool force = false}) async {
    if (!force && _routesLoaded) return;
    final requestVersion = ++_routesDataVersion;
    loading = true;
    errorMessage = null;
    _notify();
    try {
      final routes = await _gateway.getRoutes();
      if (requestVersion != _routesDataVersion) return;
      savedRoutes = routes;
      _routesLoaded = true;
    } on RoutesFailure catch (error) {
      if (requestVersion != _routesDataVersion) return;
      errorMessage = error.message;
    } on Object {
      if (requestVersion != _routesDataVersion) return;
      errorMessage = 'Kayıtlı rotalar yüklenemedi.';
    } finally {
      if (requestVersion == _routesDataVersion) {
        loading = false;
        _notify();
      }
    }
  }

  Future<bool> createRoute({
    required String name,
    required RouteStart start,
    required RouteTravelMode mode,
  }) async {
    if (draft.length < minRouteStops || draft.length > maxRouteStops) {
      errorMessage = 'Rota için 2 ile 8 arasında konut seçmelisin.';
      _notify();
      return false;
    }
    if (name.trim().isEmpty) {
      errorMessage = 'Rota adı zorunludur.';
      _notify();
      return false;
    }

    saving = true;
    errorMessage = null;
    _notify();
    try {
      final created = await _gateway.createRoute(
        name: name,
        start: start,
        propertyIds: draft.map((item) => item.id).toList(growable: false),
        mode: mode,
      );
      _routesDataVersion++;
      loading = false;
      activeRoute = created;
      _upsertSummary(created);
      _routesLoaded = true;
      draft = const [];
      await _refreshRoutesBestEffort();
      return true;
    } on RoutesFailure catch (error) {
      errorMessage = error.message;
      return false;
    } on Object {
      errorMessage = 'Rota oluşturulamadı.';
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<bool> openRoute(String id) async {
    final requestVersion = ++_openRequestVersion;
    openingRouteId = id;
    errorMessage = null;
    _notify();
    try {
      final route = await _gateway.getRoute(id);
      if (requestVersion != _openRequestVersion) return false;
      activeRoute = route;
      return true;
    } on RoutesFailure catch (error) {
      if (requestVersion != _openRequestVersion) return false;
      errorMessage = error.message;
      return false;
    } on Object {
      if (requestVersion != _openRequestVersion) return false;
      errorMessage = 'Rota detayı açılamadı.';
      return false;
    } finally {
      if (requestVersion == _openRequestVersion) {
        openingRouteId = null;
        _notify();
      }
    }
  }

  Future<bool> deleteRoute(String id) async {
    if (deletingRouteIds.contains(id)) return false;
    deletingRouteIds = {...deletingRouteIds, id};
    errorMessage = null;
    _notify();
    try {
      await _gateway.deleteRoute(id);
      _routesDataVersion++;
      loading = false;
      savedRoutes = savedRoutes.where((item) => item.id != id).toList();
      _routesLoaded = true;
      if (activeRoute?.id == id) activeRoute = null;
      return true;
    } on RoutesFailure catch (error) {
      errorMessage = error.message;
      return false;
    } on Object {
      errorMessage = 'Rota silinemedi.';
      return false;
    } finally {
      deletingRouteIds = {...deletingRouteIds}..remove(id);
      _notify();
    }
  }

  Future<bool> reoptimizeWithout(int propertyId) async {
    final current = activeRoute;
    if (current == null) return false;
    final remaining = current.stops
        .where((stop) => stop.propertyId != propertyId)
        .toList(growable: false);
    if (remaining.length < minRouteStops) {
      errorMessage = 'Rota en az 2 konut içermelidir.';
      _notify();
      return false;
    }

    saving = true;
    errorMessage = null;
    _notify();
    try {
      final replacement = await _gateway.createRoute(
        name: current.name,
        start: current.start,
        propertyIds: remaining
            .map((stop) => stop.propertyId)
            .toList(growable: false),
        mode: current.mode,
      );
      _routesDataVersion++;
      loading = false;
      activeRoute = replacement;
      _upsertSummary(replacement);
      _routesLoaded = true;
      draft = const [];

      try {
        await _gateway.deleteRoute(current.id);
        savedRoutes = savedRoutes
            .where((item) => item.id != current.id)
            .toList(growable: false);
      } on Object {
        errorMessage =
            'Yeni rota hazır; ancak önceki rota silinemedi. '
            'Rotalarım listesinden tekrar silebilirsin.';
      }

      await _refreshRoutesBestEffort();
      return true;
    } on RoutesFailure catch (error) {
      errorMessage = error.message;
      return false;
    } on Object {
      errorMessage = 'Rota yeniden oluşturulamadı.';
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  void closeActiveRoute() {
    _openRequestVersion++;
    openingRouteId = null;
    activeRoute = null;
    _notify();
  }

  void _upsertSummary(RouteDetail route) {
    final summary = RouteSummary(
      id: route.id,
      name: route.name,
      mode: route.mode,
      totalDistanceM: route.totalDistanceM,
      totalDurationS: route.totalDurationS,
      createdAt: route.createdAt,
      stopCount: route.stopCount,
    );
    savedRoutes = [
      summary,
      ...savedRoutes.where((item) => item.id != summary.id),
    ];
  }

  Future<void> _refreshRoutesBestEffort() async {
    loading = false;
    final requestVersion = ++_routesDataVersion;
    try {
      final routes = await _gateway.getRoutes();
      if (requestVersion != _routesDataVersion) return;
      savedRoutes = routes;
      _routesLoaded = true;
    } on Object {
      // Oluşturma/silme işlemi sunucuda başarıyla tamamlandıysa yalnızca
      // listenin yenilenememesi işlemi başarısız gibi göstermemelidir.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _openRequestVersion++;
    _routesDataVersion++;
    super.dispose();
  }
}
