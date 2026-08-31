import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivido_mobile/core/theme/app_colors.dart';
import 'package:vivido_mobile/core/theme/app_theme.dart';
import 'package:vivido_mobile/features/map_data/presentation/poi_category_colors.dart';

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
      expect(AppColors.band(100), AppColors.bandExcellent);
      expect(AppColors.band(85), AppColors.bandExcellent);
      expect(AppColors.band(84.9), AppColors.bandGood);

      expect(AppColors.band(70), AppColors.bandGood);
      expect(AppColors.band(69.9), AppColors.bandFair);

      expect(AppColors.band(55), AppColors.bandFair);
      expect(AppColors.band(54.9), AppColors.bandPoor);

      expect(AppColors.band(0), AppColors.bandPoor);
    });

    test('bant renkleri web rozet renkleriyle birebir', () {
      expect(AppColors.bandExcellent, const Color(0xFF15803D));
      expect(AppColors.bandGood, const Color(0xFF4D7C0F));
      expect(AppColors.bandFair, const Color(0xFFB45309));
      expect(AppColors.bandPoor, const Color(0xFF9A3412));
    });

    test('etiketler bant sınırlarıyla tutarlı', () {
      expect(AppColors.bandLabel(90), 'Çok iyi');
      expect(AppColors.bandLabel(75), 'İyi');
      expect(AppColors.bandLabel(60), 'Orta');
      expect(AppColors.bandLabel(20), 'Zayıf');
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
}
