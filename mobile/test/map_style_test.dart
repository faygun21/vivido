import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vivido_mobile/features/map/presentation/widgets/cankaya_map.dart';
import 'package:vivido_mobile/features/map_data/presentation/poi_category_colors.dart';

/// Harita stilinin web ile aynı katmanları taşıdığını doğrular.
///
/// ⚠️ NEDEN BU TEST VAR
///
/// Eksik bir MapLibre katmanı çalışma zamanında HATA VERMEZ — sadece
/// çizilmez. Mobil stil aylarca `transportation_name` ve `place` kaynak
/// katmanlarını okuyan hiçbir `symbol` katmanı içermeden çalıştı: yollar
/// vardı, isimleri yoktu; mahalleler vardı, adları yoktu. `glyphs` tanımlı
/// olduğu için küme sayıları çiziliyordu ve eksiklik "font sorunu" gibi de
/// görünmüyordu.
///
/// Aynı sessizlik favori katmanı için de geçerliydi: web favorileri altın
/// yıldızla gösteriyordu, mobilde katman hiç yoktu.
void main() {
  late Map<String, Object?> style;
  late List<Map<String, Object?>> layers;
  late Map<String, Object?> sources;

  setUp(() {
    style = jsonDecode(vividoMapStyle) as Map<String, Object?>;
    layers =
        (style['layers'] as List<Object?>)
            .cast<Map<String, Object?>>()
            .toList();
    sources = style['sources'] as Map<String, Object?>;
  });

  Map<String, Object?> layer(String id) => layers.firstWhere(
    (item) => item['id'] == id,
    orElse: () => throw StateError('"$id" katmanı stilde yok'),
  );

  int indexOf(String id) => layers.indexWhere((item) => item['id'] == id);

  group('etiketler', () {
    test('sokak adları çiziliyor', () {
      final roads = layer('vivido-yol-adlari');
      expect(roads['type'], 'symbol');
      expect(roads['source-layer'], 'transportation_name');

      final layout = roads['layout'] as Map<String, Object?>;
      expect(layout['text-field'], ['get', 'name']);
      // Etiket yol boyunca kıvrılmalı; yatay bir etiket hangi yola ait
      // olduğunu söylemez.
      expect(layout['symbol-placement'], 'line');
    });

    test('yer adları çiziliyor', () {
      final places = layer('vivido-yer-adlari');
      expect(places['type'], 'symbol');
      expect(places['source-layer'], 'place');
    });

    test('etiketlerin halesi var', () {
      // Hale olmadan gri metin, altındaki beyaz yolla aynı tonda kalıyor
      // ve okunmuyor.
      for (final id in ['vivido-yol-adlari', 'vivido-yer-adlari']) {
        final paint = layer(id)['paint'] as Map<String, Object?>;
        expect(paint['text-halo-color'], '#ffffff', reason: id);
        expect(paint['text-halo-width'], greaterThan(1), reason: id);
      }
    });

    test('metin çizen her katman için glyphs tanımlı', () {
      // `glyphs` yoksa MapLibre `text-field` içeren her symbol katmanını
      // SESSİZCE boş çizer.
      expect(style['glyphs'], isNotNull);
      expect(style['glyphs'], contains('{fontstack}'));
    });
  });

  group('mahalle katmanı', () {
    test('kaynak ve iki katman tanımlı', () {
      expect(sources, contains('vivido-neighborhoods'));
      expect(layer('vivido-neighborhood-fill')['type'], 'fill');
      expect(layer('vivido-neighborhood-line')['type'], 'line');
    });

    test('dolgu şeffaf — altındaki sokaklar okunur kalmalı', () {
      final paint =
          layer('vivido-neighborhood-fill')['paint'] as Map<String, Object?>;
      expect(paint['fill-opacity'], lessThan(0.3));
    });
  });

  group('favori katmanı', () {
    test('konutlardan AYRI bir kaynak kullanıyor', () {
      // Türetilmiş olsaydı "Konutlar" katmanı kapatıldığında favoriler de
      // kaybolurdu; kullanıcı tam olarak bunun tersini istiyor.
      expect(sources, contains('vivido-favorites'));
      expect(layer('vivido-favorite-circles')['source'], 'vivido-favorites');
      expect(layer('vivido-favorite-icons')['source'], 'vivido-favorites');
    });

    test('kümelenmiyor', () {
      final source = sources['vivido-favorites'] as Map<String, Object?>;
      expect(source['cluster'], isNull);
    });

    test('konut katmanının ÜSTÜNDE çiziliyor', () {
      // Favori olan ev aynı koordinatta iki kaynakta birden var; favori
      // sonra çizilmezse turuncu ev pini onu örter.
      expect(
        indexOf('vivido-favorite-circles'),
        greaterThan(indexOf('vivido-property-icons')),
      );
    });

    test('yarıçapı konutunkinden büyük', () {
      final favorite =
          layer('vivido-favorite-circles')['paint'] as Map<String, Object?>;
      final property =
          layer('vivido-property-points')['paint'] as Map<String, Object?>;
      expect(
        favorite['circle-radius'] as num,
        greaterThan(property['circle-radius'] as num),
        reason: 'üst üste bindiklerinde favori halka gibi taşmalı',
      );
    });
  });

  group('yol hiyerarşisi', () {
    // Tek bir beyaz çizgi vardı: otoyol da ara sokak da aynı görünüyordu
    // ve harita "nereden geçilir" sorusuna cevap vermiyordu.
    test('küçük ve ana yollar birbirini dışlayan filtrelerle ayrılmış', () {
      final minor = layer('yollar-kucuk');
      final main = layer('yollar-ana');
      expect(minor['filter'], isNotNull);
      expect(main['filter'], isNotNull);
      expect(
        (main['paint'] as Map<String, Object?>)['line-color'],
        isNot((minor['paint'] as Map<String, Object?>)['line-color']),
        reason: 'ana arter ile ara sokak aynı renkteyse hiyerarşi görünmez',
      );
    });
  });

  group('konut işaretçisi', () {
    test('POI ile AYNI dili konuşuyor: dolu renkli daire + beyaz ikon', () {
      // Eskiden tersti (beyaz daire + turuncu ikon) ve haritada iki farklı
      // işaret dili vardı.
      final circle =
          layer('vivido-property-points')['paint'] as Map<String, Object?>;
      expect(circle['circle-color'], '#EA580C');
      expect(circle['circle-stroke-color'], '#ffffff');
    });

    test('küme ve tekil pin AYNI rengi kullanıyor', () {
      final cluster =
          layer('vivido-property-clusters')['paint'] as Map<String, Object?>;
      final single =
          layer('vivido-property-points')['paint'] as Map<String, Object?>;
      expect(cluster['circle-color'], single['circle-color']);
    });
  });

  group('POI katmanı', () {
    test('renk ifadesi bütün kategorileri kapsıyor', () {
      final paint =
          layer('vivido-poi-points')['paint'] as Map<String, Object?>;
      final expression = (paint['circle-color'] as List<Object?>).join(' ');
      for (final code in poiCategoryColors.keys) {
        expect(expression, contains(code));
      }
    });

    test('ikon daireden GEÇ beliriyor', () {
      // Küçük dairenin üstünde ikon okunmaz, sadece lekelenir.
      final circleZoom = layer('vivido-poi-points')['minzoom'] as num;
      final iconZoom = layer('vivido-poi-icons')['minzoom'] as num;
      expect(iconZoom, greaterThan(circleZoom));
    });
  });
}
