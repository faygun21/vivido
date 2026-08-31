import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../../location/application/user_location_controller.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';
import '../../../routes/domain/route_models.dart';
import '../../application/navigation_controller.dart';
import '../../data/geolocator_navigation_location_gateway.dart';
import '../../domain/maneuver_text.dart';
import '../../domain/navigation_models.dart';
import '../widgets/maneuver_banner.dart';
import '../widgets/next_stop_sheet.dart';
import '../widgets/off_route_banner.dart';

typedef NavigationRouteRecalculator =
    Future<RouteDetail?> Function(NavigationCoordinate position);

class NavigationPage extends StatefulWidget {
  const NavigationPage({
    required this.route,
    this.controller,
    this.onRecalculate,
    super.key,
  });

  final RouteDetail route;
  final NavigationController? controller;
  final NavigationRouteRecalculator? onRecalculate;

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  late NavigationController _controller;
  late RouteDetail _route;
  late final bool _ownsController;
  bool _recalculating = false;

  @override
  void initState() {
    super.initState();
    _route = widget.route;
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? _createController(_route);
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.start());
  }

  NavigationController _createController(RouteDetail route) =>
      NavigationController(
        route: route,
        locationGateway: GeolocatorNavigationLocationGateway(),
      );

  Future<void> _recalculate() async {
    final position = _controller.position;
    final callback = widget.onRecalculate;
    if (position == null || callback == null || _recalculating) return;
    setState(() => _recalculating = true);
    final replacement = await callback(position);
    if (!mounted) return;
    if (replacement == null) {
      setState(() => _recalculating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rota yeniden oluşturulamadı.')),
      );
      return;
    }
    final oldController = _controller;
    setState(() {
      _route = replacement;
      _controller = _createController(replacement);
      _recalculating = false;
    });
    oldController.dispose();
    await _controller.start();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Navigasyon'),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('Bitir'),
        ),
      ],
    ),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.status == NavigationStatus.requestingPermission ||
              _controller.status == NavigationStatus.idle) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.status == NavigationStatus.blocked ||
              _controller.status == NavigationStatus.failed) {
            return _NavigationBlocked(
              message: _controller.errorMessage ?? 'Navigasyon başlatılamadı.',
              showSettings:
                  _controller.status == NavigationStatus.blocked &&
                  _controller.permissionState !=
                      NavigationPermissionState.denied,
              onSettings: _controller.openRequiredSettings,
              onRetry: _controller.start,
            );
          }

          final position = _controller.position;
          final step = _controller.activeStep;
          final instruction =
              step == null
                  ? null
                  : maneuverInstruction(
                    step.maneuver,
                    roadName: step.name,
                    isLastStep:
                        _controller.progress.stopSequence >= _route.stopCount,
                  );
          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    8,
                    _controller.progress.offRoute || _controller.weakSignal
                        ? 164
                        : 112,
                    8,
                    126,
                  ),
                  child: CankayaMap(
                    anchors: const [],
                    route: _route,
                    followUserLocation: _controller.cameraFollows,
                    followTarget:
                        position == null || !_controller.cameraFollows
                            ? null
                            : Geographic(
                              lon: position.longitude,
                              lat: position.latitude,
                            ),
                    followBearing: position?.headingDegrees,
                    traveledUpToIndex: _controller.progress.traveledUpToIndex,
                    onCameraFollowInterrupted: _controller.pauseCameraFollow,
                    userBearing: position?.headingDegrees,
                    userLocation:
                        position == null
                            ? null
                            : UserLocation(
                              latitude: position.latitude,
                              longitude: position.longitude,
                              accuracyM: position.accuracyM,
                            ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: ManeuverBanner(
                  instruction: instruction,
                  distanceM: _controller.progress.distanceToManeuverM,
                  roadName: step?.name,
                ),
              ),
              if (_controller.progress.offRoute)
                Positioned(
                  top: 92,
                  left: 16,
                  right: 16,
                  child: OffRouteBanner(
                    distanceM: _controller.progress.offRouteDistanceM,
                    recalculating: _recalculating,
                    onRecalculate:
                        widget.onRecalculate == null ? null : _recalculate,
                  ),
                )
              else if (_controller.weakSignal)
                const Positioned(
                  top: 92,
                  left: 16,
                  right: 16,
                  child: _WeakSignalBanner(),
                ),
              if (!_controller.cameraFollows && position != null)
                Positioned(
                  left: 20,
                  bottom: 142,
                  child: _RecenterButton(onPressed: _controller.recenter),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: NextStopSheet(
                  stop: _controller.targetStop,
                  totalStops: _route.stopCount,
                  distanceM: _controller.progress.distanceToStopM,
                  etaSeconds: _controller.progress.etaSecondsToStop,
                  arrived: _controller.progress.arrivedAtStop,
                ),
              ),
              if (_controller.progress.finished) const _FinishedOverlay(),
            ],
          );
        },
      ),
    ),
  );
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 4,
    color: Theme.of(context).colorScheme.surface,
    shadowColor: Colors.black38,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(24),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.navigation, size: 20, color: Color(0xFF0F766E)),
            SizedBox(width: 7),
            Text(
              'Ortala',
              style: TextStyle(
                color: Color(0xFF0F766E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FinishedOverlay extends StatelessWidget {
  const _FinishedOverlay();

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flag_circle, size: 54),
                const SizedBox(height: 12),
                const Text(
                  'Rota tamamlandı',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Bitir'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _WeakSignalBanner extends StatelessWidget {
  const _WeakSignalBanner();

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF3E8),
    borderRadius: BorderRadius.circular(12),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.gps_off, size: 19),
          SizedBox(width: 8),
          Expanded(child: Text('GPS sinyali zayıf. Açık bir alana geç.')),
        ],
      ),
    ),
  );
}

class _NavigationBlocked extends StatelessWidget {
  const _NavigationBlocked({
    required this.message,
    required this.showSettings,
    required this.onSettings,
    required this.onRetry,
  });

  final String message;
  final bool showSettings;
  final Future<void> Function() onSettings;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_outlined, size: 52),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          if (showSettings)
            FilledButton.tonal(
              onPressed: onSettings,
              child: const Text('Ayarları aç'),
            ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    ),
  );
}
