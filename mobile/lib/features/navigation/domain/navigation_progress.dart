import 'dart:math' as math;

import '../../routes/domain/route_models.dart';
import 'geo_math.dart';
import 'navigation_models.dart';

const offRouteThresholdM = 50.0;
const backOnRouteThresholdM = 30.0;
const offRouteConsecutiveFixes = 3;
const maxUsableAccuracyM = 35.0;
const maneuverAdvanceM = 15.0;
const stopArrivalM = 40.0;
const navigationAreaLimitM = 10000.0;

class NavigationProgress {
  const NavigationProgress({
    this.stopSequence = 1,
    this.currentStepIndex = 0,
    this.distanceToManeuverM,
    this.distanceToStopM,
    this.etaSecondsToStop,
    this.offRouteDistanceM = 0,
    this.offRoute = false,
    this.offRouteStreak = 0,
    this.arrivedAtStop = false,
    this.finished = false,
    this.traveledUpToIndex = 0,
    this.remainingRouteDistanceM,
    this.outsideNavigationArea = false,
  });

  final int stopSequence;
  final int currentStepIndex;
  final double? distanceToManeuverM;
  final double? distanceToStopM;
  final int? etaSecondsToStop;
  final double offRouteDistanceM;
  final bool offRoute;
  final int offRouteStreak;
  final bool arrivedAtStop;
  final bool finished;
  final int traveledUpToIndex;
  final double? remainingRouteDistanceM;
  final bool outsideNavigationArea;

  @Deprecated('Use currentStepIndex')
  int get activeStepIndex => currentStepIndex;

  @Deprecated('Use offRouteDistanceM')
  double get distanceFromRouteM => offRouteDistanceM;
}

