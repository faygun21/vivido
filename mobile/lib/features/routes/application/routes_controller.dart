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

  /// Düzenlenen KAYITLI rotanın id'si. Kaydederken bunun üzerine
  /// yazılıyor — yoksa her düzenleme yeni bir rota yaratır ve kullanıcının
  /// kayıtlı rotaları çoğalırdı.
  String? _editedRouteId;

  /// Önizlemeden beri değişiklik yapıldı mı? "Rotayı kaydet" düğmesi buna
  /// bakıyor.
  bool _hasUnsavedChanges = false;

  /// Önizlemede kullanılan başlangıç noktası; yeniden optimize ederken
  /// aynısı kullanılsın diye saklanıyor.
  RouteStart? _pendingStart;

  bool get hasUnsavedChanges => _hasUnsavedChanges;

  /// Ekranda kaydedilmemiş bir rota var mı?
  bool get isPreviewing => activeRoute != null && !activeRoute!.isSaved;

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

  /// Rotayı hesaplar ve ekranda gösterir — KAYDETMEZ.
  ///
  /// Taslak (`draft`) BİLEREK temizlenmiyor: kullanıcı önizlemeyi beğenmezse
  /// seçtiği evleri baştan seçmek zorunda kalmamalı.
  Future<bool> previewRoute({
    required RouteStart start,
    required RouteTravelMode mode,
  }) async {
    if (draft.length < minRouteStops || draft.length > maxRouteStops) {
      errorMessage = 'Rota için 2 ile 8 arasında konut seçmelisin.';
      _notify();
      return false;
    }

    saving = true;
    errorMessage = null;
    _notify();
    try {
      activeRoute = await _gateway.previewRoute(
        start: start,
        propertyIds: draft.map((item) => item.id).toList(growable: false),
        mode: mode,
      );
      _pendingStart = start;
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

  /// Ekrandaki rotanın duraklarını değiştirip YENİDEN optimize eder.
  ///
  /// Ekleme ve çıkarma aynı yoldan geçiyor: her ikisinde de sıralama
  /// baştan hesaplanmalı, yoksa ev listeye eklenir ama rota eski sırayı
  /// korur ve "en uygun ziyaret sırası" vaadi bozulur.
  Future<bool> reoptimize(List<int> propertyIds) async {
    final route = activeRoute;
    if (route == null) return false;

    if (propertyIds.length < minRouteStops) {
      errorMessage = 'Rotada en az 2 konut kalmalı.';
      _notify();
      return false;
    }
    if (propertyIds.length > maxRouteStops) {
      errorMessage = 'Bir rotaya en fazla 8 konut ekleyebilirsin.';
      _notify();
      return false;
    }

    saving = true;
    errorMessage = null;
    _notify();
    try {
      final next = await _gateway.previewRoute(
        start: _pendingStart ?? route.start,
        propertyIds: propertyIds,
        mode: route.mode,
      );
      activeRoute = next;
      // Kayıtlı bir rotayı düzenliyorsak artık kaydedilmemiş bir sürüm
      // ekranda: kullanıcı değişikliği kaydedene kadar sunucudaki hâli
      // eskisi olarak kalıyor.
      _editedRouteId ??= route.isSaved ? route.id : null;
      _hasUnsavedChanges = true;
      return true;
    } on RoutesFailure catch (error) {
      errorMessage = error.message;
      return false;
    } on Object {
      errorMessage = 'Rota güncellenemedi.';
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  /// Ekrandaki rotayı kaydeder.
  ///
  /// ⚠️ API'de GÜNCELLEME UCU YOK (`PUT /routes/{id}` diye bir şey yok), o
  /// yüzden kayıtlı bir rota düzenlendiğinde yeni bir rota oluşturup
  /// eskisini siliyoruz. Sıra ÖNEMLİ: önce oluştur, sonra sil. Tersi olsaydı
  /// oluşturma hata verdiğinde kullanıcı hem eski hem yeni rotayı kaybederdi.
  /// Silme hata verirse iki rota kalır — can sıkıcı ama veri kaybı değil.
  Future<bool> saveActiveRoute({required String name}) async {
    final route = activeRoute;
    if (route == null) return false;
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
        start: _pendingStart ?? route.start,
        propertyIds: route.propertyIds,
        mode: route.mode,
      );

      final replaced = _editedRouteId;
      if (replaced != null && replaced != created.id) {
        try {
          await _gateway.deleteRoute(replaced);
          savedRoutes = savedRoutes
              .where((item) => item.id != replaced)
              .toList();
        } on Object {
          // Eski rota silinemedi. Yeni rota kaydedildi, veri kaybı yok;
          // kullanıcıyı burada uyarmak yerine listede iki kayıt görmesine
          // izin veriyoruz — istediğini elle silebilir.
        }
      }

      activeRoute = created;
      _editedRouteId = null;
      _hasUnsavedChanges = false;
      _upsertSummary(created);
      _routesLoaded = true;
      draft = const [];
      await _refreshRoutesBestEffort();
      return true;
    } on RoutesFailure catch (error) {
      errorMessage = error.message;
      return false;
    } on Object {
      errorMessage = 'Rota kaydedilemedi.';
      return false;
    } finally {
      saving = false;
      _notify();
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

  /// Haritadaki rotayı kapatır. Kayıtlı rotalara DOKUNMAZ.
  ///
  /// Düzenleme durumu da sıfırlanıyor: kaydedilmemiş değişiklikler
  /// atılıyor, sunucudaki kayıtlı hâli olduğu gibi kalıyor.
  void closeActiveRoute() {
    // Uçuştaki `openRoute` isteğini geçersiz kılar: kapattıktan sonra
    // gecikmeli bir yanıt gelip rotayı geri açmasın.
    _openRequestVersion++;
    openingRouteId = null;
    activeRoute = null;
    _editedRouteId = null;
    _hasUnsavedChanges = false;
    _pendingStart = null;
    errorMessage = null;
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
