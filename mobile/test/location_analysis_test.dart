import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivido_mobile/features/location_analysis/domain/location_analysis.dart';
import 'package:vivido_mobile/features/location_analysis/presentation/widgets/location_analysis_controls.dart';

void main() {
  group('konum analizi', () {
    test('web ile aynı seçenekleri ve yürüme hızını kullanır', () {
      expect(analysisRadiusOptionsKm, [0.5, 1, 2, 3, 5]);
      expect(walkingMinuteOptions, [5, 10, 15, 20, 30]);
      expect(walkingRadiusMetres(15), 1200);
    });

    test('kapalı ve jeodezik yarıçapa uygun halka üretir', () {
      const center = AnalysisCoordinate(latitude: 39.87, longitude: 32.85);
      final ring = createRadiusRing(
        center: center,
        radiusMetres: 2000,
        segments: 72,
      );

      expect(ring, hasLength(73));
      expect(ring.last.latitude, closeTo(ring.first.latitude, 1e-12));
      expect(ring.last.longitude, closeTo(ring.first.longitude, 1e-12));
      expect(_distanceMetres(center, ring.first), closeTo(2000, 0.5));
    });
  });

  testWidgets('kompakt gösterge ayarları açar ve alanı temizler', (
    tester,
  ) async {
    var opened = false;
    var cleared = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationAnalysisLauncher(
            hasSelectedLocation: true,
            analysisRadiusKm: 2,
            walkingMinutes: 15,
            onOpen: () => opened = true,
            onClear: () => cleared = true,
          ),
        ),
      ),
    );

    expect(find.text('2 km · 15 dk'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-location-analysis')));
    expect(opened, isTrue);

    await tester.tap(find.byKey(const Key('clear-location-analysis')));
    expect(cleared, isTrue);
  });

  testWidgets('alt panel seçimleri yalnızca uygula ile döndürür', (
    tester,
  ) async {
    LocationAnalysisSettings? applied;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    applied = await showLocationAnalysisSettingsSheet(
                      context,
                      analysisRadiusKm: 2,
                      walkingMinutes: 15,
                    );
                  },
                  child: const Text('Ayarları aç'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Ayarları aç'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('analysis-radius-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 km').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('walking-minutes-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 dk').last);
    await tester.pumpAndSettle();

    expect(applied, isNull);
    await tester.tap(find.byKey(const Key('apply-location-analysis')));
    await tester.pumpAndSettle();

    expect(applied?.analysisRadiusKm, 5);
    expect(applied?.walkingMinutes, 30);
  });
}

double _distanceMetres(AnalysisCoordinate start, AnalysisCoordinate end) {
  const earthRadius = 6371008.8;
  final startLat = start.latitude * math.pi / 180;
  final endLat = end.latitude * math.pi / 180;
  final deltaLat = (end.latitude - start.latitude) * math.pi / 180;
  final deltaLon = (end.longitude - start.longitude) * math.pi / 180;
  final haversine =
      math.pow(math.sin(deltaLat / 2), 2) +
      math.cos(startLat) *
          math.cos(endLat) *
          math.pow(math.sin(deltaLon / 2), 2);
  return earthRadius *
      2 *
      math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
}
