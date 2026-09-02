import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivido_mobile/core/models/models.dart';
import 'package:vivido_mobile/core/network/api_client.dart';
import 'package:vivido_mobile/core/storage/token_store.dart';
import 'package:vivido_mobile/features/location_analysis/application/area_poi_controller.dart';
import 'package:vivido_mobile/features/location_analysis/data/api_area_poi_gateway.dart';
import 'package:vivido_mobile/features/location_analysis/domain/area_poi.dart';
import 'package:vivido_mobile/features/location_analysis/domain/location_analysis.dart';
import 'package:vivido_mobile/features/map_data/domain/map_data_models.dart';

/// Analiz çemberinin içindeki hizmet noktaları.
///
/// Çember eskiden yalnızca çiziliyordu; "bu alanda ne var?" sorusunun
/// cevabı hiçbir yerde yoktu.
void main() {
  const center = AnalysisCoordinate(latitude: 39.9, longitude: 32.85);

  PoiMapItem poi(String id, double lat, double lon, {String category = 'market'}) =>
      PoiMapItem(
        id: id,
        name: 'POI $id',
        categoryCode: category,
        latitude: lat,
        longitude: lon,
      );

  group('mesafeye göre sıralama', () {
    test('merkeze yakından uzağa sıralar', () {
      final ranked = rankByDistance(
        center: center,
        radiusM: 5000,
        pois: [
          poi('uzak', 39.92, 32.85),
          poi('yakin', 39.901, 32.85),
          poi('orta', 39.91, 32.85),
        ],
      );
      expect(
        ranked.map((item) => item.poi.id),
        ['yakin', 'orta', 'uzak'],
      );
    });

    test('yarıçapın DIŞINDA kalanları eler', () {
      // Sunucu yarıçapı bbox/PostGIS ile uyguluyor ve kenar durumlarda
      // birkaç metre taşan sonuçlar dönebiliyor. Listede "yürüme alanı
      // içinde" diyorsak gerçekten içinde olmalı.
      final ranked = rankByDistance(
        center: center,
        radiusM: 400,
        pois: [poi('icerde', 39.9018, 32.85), poi('disarda', 39.93, 32.85)],
      );
      expect(ranked.map((item) => item.poi.id), ['icerde']);
    });

    test('yürüme süresi çemberle aynı hızı kullanıyor', () {
      // Çember `walkingRadiusMetres` ile 80 m/dk üzerinden çiziliyor.
      // Farklı bir sabit kullanılsaydı çemberin KENARINDAKİ bir nokta
      // çemberin süresinden farklı bir süre gösterirdi.
      final radius = walkingRadiusMetres(10); // 800 m
      final ranked = rankByDistance(
        center: center,
        radiusM: radius,
        // Merkezden ~800 m kuzey.
        pois: [poi('kenar', 39.9 + 800 / 111320, 32.85)],
      );
      expect(ranked, hasLength(1));
      expect(ranked.single.walkingMinutes, closeTo(10, 1));
    });

    test('çok yakın nokta için süre 0 değil 1 dakika', () {
      final ranked = rankByDistance(
        center: center,
        radiusM: 800,
        pois: [poi('bitisik', 39.90001, 32.85001)],
      );
      expect(ranked.single.walkingMinutes, 1);
    });
  });

  group('AreaPoiController', () {
    ApiClient clientReturning(
      List<Map<String, Object?>> Function(Uri url) handler, {
      void Function(Uri url)? onRequest,
    }) => ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStore: MemoryTokenStore(
        const AuthSession(
          accessToken: 'a',
          refreshToken: 'r',
          expiresIn: 3600,
          user: AuthUser(id: 'u', email: 'a@b.c'),
        ),
      ),
      httpClient: MockClient((request) async {
        onRequest?.call(request.url);
        return http.Response(
          jsonEncode(handler(request.url)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    test('kategori seçilince o kategoriyi çeker ve sıralar', () async {
      final requested = <String?>[];
      final controller = AreaPoiController(
        ApiAreaPoiGateway(
          clientReturning(
            (url) => [
              {
                'id': '2',
                'name': 'Uzak market',
                'categoryCode': 'market',
                'latitude': 39.905,
                'longitude': 32.85,
              },
              {
                'id': '1',
                'name': 'Yakın market',
                'categoryCode': 'market',
                'latitude': 39.9005,
                'longitude': 32.85,
              },
            ],
            onRequest: (url) => requested.add(url.queryParameters['category']),
          ),
        ),
      );
      addTearDown(controller.dispose);

      controller.setArea(center: center, radiusM: 800);
      controller.select('market');
      await Future<void>.delayed(Duration.zero);

      expect(requested, ['market']);
      expect(controller.items.map((item) => item.poi.id), ['1', '2']);
      expect(controller.loading, isFalse);
    });

    test('yarıçap sunucuya TAM SAYI olarak gidiyor', () async {
      // Ondalıklı yarıçapta uç 400 dönüyordu.
      Uri? seen;
      final controller = AreaPoiController(
        ApiAreaPoiGateway(
          clientReturning((_) => const [], onRequest: (url) => seen = url),
        ),
      );
      addTearDown(controller.dispose);

      controller.setArea(center: center, radiusM: 1234.56);
      controller.select('park');
      await Future<void>.delayed(Duration.zero);

      expect(seen?.queryParameters['radiusM'], '1235');
    });

    test('aynı kategoriye dönünce yeni istek atmaz', () async {
      var calls = 0;
      final controller = AreaPoiController(
        ApiAreaPoiGateway(
          clientReturning((_) => const [], onRequest: (_) => calls++),
        ),
      );
      addTearDown(controller.dispose);

      controller.setArea(center: center, radiusM: 800);
      controller.select('market');
      await Future<void>.delayed(Duration.zero);
      controller.select('park');
      await Future<void>.delayed(Duration.zero);
      controller.select('market');
      await Future<void>.delayed(Duration.zero);

      expect(calls, 2, reason: 'market önbellekten gelmeli');
    });

    test('alan değişince önbellek atılıyor', () async {
      // Eski merkeze ait bir listeyi yeni çemberde göstermek sessiz bir
      // yalan olurdu.
      var calls = 0;
      final controller = AreaPoiController(
        ApiAreaPoiGateway(
          clientReturning((_) => const [], onRequest: (_) => calls++),
        ),
      );
      addTearDown(controller.dispose);

      controller.setArea(center: center, radiusM: 800);
      controller.select('market');
      await Future<void>.delayed(Duration.zero);

      controller.setArea(
        center: const AnalysisCoordinate(latitude: 39.95, longitude: 32.9),
        radiusM: 800,
      );
      await Future<void>.delayed(Duration.zero);

      expect(calls, 2, reason: 'yeni merkez için yeniden çekilmeli');
    });

    test('yürüme süresi değişince yarıçap yenileniyor', () async {
      final radii = <String?>[];
      final controller = AreaPoiController(
        ApiAreaPoiGateway(
          clientReturning(
            (_) => const [],
            onRequest: (url) => radii.add(url.queryParameters['radiusM']),
          ),
        ),
      );
      addTearDown(controller.dispose);

      controller.setArea(center: center, radiusM: walkingRadiusMetres(10));
      controller.select('market');
      await Future<void>.delayed(Duration.zero);

      controller.setArea(center: center, radiusM: walkingRadiusMetres(30));
      await Future<void>.delayed(Duration.zero);

      expect(radii, ['800', '2400']);
    });

    test('alan kapatılınca liste ve seçim sıfırlanıyor', () async {
      final controller = AreaPoiController(
        ApiAreaPoiGateway(
          clientReturning(
            (_) => [
              {
                'id': '1',
                'name': 'Market',
                'categoryCode': 'market',
                'latitude': 39.9005,
                'longitude': 32.85,
              },
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);

      controller.setArea(center: center, radiusM: 800);
      controller.select('market');
      await Future<void>.delayed(Duration.zero);
      expect(controller.items, isNotEmpty);

      controller.clear();
      expect(controller.items, isEmpty);
      expect(controller.selectedCategory, isNull);
      expect(controller.highlighted, isEmpty);
    });

    test('sunucu hatası kullanıcı mesajına çevriliyor', () async {
      final controller = AreaPoiController(
        ApiAreaPoiGateway(
          ApiClient(
            baseUrl: 'http://localhost/api/v1',
            tokenStore: MemoryTokenStore(),
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode({'title': 'Hata', 'detail': 'POI servisi kapalı.'}),
                503,
                headers: {
                  'content-type': 'application/problem+json; charset=utf-8',
                },
              ),
            ),
          ),
        ),
      );
      addTearDown(controller.dispose);

      controller.setArea(center: center, radiusM: 800);
      controller.select('market');
      await Future<void>.delayed(Duration.zero);

      expect(controller.errorMessage, 'POI servisi kapalı.');
      expect(controller.loading, isFalse);
    });
  });
}
