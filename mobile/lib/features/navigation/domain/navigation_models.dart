import '../../routes/domain/route_models.dart';

enum NavigationPhase { starting, following, offRoute, finished, lost }

enum NavigationPermissionState {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class NavigationCoordinate {
  const NavigationCoordinate({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.headingDegrees,
    this.speedMps,
  });

  final double latitude;
  final double longitude;
  final double? accuracyM;
  final double? headingDegrees;
  final double? speedMps;
}

abstract interface class NavigationLocationGateway {
  Future<NavigationPermissionState> ensurePermission();

  Stream<NavigationCoordinate> watch();

  Future<void> openAppSettings();

  Future<void> openLocationSettings();
}

class NavigationStepRef {
  const NavigationStepRef({required this.legSequence, required this.step});

  final int legSequence;
  final RouteStep step;
}

List<NavigationStepRef> flattenRouteSteps(RouteDetail route) => [
  for (final leg in route.legs)
    for (final step in leg.steps)
      NavigationStepRef(legSequence: leg.sequence, step: step),
];
