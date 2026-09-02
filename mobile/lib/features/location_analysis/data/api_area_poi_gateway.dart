import '../../../core/network/api_client.dart';
import '../../map_data/domain/map_data_models.dart';
import '../domain/area_poi.dart';

/// `GET /pois/near?lat&lon&radiusM&category`
///
/// Aynı uç konut detayındaki "güçlü yön noktaları" için de kullanılıyor
/// (`ApiStrengthPoiGateway`). Yeni bir uç yazılmadı: sunucu zaten yarıçap
/// içinde kategoriye göre filtreliyor.
class ApiAreaPoiGateway implements AreaPoiGateway {
  const ApiAreaPoiGateway(this._client);

  final ApiClient _client;

  @override
  Future<List<PoiMapItem>> getPoisNear({
    required double latitude,
    required double longitude,
    required double radiusM,
    required String categoryCode,
  }) async {
    try {
      final response = await _client.get(
        Uri(
          path: '/pois/near',
          queryParameters: {
            'lat': latitude.toString(),
            'lon': longitude.toString(),
            // Sunucu tam sayı bekliyor; ondalıklı yarıçap 400 dönüyordu.
            'radiusM': radiusM.round().toString(),
            'category': categoryCode,
          },
        ).toString(),
      );
      if (response is! List<dynamic>) {
        throw const AreaPoiFailure('Hizmet noktası yanıtı beklenen biçimde değil.');
      }
      return response
          .map((item) => PoiMapItem.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } on ApiException catch (error) {
      throw AreaPoiFailure(error.detail ?? error.title);
    } on AreaPoiFailure {
      rethrow;
    } on Object {
      throw const AreaPoiFailure('Çevredeki hizmet noktaları yüklenemedi.');
    }
  }
}
