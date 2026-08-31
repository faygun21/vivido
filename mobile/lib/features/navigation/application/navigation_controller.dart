import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../routes/domain/route_models.dart';
import '../domain/navigation_models.dart';
import '../domain/navigation_progress.dart';

enum NavigationStatus { idle, requestingPermission, tracking, blocked, failed }

class NavigationController extends ChangeNotifier {
  NavigationController({required this.route, required this.locationGateway});

  final RouteDetail route;
  final NavigationLocationGateway locationGateway;

  NavigationStatus status = NavigationStatus.idle;
  NavigationPhase phase = NavigationPhase.starting;
  NavigationPermissionState? permissionState;
  NavigationCoordinate? position;
  NavigationProgress progress = const NavigationProgress();
  String? errorMessage;
  bool cameraFollows = true;
  bool weakSignal = false;

  StreamSubscription<NavigationCoordinate>? _subscription;
  Timer? _signalTimer;
  bool _disposed = false;

  RouteLeg? get activeLeg =>
      route.legs
          .where((leg) => leg.sequence == progress.stopSequence)
          .firstOrNull;

  RouteStep? get activeStep {
    final steps = activeLeg?.steps ?? const <RouteStep>[];
    if (steps.isEmpty) return null;
    // OSRM manevrası adımın başında bulunduğu için sıradaki eylem i+1'dir.
    final index = math.min(progress.currentStepIndex + 1, steps.length - 1);
    return steps[index];
  }

  RouteStop? get targetStop =>
      route.stops
          .where((stop) => stop.sequence == progress.stopSequence)
          .firstOrNull;

  Future<void> start() async {
    if (status == NavigationStatus.requestingPermission ||
        status == NavigationStatus.tracking) {
      return;
    }
    if (route.stopCount < 2 || route.legs.every((leg) => leg.steps.isEmpty)) {
      status = NavigationStatus.failed;
      phase = NavigationPhase.lost;
      errorMessage =
          route.stopCount < 2
              ? 'Navigasyon için rotada en az iki konut bulunmalıdır.'
              : 'Bu rota için manevra bilgisi bulunmuyor.';
      _notify();
      return;
    }

    status = NavigationStatus.requestingPermission;
    phase = NavigationPhase.starting;
    errorMessage = null;
    _notify();
    try {
      permissionState = await locationGateway.ensurePermission();
      if (permissionState != NavigationPermissionState.granted) {
        status = NavigationStatus.blocked;
        phase = NavigationPhase.lost;
        errorMessage = switch (permissionState!) {
          NavigationPermissionState.denied =>
            'Navigasyonu başlatmak için konum izni vermelisin.',
          NavigationPermissionState.deniedForever =>
            'Konum izni kapalı. Uygulama ayarlarından izni açmalısın.',
          NavigationPermissionState.serviceDisabled =>
            'Telefonun konum servisi kapalı. Konumu açıp tekrar dene.',
          NavigationPermissionState.granted => null,
        };
        _notify();
        return;
      }

      await _subscription?.cancel();
      _subscription = locationGateway.watch().listen(
        _onPosition,
        onError: (_) {
          status = NavigationStatus.failed;
          phase = NavigationPhase.lost;
          weakSignal = true;
          errorMessage = 'Konum sinyali kayboldu. Konum servisini kontrol et.';
          _notify();
        },
      );
      status = NavigationStatus.tracking;
      _armSignalTimer();
      await _enableWakeLock();
      _notify();
    } on Object {
      status = NavigationStatus.failed;
      phase = NavigationPhase.lost;
      errorMessage = 'Navigasyon başlatılamadı.';
      _notify();
    }
  }

  void _onPosition(NavigationCoordinate value) {
    position = value;
    weakSignal = (value.accuracyM ?? 0) > maxUsableAccuracyM;
    _armSignalTimer();
    if (!weakSignal) {
      progress = advanceNavigation(
        route: route,
        position: value,
        previous: progress,
      );
      phase =
          progress.finished
              ? NavigationPhase.finished
              : progress.offRoute
              ? NavigationPhase.offRoute
              : NavigationPhase.following;
    }
    _notify();
  }

  void pauseCameraFollow() {
    if (!cameraFollows) return;
    cameraFollows = false;
    _notify();
  }

  void recenter() {
    cameraFollows = true;
    _notify();
  }

  void _armSignalTimer() {
    _signalTimer?.cancel();
    _signalTimer = Timer(const Duration(seconds: 12), () {
      weakSignal = true;
      if (phase != NavigationPhase.finished) phase = NavigationPhase.lost;
      errorMessage = 'Konum sinyali zayıf. Açık bir alana geçmeyi dene.';
      _notify();
    });
  }

  Future<void> openRequiredSettings() async {
    if (permissionState == NavigationPermissionState.serviceDisabled) {
      await locationGateway.openLocationSettings();
    } else {
      await locationGateway.openAppSettings();
    }
  }

  Future<void> stop() async {
    _signalTimer?.cancel();
    _signalTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    position = null;
    status = NavigationStatus.idle;
    await _disableWakeLock();
  }

  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
    } on Object {
      // Wakelock navigasyonun doğruluğunu etkilemez; platform desteklemiyorsa
      // GPS akışı çalışmaya devam etmelidir.
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      await WakelockPlus.disable();
    } on Object {
      // Ekran kapanırken platform kanalı artık hazır olmayabilir.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _signalTimer?.cancel();
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    _subscription = null;
    position = null;
    unawaited(_disableWakeLock());
    super.dispose();
  }
}