NavigationProgress advanceNavigation({
  required RouteDetail route,
  required NavigationCoordinate position,
  required NavigationProgress previous,
}) {
  if (route.legs.isEmpty || route.stops.isEmpty) return previous;
  if ((position.accuracyM ?? 0) > maxUsableAccuracyM) return previous;

  var stopSequence = previous.stopSequence.clamp(1, route.stops.length);
  var currentStepIndex = previous.currentStepIndex;
  var arrivedAtStop = false;
  var finished = previous.finished;
  var leg = _legFor(route, stopSequence);
  var stop = _stopFor(route, stopSequence);
  if (leg == null || stop == null || leg.steps.isEmpty) return previous;

  currentStepIndex = currentStepIndex.clamp(0, leg.steps.length - 1);
  final point = [position.longitude, position.latitude];

  // Yalnızca mevcut ve sonraki adımı karşılaştırmak GPS gürültüsünde
  // ilerlemenin önceki adımlara geri sıçramasını önler.
  if (currentStepIndex + 1 < leg.steps.length) {
    final currentDistance = _distanceToStep(point, leg.steps[currentStepIndex]);
    final nextDistance = _distanceToStep(
      point,
      leg.steps[currentStepIndex + 1],
    );
    if (nextDistance + 3 < currentDistance) currentStepIndex++;
  }

  // OSRM manevrası adımın başındadır. Kullanıcıya mevcut yolun sonunda
  // yapılacak eylem, yani i+1 adımının manevrası gösterilir.
  var instructionIndex = math.min(currentStepIndex + 1, leg.steps.length - 1);
  var instruction = leg.steps[instructionIndex];
  var distanceToManeuver = _distanceToManeuver(position, instruction);
  if (distanceToManeuver < maneuverAdvanceM &&
      currentStepIndex < leg.steps.length - 1) {
    currentStepIndex++;
    instructionIndex = math.min(currentStepIndex + 1, leg.steps.length - 1);
    instruction = leg.steps[instructionIndex];
    distanceToManeuver = _distanceToManeuver(position, instruction);
  }

  var distanceToStop = haversineM(
    position.latitude,
    position.longitude,
    stop.property.latitude,
    stop.property.longitude,
  );
  if (distanceToStop < stopArrivalM) {
    arrivedAtStop = true;
    if (stopSequence >= route.stops.length) {
      finished = true;
    } else {
      stopSequence++;
      currentStepIndex = 0;
      final nextLeg = _legFor(route, stopSequence);
      final nextStop = _stopFor(route, stopSequence);
      if (nextLeg == null || nextStop == null || nextLeg.steps.isEmpty) {
        return NavigationProgress(
          stopSequence: stopSequence,
          arrivedAtStop: true,
          finished: true,
          traveledUpToIndex: previous.traveledUpToIndex,
        );
      }
      leg = nextLeg;
      stop = nextStop;
      instructionIndex = math.min(1, leg.steps.length - 1);
      instruction = leg.steps[instructionIndex];
      distanceToManeuver = _distanceToManeuver(position, instruction);
      distanceToStop = haversineM(
        position.latitude,
        position.longitude,
        stop.property.latitude,
        stop.property.longitude,
      );
    }
  }

  final activeGeometry = _legGeometry(leg, fallback: route.geometry);
  final snap = distanceToPolylineM(point, activeGeometry);
  final fullSnap = distanceToPolylineM(point, route.geometry);
  final outsideNavigationArea = snap.distanceM > navigationAreaLimitM;

  var offRoute = previous.offRoute;
  var streak = previous.offRouteStreak;
  if (offRoute) {
    if (snap.distanceM < backOnRouteThresholdM) {
      offRoute = false;
      streak = 0;
    }
  } else if (snap.distanceM > offRouteThresholdM) {
    streak++;
    offRoute = streak >= offRouteConsecutiveFixes;
  } else {
    streak = 0;
  }

  final remaining = _remainingDistance(
    leg: leg,
    currentStepIndex: currentStepIndex,
    distanceToManeuverM: distanceToManeuver,
  );
  final legDistance = leg.steps.fold<double>(
    0,
    (sum, step) => sum + step.distance,
  );
  final legDuration = leg.steps.fold<double>(
    0,
    (sum, step) => sum + step.duration,
  );
  final eta =
      legDistance <= 0 ? null : (legDuration * remaining / legDistance).round();

  return NavigationProgress(
    stopSequence: stopSequence,
    currentStepIndex: currentStepIndex,
    distanceToManeuverM: outsideNavigationArea ? null : distanceToManeuver,
    distanceToStopM: distanceToStop,
    etaSecondsToStop: eta,
    offRouteDistanceM: snap.distanceM,
    offRoute: offRoute,
    offRouteStreak: streak,
    arrivedAtStop: arrivedAtStop,
    finished: finished,
    traveledUpToIndex: math.max(0, fullSnap.segmentIndex),
    remainingRouteDistanceM: remaining,
    outsideNavigationArea: outsideNavigationArea,
  );
}

RouteLeg? _legFor(RouteDetail route, int sequence) =>
    route.legs.where((leg) => leg.sequence == sequence).firstOrNull;

RouteStop? _stopFor(RouteDetail route, int sequence) =>
    route.stops.where((stop) => stop.sequence == sequence).firstOrNull;

List<List<double>> _legGeometry(
  RouteLeg leg, {
  required List<List<double>> fallback,
}) {
  final geometry = [for (final step in leg.steps) ...step.geometry];
  return geometry.length >= 2 ? geometry : fallback;
}

double _distanceToStep(List<double> point, RouteStep step) {
  if (step.geometry.length >= 2) {
    return distanceToPolylineM(point, step.geometry).distanceM;
  }
  final location = step.maneuver.location;
  return location.length < 2
      ? double.infinity
      : haversineM(point[1], point[0], location[1], location[0]);
}

double _distanceToManeuver(NavigationCoordinate position, RouteStep step) {
  final location = step.maneuver.location;
  if (location.length < 2) return step.distance;
  return haversineM(
    position.latitude,
    position.longitude,
    location[1],
    location[0],
  );
}

double _remainingDistance({
  required RouteLeg leg,
  required int currentStepIndex,
  required double distanceToManeuverM,
}) {
  var total = math.min(
    distanceToManeuverM,
    leg.steps[currentStepIndex].distance,
  );
  for (final step in leg.steps.skip(currentStepIndex + 1)) {
    total += step.distance;
  }
  return total;
}
