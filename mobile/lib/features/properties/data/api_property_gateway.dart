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
      final raw = await _client.get(
        '/properties/top?limit=$limit&showAll=$showAll',
      );

      // ⚠️ ESKİ ŞEKLE DE DAYANIKLI. Uç bir zamanlar düz dizi dönüyordu;
      // eski bir sunucuya bağlanılırsa tip hatasıyla patlamak yerine
      // listeyi okuyup devam ediyoruz. (Bu savunma merge sırasında
      // arkadaşımızın çözümünden alındı.)
      final json = raw is Map<String, dynamic> ? raw : null;
      final rawItems = json == null ? raw : json['items'];

      final items = (rawItems as List<dynamic>? ?? const [])
          .map((item) => PropertySummary.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);

      // Dizi dönen eski sunucuda "en yakın ev" bilgisi zaten yok.
      final fallbackJson = json?['nearestFallback'] as Map<String, dynamic>?;

      // `corridorPolygon` BURADA okunmuyor: koridoru haritada
      // `AuthenticatedPropertiesMap` üzerinden çiziyoruz (bkz.
      // map_data gateway), liste ekranının ona ihtiyacı yok.
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
