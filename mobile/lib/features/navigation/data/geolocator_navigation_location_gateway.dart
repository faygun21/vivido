import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/navigation_models.dart';

class GeolocatorNavigationLocationGateway implements NavigationLocationGateway {
  @override
  Future<NavigationPermissionState> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return NavigationPermissionState.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => NavigationPermissionState.granted,
      LocationPermission.deniedForever =>
        NavigationPermissionState.deniedForever,
      _ => NavigationPermissionState.denied,
    };
  }

  @override
  Stream<NavigationCoordinate> watch() {
    final settings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        intervalDuration: Duration(seconds: 1),
      ),
      TargetPlatform.iOS || TargetPlatform.macOS => AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
      ),
      _ => const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    };
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (position) => NavigationCoordinate(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
        headingDegrees:
            position.heading.isFinite && position.heading >= 0
                ? position.heading
                : null,
        speedMps:
            position.speed.isFinite && position.speed >= 0
                ? position.speed
                : null,
      ),
    );
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
