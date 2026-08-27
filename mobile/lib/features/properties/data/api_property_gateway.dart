import '../../../core/network/api_client.dart';
import '../domain/property_gateway.dart';
import '../domain/property_models.dart';

class ApiPropertyGateway implements PropertyGateway {
  const ApiPropertyGateway(this._client);

  final ApiClient _client;

  @override
  Future<TopProperties> getTopProperties({
    int limit = 20,
    bool showAll = false,
  }) async {
    try {
      // Anchor koridorunu SUNUCU hesaplıyor (profildeki özel yerlerden).
      // İstemcinin merkez/yarıçap göndermesi gerekmiyor; tek bayrak yeter.
      final json =
          await _client.get('/properties/top?limit=$limit&showAll=$showAll')
              as Map<String, dynamic>;

      final items = (json['items'] as List<dynamic>? ?? const [])
          .map((item) => PropertySummary.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);

      final fallbackJson = json['nearestFallback'] as Map<String, dynamic>?;

      // `corridorPolygon` BİLEREK okunmuyor: web de onu haritada
      // göstermeyi bıraktı (cf0f0df). Alan DTO'da duruyor ama arayüz
      // tüketmiyor.
      return TopProperties(
        items: items,
        nearestFallback: fallbackJson == null
            ? null
            : PropertySummary.fromJson(fallbackJson),
      );
    } on ApiException catch (error) {
      throw PropertyDataFailure(error.detail ?? error.title);
    }
  }

  @override
  Future<PropertyDetail> getPropertyDetail(String id) async {
    try {
      final json = await _client.get('/properties/$id') as Map<String, dynamic>;
      return PropertyDetail.fromJson(json);
    } on ApiException catch (error) {
      throw PropertyDataFailure(error.detail ?? error.title);
    }
  }
}
