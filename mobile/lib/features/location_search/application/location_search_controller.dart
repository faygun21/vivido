import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/api_location_search_gateway.dart';
import '../domain/location_search_models.dart';

class LocationSearchController extends ChangeNotifier {
  LocationSearchController(this._gateway);

  final LocationSearchGateway _gateway;

  List<LocationSearchResult> results = const [];
  LocationSearchResult? selected;
  String attribution = '';
  String? errorMessage;
  bool loading = false;
  bool searched = false;

  Future<void> search(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      errorMessage = 'En az 2 karakter yaz.';
      notifyListeners();
      return;
    }
    if (loading) return;

    loading = true;
    searched = false;
    errorMessage = null;
    results = const [];
    selected = null;
    notifyListeners();

    try {
      final response = await _gateway.search(query);
      results = response.items;
      attribution = response.attribution;
      searched = true;
    } on Object catch (error) {
      errorMessage = _describe(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void select(LocationSearchResult result) {
    selected = result;
    results = const [];
    searched = false;
    errorMessage = null;
    notifyListeners();
  }

  void clear() {
    results = const [];
    selected = null;
    attribution = '';
    errorMessage = null;
    searched = false;
    notifyListeners();
  }

  String _describe(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'LOCATION_SEARCH_UNAVAILABLE' =>
          'Konum servislerine şu anda ulaşılamıyor. Tekrar dene.',
        'NETWORK_ERROR' || 'REQUEST_TIMEOUT' =>
          'Bağlantı kurulamadı. İnternet ve API adresini kontrol et.',
        _ when error.statusCode == 404 =>
          'Konum arama endpointi bulunamadı. Backend sürümünü güncelle.',
        _ => error.detail ?? error.title,
      };
    }
    return 'Konum aranırken beklenmeyen bir hata oluştu.';
  }
}
