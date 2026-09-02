import 'package:flutter/foundation.dart';

import '../../map_data/domain/map_data_models.dart';
import '../domain/area_poi.dart';
import '../domain/location_analysis.dart';

/// Analiz alanı içindeki hizmet noktalarını kategori kategori getirir.
///
/// ⚠️ TEK KATEGORİ, İSTEK BAŞINA
///
/// Sunucu ucu (`/pois/near`) tek kategori alıyor. Sekiz kategoriyi birden
/// çekip istemcide süzmek daha az kod olurdu ama sekiz paralel istek
/// demek — kullanıcı çoğu zaman bir ya da iki kategoriye bakıyor. Seçilen
/// kategori çekiliyor, sonuç ÖNBELLEĞE alınıyor: kategoriler arasında ileri
/// geri gitmek yeni istek atmıyor.
///
/// Önbellek merkez ya da yarıçap değişince tamamen atılıyor — eski merkeze
/// ait bir listeyi yeni çemberde göstermek sessiz bir yalan olurdu.
class AreaPoiController extends ChangeNotifier {
  AreaPoiController(this._gateway);

  final AreaPoiGateway _gateway;

  /// Şu an listelenen kategori. `null` ise kullanıcı henüz seçmedi.
  String? selectedCategory;

  List<AreaPoi> items = const [];
  bool loading = false;
  String? errorMessage;

  AnalysisCoordinate? _center;
  double _radiusM = 0;
  final Map<String, List<AreaPoi>> _cache = {};
  int _requestVersion = 0;
  bool _disposed = false;

  /// Analiz alanı değişti — önbelleği at, seçili kategoriyi yeniden çek.
  void setArea({required AnalysisCoordinate center, required double radiusM}) {
    final sameArea =
        _center != null &&
        _center!.latitude == center.latitude &&
        _center!.longitude == center.longitude &&
        _radiusM == radiusM;
    if (sameArea) return;

    _center = center;
    _radiusM = radiusM;
    _cache.clear();
    items = const [];
    errorMessage = null;
    _requestVersion++;
    _notify();

    if (selectedCategory != null) {
      // İlk açılışta bir kategori seçili değilse bekliyoruz; kullanıcı
      // seçince yükleniyor.
      reload(selectedCategory!);
    }
  }

  /// Alan kapatıldı.
  void clear() {
    _center = null;
    _radiusM = 0;
    _cache.clear();
    items = const [];
    selectedCategory = null;
    errorMessage = null;
    loading = false;
    _requestVersion++;
    _notify();
  }

  /// Kategoriye geç. Önbellekte varsa istek atılmıyor.
  void select(String categoryCode) {
    if (selectedCategory == categoryCode) return;
    selectedCategory = categoryCode;
    errorMessage = null;

    final cached = _cache[categoryCode];
    if (cached != null) {
      items = cached;
      loading = false;
      _notify();
      return;
    }

    items = const [];
    _notify();
    reload(categoryCode);
  }

  /// Seçili kategoriyi (yeniden) yükler.
  Future<void> reload(String categoryCode) async {
    final center = _center;
    if (center == null) return;

    final version = ++_requestVersion;
    loading = true;
    errorMessage = null;
    _notify();

    try {
      final pois = await _gateway.getPoisNear(
        latitude: center.latitude,
        longitude: center.longitude,
        radiusM: _radiusM,
        categoryCode: categoryCode,
      );
      if (version != _requestVersion || _disposed) return;

      final ranked = rankByDistance(
        center: center,
        pois: pois,
        radiusM: _radiusM,
      );
      _cache[categoryCode] = ranked;
      if (selectedCategory == categoryCode) items = ranked;
    } on AreaPoiFailure catch (failure) {
      if (version == _requestVersion) errorMessage = failure.message;
    } on Object {
      if (version == _requestVersion) {
        errorMessage = 'Çevredeki hizmet noktaları yüklenemedi.';
      }
    } finally {
      if (version == _requestVersion && !_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  /// Haritada vurgulanacak noktalar — listede ne varsa o.
  List<PoiMapItem> get highlighted =>
      items.map((item) => item.poi).toList(growable: false);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
