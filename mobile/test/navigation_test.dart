import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vivido_mobile/features/navigation/application/navigation_controller.dart';
import 'package:vivido_mobile/features/navigation/domain/geo_math.dart';
import 'package:vivido_mobile/features/navigation/domain/maneuver_text.dart';
import 'package:vivido_mobile/features/navigation/domain/navigation_models.dart';
import 'package:vivido_mobile/features/navigation/domain/navigation_progress.dart';
import 'package:vivido_mobile/features/routes/domain/route_models.dart';

void main() {
  group('coğrafi hesaplar', () {
    test('haversine aynı noktada sıfır, 1 derece enlemde yaklaşık 111 km', () {
      expect(haversineM(39.9, 32.8, 39.9, 32.8), closeTo(0, 0.01));
      expect(haversineM(39, 32, 40, 32), closeTo(111195, 250));
    });

    test('nokta-segment ve polyline en yakın mesafeyi bulur', () {
      const line = [
        [32.8, 39.9],
        [32.8, 39.901],
        [32.801, 39.901],
      ];
      final segment = distanceToSegmentM(
        const [32.8001, 39.9005],
        line[0],
        line[1],
      );
      final polyline = distanceToPolylineM(const [32.8001, 39.9005], line);
      expect(segment.distanceM, inInclusiveRange(7, 11));
      expect(polyline.distanceM, closeTo(segment.distanceM, 0.1));
      expect(polyline.segmentIndex, 0);
    });

    test('bearing kuzey ve doğu yönlerini doğru verir', () {
      expect(
        bearingDeg(const [32.8, 39.9], const [32.8, 40.0]),
        closeTo(0, 0.1),
      );
      expect(
        bearingDeg(const [32.8, 39.9], const [32.9, 39.9]),
        closeTo(90, 0.1),
      );
    });
  });

  group('OSRM Türkçe manevra tablosu', () {
    final cases = <(String, String?, int?, String)>[
      ('depart', null, null, 'Yola çık'),
      ('arrive', null, null, 'Konuta ulaştın'),
      ('turn', 'left', null, 'Sola dön'),
      ('turn', 'right', null, 'Sağa dön'),
      ('turn', 'slight left', null, 'Hafif sola dön'),
      ('turn', 'slight right', null, 'Hafif sağa dön'),
      ('turn', 'sharp left', null, 'Keskin sola dön'),
      ('turn', 'sharp right', null, 'Keskin sağa dön'),
      ('turn', 'uturn', null, 'U dönüşü yap'),
      ('continue', 'straight', null, 'Düz devam et'),
      ('merge', 'left', null, 'Sol şeride geç'),
      ('on ramp', null, null, 'Bağlantı yoluna gir'),
      ('off ramp', null, null, 'Çıkışa gir'),
      ('fork', 'right', null, 'Yol ayrımında sağı izle'),
      ('end of road', 'left', null, 'Yolun sonunda sola dön'),
      ('roundabout', null, 3, 'Kavşaktan 3. çıkışı kullan'),
      ('rotary', null, null, 'Kavşağa gir'),
      ('notification', null, null, 'Test Yolu üzerinde devam et'),
      ('unknown', null, null, 'Test Yolu üzerinde devam et'),
    ];

    for (final entry in cases) {
      test('${entry.$1}/${entry.$2 ?? '-'}', () {
        expect(
          maneuverText(_step(entry.$1, modifier: entry.$2, exit: entry.$3)),
          entry.$4,
        );
      });
    }
  });

  group('navigasyon ilerlemesi', () {
    test('yüksek doğruluk hatalı konumu hesaplamalarda yok sayar', () {
      const previous = NavigationProgress(currentStepIndex: 1);
      final result = advanceNavigation(
        route: _route,
        position: const NavigationCoordinate(
          latitude: 39.91,
          longitude: 32.81,
          accuracyM: 36,
        ),
        previous: previous,
      );
      expect(identical(result, previous), isTrue);
    });

    test('50 metre dışındaki üçüncü ardışık fix sapma üretir', () {
      const far = NavigationCoordinate(latitude: 39.91, longitude: 32.81);
      var progress = const NavigationProgress();
      for (var i = 0; i < 2; i++) {
        progress = advanceNavigation(
          route: _route,
          position: far,
          previous: progress,
        );
        expect(progress.offRoute, isFalse);
      }
      progress = advanceNavigation(
        route: _route,
        position: far,
        previous: progress,
      );
      expect(progress.offRoute, isTrue);
      expect(progress.offRouteDistanceM, greaterThan(50));
    });

    test('30 metre içine dönünce sapmayı kapatır', () {
      final result = advanceNavigation(
        route: _route,
        position: const NavigationCoordinate(
          latitude: 39.9004,
          longitude: 32.8,
        ),
        previous: const NavigationProgress(offRoute: true, offRouteStreak: 3),
      );
      expect(result.offRoute, isFalse);
      expect(result.offRouteStreak, 0);
    });

    test('manevraya 15 metreden yaklaşınca adımı ilerletir', () {
      final result = advanceNavigation(
        route: _route,
        position: const NavigationCoordinate(latitude: 39.901, longitude: 32.8),
        previous: const NavigationProgress(),
      );
      expect(result.currentStepIndex, greaterThanOrEqualTo(1));
    });

    test('40 metre içindeki durağa varınca sonraki durağa geçer', () {
      final result = advanceNavigation(
        route: _route,
        position: const NavigationCoordinate(latitude: 39.902, longitude: 32.8),
        previous: const NavigationProgress(),
      );
      expect(result.arrivedAtStop, isTrue);
      expect(result.stopSequence, 2);
      expect(result.finished, isFalse);
    });
  });

  group('NavigationController', () {
    test('izin reddedilirse GPS akışı başlamaz', () async {
      final gateway = _FakeLocationGateway(NavigationPermissionState.denied);
      final controller = NavigationController(
        route: _route,
        locationGateway: gateway,
      );
      addTearDown(controller.dispose);
      await controller.start();
      expect(controller.status, NavigationStatus.blocked);
      expect(controller.errorMessage, contains('konum izni'));
      expect(gateway.watchCount, 0);
    });

    test(
      'GPS fix ile following durumuna geçer ve dispose aboneliği kapatır',
      () async {
        final gateway = _FakeLocationGateway(NavigationPermissionState.granted);
        final controller = NavigationController(
          route: _route,
          locationGateway: gateway,
        );
        await controller.start();
        gateway.add(
          const NavigationCoordinate(
            latitude: 39.9002,
            longitude: 32.8,
            accuracyM: 5,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(controller.status, NavigationStatus.tracking);
        expect(controller.phase, NavigationPhase.following);
        controller.dispose();
        await Future<void>.delayed(Duration.zero);
        expect(gateway.cancelled, isTrue);
        await gateway.close();
      },
    );

    test('harita kaydırılınca takip durur, ortala ile yeniden başlar', () {
      final gateway = _FakeLocationGateway(NavigationPermissionState.granted);
      final controller = NavigationController(
        route: _route,
        locationGateway: gateway,
      );
      addTearDown(controller.dispose);

      expect(controller.cameraFollows, isTrue);
      controller.pauseCameraFollow();
      expect(controller.cameraFollows, isFalse);
      controller.recenter();
      expect(controller.cameraFollows, isTrue);
    });
  });

  test(
    'RouteStep geometrisi JSON dönüşünde GeoJSON lon-lat sırasını korur',
    () {
      const json = <String, dynamic>{
        'distance': 50,
        'duration': 10,
        'name': 'Yol',
        'maneuver': <String, dynamic>{
          'type': 'turn',
          'location': <double>[32.8, 39.9],
        },
        'geometry': <String, dynamic>{
          'type': 'LineString',
          'coordinates': <List<double>>[
            [32.8, 39.9],
            [32.81, 39.91],
          ],
        },
      };
      final step = RouteStep.fromJson(json);
      expect(step.geometry, json['geometry']!['coordinates']);
      expect(step.toJson()['geometry'], json['geometry']);
    },
  );
}

RouteStep _step(String type, {String? modifier, int? exit}) => RouteStep(
  distance: 100,
  duration: 20,
  name: 'Test Yolu',
  geometry: const [
    [32.8, 39.9],
    [32.8, 39.901],
  ],
  maneuver: RouteManeuver(
    type: type,
    modifier: modifier,
    exit: exit,
    location: const [32.8, 39.901],
  ),
);

final _route = RouteDetail(
  id: 'route-1',
  name: 'Test rotası',
  start: const RouteStart(latitude: 39.9, longitude: 32.8, label: 'Başlangıç'),
  mode: RouteTravelMode.car,
  totalDistanceM: 600,
  totalDurationS: 120,
  stopCount: 2,
  geometry: const [
    [32.8, 39.9],
    [32.8, 39.901],
    [32.8, 39.902],
    [32.801, 39.903],
  ],
  stops: const [
    RouteStop(
      sequence: 1,
      propertyId: 41,
      property: RouteStopProperty(
        monthlyRent: 20000,
        areaM2: 90,
        roomCount: '2+1',
        latitude: 39.902,
        longitude: 32.8,
      ),
    ),
    RouteStop(
      sequence: 2,
      propertyId: 42,
      property: RouteStopProperty(
        monthlyRent: 22000,
        areaM2: 100,
        roomCount: '3+1',
        latitude: 39.903,
        longitude: 32.801,
      ),
    ),
  ],
  legs: [
    RouteLeg(
      sequence: 1,
      steps: [
        _step('depart'),
        RouteStep(
          distance: 150,
          duration: 30,
          name: 'Birinci Yol',
          geometry: const [
            [32.8, 39.901],
            [32.8, 39.902],
          ],
          maneuver: const RouteManeuver(
            type: 'turn',
            modifier: 'right',
            location: [32.8, 39.901],
          ),
        ),
      ],
    ),
    RouteLeg(
      sequence: 2,
      steps: [
        RouteStep(
          distance: 200,
          duration: 40,
          name: 'İkinci Yol',
          geometry: const [
            [32.8, 39.902],
            [32.801, 39.903],
          ],
          maneuver: const RouteManeuver(
            type: 'depart',
            location: [32.8, 39.902],
          ),
        ),
      ],
    ),
  ],
  createdAt: DateTime.utc(2026, 8, 31),
);

class _FakeLocationGateway implements NavigationLocationGateway {
  _FakeLocationGateway(this.permission) {
    controller = StreamController<NavigationCoordinate>.broadcast(
      onCancel: () => cancelled = true,
    );
  }

  final NavigationPermissionState permission;
  late final StreamController<NavigationCoordinate> controller;
  int watchCount = 0;
  bool cancelled = false;

  void add(NavigationCoordinate coordinate) => controller.add(coordinate);

  @override
  Future<NavigationPermissionState> ensurePermission() async => permission;

  @override
  Stream<NavigationCoordinate> watch() {
    watchCount++;
    return controller.stream;
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}

  Future<void> close() => controller.close();
}
