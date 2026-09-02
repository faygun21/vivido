import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivido_mobile/core/theme/app_colors.dart';
import 'package:vivido_mobile/core/theme/app_theme.dart';
import 'package:vivido_mobile/core/theme/app_typography.dart';
import 'package:vivido_mobile/features/map_data/presentation/poi_category_colors.dart';
import 'package:vivido_mobile/features/properties/presentation/property_format.dart';
import 'package:vivido_mobile/shared/widgets/brand_icon.dart';

/// Mobil paletin web ile aynı kaldığını doğrular.
///
/// Bu test bir "kopyala-yapıştır kontrolü" gibi görünebilir ama gerçek bir
/// riski kapatıyor: renkler iki ayrı dilde iki ayrı dosyada yaşıyor ve
/// derleyici birinin diğerinden ayrıldığını fark edemez. Mobil uzun süre
/// YEŞİL (#087F5B) bir paletle çalıştı, web ise terracotta (#C0421D) —
/// kimse fark etmedi çünkü ikisini yan yana koyan bir şey yoktu.
void main() {
  group('palet web ile aynı', () {
    // Kaynak: web/src/index.css `:root`
    test('vurgu ve zemin renkleri web token değerleriyle birebir', () {
      expect(AppColors.bg, const Color(0xFFF9F4ED), reason: '--bg');
      expect(AppColors.surface, const Color(0xFFFFFFFF), reason: '--surface');
      expect(AppColors.ink, const Color(0xFF333333), reason: '--ink');
      expect(
        AppColors.inkMuted,
        const Color(0xFF737373),
        reason: '--ink-muted',
      );
      expect(AppColors.line, const Color(0xFFA79D93), reason: '--line');
      expect(AppColors.accent, const Color(0xFFC0421D), reason: '--accent');
      expect(
        AppColors.accentSecondary,
        const Color(0xFFE27250),
        reason: '--accent-secondary',
      );
      expect(AppColors.inputBg, const Color(0xFFECEAE6), reason: '--input-bg');
    });

    test('vurgu rengi eski yeşil tohum değerine geri dönmemiş', () {
      // Regresyon koruması: `ColorScheme.fromSeed(#087F5B)` günlerine
      // dönülürse bu test düşer.
      expect(AppColors.accent, isNot(const Color(0xFF087F5B)));
      expect(AppTheme.light.colorScheme.primary, AppColors.accent);
    });
  });

  group('skor bantları', () {
    // Eşikler: packages/shared/src/utils.ts `scoreBand()`
    //   >=85 excellent · >=70 good · >=55 fair · gerisi poor
    // Renkler: web/src/index.css `.score-badge--*`
    test('eşikler web scoreBand() ile aynı sınırlarda kırılır', () {
      expect(scoreBandOf(100), 'excellent');
      expect(scoreBandOf(85), 'excellent');
      expect(scoreBandOf(84.9), 'good');

      expect(scoreBandOf(70), 'good');
      expect(scoreBandOf(69.9), 'fair');

      expect(scoreBandOf(55), 'fair');
      expect(scoreBandOf(54.9), 'poor');

      expect(scoreBandOf(0), 'poor');
    });

    test('bant renkleri web rozet renkleriyle birebir', () {
      expect(AppColors.bandExcellent, const Color(0xFF15803D));
      expect(AppColors.bandGood, const Color(0xFF4D7C0F));
      expect(AppColors.bandFair, const Color(0xFFB45309));
      expect(AppColors.bandPoor, const Color(0xFF9A3412));
    });

    test('bant kodu → renk eşlemesi tek kaynaktan geliyor', () {
      // Regresyon koruması: `property_format.dart` bir zamanlar KENDİ
      // renk kümesini taşıyordu (#047857/#0F766E/#B91C1C) ve aynı ev
      // listede bir yeşil, detayda başka bir yeşil rozet alıyordu.
      expect(scoreBandColor('excellent'), AppColors.bandExcellent);
      expect(scoreBandColor('good'), AppColors.bandGood);
      expect(scoreBandColor('fair'), AppColors.bandFair);
      expect(scoreBandColor('poor'), AppColors.bandPoor);
    });

    test('etiketler web BAND_LABEL ile aynı', () {
      // Skor bir kalite yargısı değil, KULLANICIYA UYGUNLUK ölçüsü.
      // Mobil "Mükemmel/İyi/Orta/Düşük" diyordu — "mükemmel ev" yanlış vaat.
      expect(scoreBandLabel('excellent'), 'Çok uygun');
      expect(scoreBandLabel('good'), 'Uygun');
      expect(scoreBandLabel('fair'), 'Orta');
      expect(scoreBandLabel('poor'), 'Zayıf');
    });
  });

  group('tipografi ölçeği', () {
    // Kaynak: web/src/styles/tokens.css §7. Mobilde ölçek HİÇ yoktu;
    // ekranlar 10.5 / 11.5 / 12.5 / 13.5 / 17 / 18 / 20 / 25 px'i elle
    // yazıyordu.
    test('tracking boyuta göre yön değiştiriyor', () {
      // Büyük başlık NEGATİF (harfler optik olarak açılır), küçük etiket
      // POZİTİF (yoksa okunmaz). Tek bir letterSpacing her boyutta yanlış.
      expect(AppType.display.letterSpacing, lessThan(0));
      expect(AppType.h1.letterSpacing, lessThan(0));
      expect(AppType.body.letterSpacing, 0);
      expect(AppType.xs.letterSpacing, greaterThan(0));
      expect(AppType.micro.letterSpacing, greaterThan(0));
    });

    test('leading boyutla ters orantılı', () {
      expect(AppType.display.height! < AppType.h1.height!, isTrue);
      expect(AppType.h1.height! < AppType.body.height!, isTrue);
    });

    test('yalnızca pubspec\'te kayıtlı ağırlıklar kullanılıyor', () {
      // w800/w900 kayıtlı değil; Flutter onları sessizce 700'e düşürüyor.
      // "Burada daha kalın bir şey var" yanılgısı bu yüzden oluşuyordu.
      final registered = <FontWeight>{
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
      };
      for (final style in [
        AppType.display,
        AppType.h1,
        AppType.h2,
        AppType.h3,
        AppType.body,
        AppType.sm,
        AppType.xs,
        AppType.micro,
      ]) {
        expect(registered, contains(style.fontWeight));
      }
    });
  });

  group('tema', () {
    test('Poppins tüm uygulamaya tema üzerinden uygulanıyor', () {
      // Eskiden yalnızca giriş/kayıt ekranlarında elle yazılıydı; harita,
      // rota ve profil ekranları Android varsayılanıyla çiziliyordu.
      final theme = AppTheme.light;
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Poppins');
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Poppins');
    });

    test('zemin rengi web --bg ile aynı', () {
      expect(AppTheme.light.scaffoldBackgroundColor, AppColors.bg);
    });
  });

  group('POI kategori görünümü', () {
    test('renk tanımlı her kategorinin ikonu da var', () {
      // Renk ve ikon aynı şeyi anlatıyor: kategorinin haritada nasıl
      // göründüğü. Biri eklenip diğeri unutulursa POI rengiyle çizilir ama
      // ikonsuz kalır — çalışma zamanında hata vermez, sadece eksik görünür.
      for (final code in poiCategoryColors.keys) {
        expect(
          poiCategoryIconAssets,
          contains(code),
          reason: '"$code" kategorisinin rengi var ama ikonu yok',
        );
      }
    });

    test('ikon dosyalari diskte mevcut', () {
      // Harita ikon yüklemesi hatayı SESSİZCE yutuyor (tek bir ikon
      // yüzünden haritayı bozmanın anlamı yok). O sessizlik, dosya adı
      // yanlış yazıldığında kimseye bir şey söylemezdi.
      for (final asset in poiCategoryIconAssets.values.toSet()) {
        expect(File(asset).existsSync(), isTrue, reason: '$asset bulunamadı');
      }
      expect(File('assets/icons/home_kahve.svg').existsSync(), isTrue);
    });

    test('ikon klasoru pubspec icinde kayitli', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/icons/'));
    });
  });

  group('Çankaya sınırı varlığı', () {
    // Harita, sınırı yükleyemezse SESSİZCE devam ediyor (kullanıcıyı eksik
    // bir çizgi için uyarmanın anlamı yok). Bu sessizlik iyi bir çalışma
    // zamanı davranışı ama kötü bir geliştirme deneyimi: pubspec kaydı
    // unutulsa kimse fark etmez, sınır sadece "çıkmaz". Test o boşluğu
    // kapatıyor.
    // NOT: `rootBundle` ile okumuyoruz — `flutter test` varlık paketini
    // kurmadığı için orada her zaman düşerdi. Dosyayı diskten okuyup
    // pubspec kaydını ayrıca doğrulamak aynı iki gerçeği kanıtlıyor:
    // (1) dosya var ve geçerli, (2) uygulamaya paketleniyor.
    test('varlık pubspec.yaml içinde kayıtlı', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        contains('assets/geo/cankaya.geojson'),
        reason: 'pubspec kaydı yoksa sınır telefonda sessizce çizilmez',
      );
    });

    test('içinde çizilebilir bir poligon var', () {
      final raw = File('assets/geo/cankaya.geojson').readAsStringSync();
      final parsed = jsonDecode(raw) as Map<String, Object?>;
      final features =
          (parsed['features'] as List<Object?>)
              .whereType<Map<String, Object?>>()
              .toList();

      final polygons = features.where((f) {
        final type = (f['geometry'] as Map<String, Object?>?)?['type'];
        return type == 'Polygon' || type == 'MultiPolygon';
      });

      expect(polygons, isNotEmpty, reason: 'sınır poligonu bulunamadı');

      // Dosyada poligonun YANINDA bir de etiket Point'i var; harita bunu
      // ayıklıyor. Ayıklama gereksizleşirse (dosya değişirse) burayı da
      // güncelleyin — yoksa fill katmanı bir noktayı boyamaya çalışır.
      expect(
        features.length,
        greaterThan(polygons.length),
        reason: 'etiket Point kalktıysa haritadaki filtre gözden geçirilmeli',
      );
    });
  });

  group('mahalle katmanı varlığı', () {
    // Web haritada mahalle poligonlarını çiziyordu, mobil yalnızca ilçe
    // sınırını: kullanıcı hangi mahallede olduğunu göremiyordu.
    test('varlık pubspec.yaml içinde kayıtlı', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('assets/geo/cankaya-mahalleler.geojson'),
      );
    });

    test('çizilebilir poligonlar içeriyor', () {
      final raw =
          File('assets/geo/cankaya-mahalleler.geojson').readAsStringSync();
      final parsed = jsonDecode(raw) as Map<String, Object?>;
      final features = (parsed['features'] as List<Object?>).length;
      expect(features, greaterThan(10), reason: 'Çankaya\'da 10+ mahalle var');
    });
  });

  group('marka görselleri', () {
    // Persona ikonları mobilde jenerik Material glyph'leriyle çiziliyordu
    // (`Icons.school_outlined`), web ise kendi çizilmiş ikonlarını
    // kullanıyordu — aynı persona iki üründe iki farklı simge alıyordu.
    test('her personanın ana ve alt ikonları diskte mevcut', () {
      for (final code in [
        'student',
        'remote_worker',
        'family_kids',
        'elderly',
      ]) {
        final visual = personaVisual(code);
        expect(
          File('assets/icons/${visual.main}').existsSync(),
          isTrue,
          reason: '$code ana ikonu (${visual.main}) bulunamadı',
        );
        for (final sub in visual.sub) {
          expect(
            File('assets/icons/$sub').existsSync(),
            isTrue,
            reason: '$code alt ikonu ($sub) bulunamadı',
          );
        }
      }
    });

    test('bilinmeyen persona kırık görsel değil nötr ikon döner', () {
      final visual = personaVisual('bir-gun-eklenen-persona');
      expect(File('assets/icons/${visual.main}').existsSync(), isTrue);
    });

    test('haritadaki favori yıldızı ve konut ikonu mevcut', () {
      // Favori EKLEME düğmesi kalp, HARİTADAKİ işaret yıldız — ikisi de
      // bilinçli (bkz. favorite_button.dart). Yıldız haritada altın bir
      // daire üstünde beyaz çiziliyor.
      expect(File('assets/icons/star_white.svg').existsSync(), isTrue);
      expect(File('assets/icons/star_kahve.svg').existsSync(), isTrue);
      expect(File('assets/icons/home_white.svg').existsSync(), isTrue);
    });

    test('maskot görselleri mevcut ve pubspec\'te kayıtlı', () {
      for (final pose in ['mascot', 'mascot_2', 'mascot_on_the_wall']) {
        expect(
          File('assets/mascot/$pose.png').existsSync(),
          isTrue,
          reason: '$pose.png bulunamadı',
        );
      }
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('assets/mascot/'),
      );
    });
  });
}
