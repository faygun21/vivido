import 'property_models.dart';

/// `GET /properties/top` yanıtı.
///
/// ⚠️ BU UÇ BİR ZAMANLAR DÜZ DİZİ DÖNÜYORDU. Web tarafında anchor (özel yer)
/// filtresi eklenince nesneye çevrildi ama mobil istemci güncellenmedi;
/// `json as List<dynamic>` çalışma zamanında patlıyor ve Konutlar sekmesi
/// hiç açılmıyordu. Ortak sözleşme sessizce kırıldığında derleyici uyarmaz —
/// bu yüzden şekil artık burada AÇIKÇA modelleniyor.
class TopProperties {
  const TopProperties({required this.items, this.nearestFallback});

  const TopProperties.empty() : items = const [], nearestFallback = null;

  final List<PropertySummary> items;

  /// Anchor koridoruna hiçbir ev düşmediyse, koridorun DIŞINDAKİ en yakın ev.
  ///
  /// "Burada uygun ev yok" demek yerine "burada yok ama en yakını şu" demeyi
  /// sağlıyor. Koridor uygulanmadıysa (anchor yok ya da "Tüm evleri göster"
  /// açık) null gelir.
  final PropertySummary? nearestFallback;
}

abstract interface class PropertyGateway {
  /// [showAll] true ise anchor koridoru uygulanmaz, ilçenin tamamından en
  /// yüksek puanlı [limit] ev döner. Sunucu tarafı varsayılanıyla aynı.
  Future<TopProperties> getTopProperties({
    int limit = 20,
    bool showAll = false,
  });

  Future<PropertyDetail> getPropertyDetail(String id);
}

class PropertyDataFailure implements Exception {
  const PropertyDataFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
