import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/mascot.dart';
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
          final media = MediaQuery.of(context);

          // ── IZGARA ────────────────────────────────────────────────
          // Harita TAM EKRAN; şeritler ve kart onun üstünde yüzüyor.
          // Eskiden harita `Padding(8, 112, 8, 126)` ile kutulanıyor ve
          // ekranın üstünde/altında iki geniş boş şerit kalıyordu —
          // navigasyonda en değerli şey görülebilen yol uzunluğu.
          const gutter = AppSpacing.mapGutter;
          final topRow = media.padding.top + gutter;
          const maneuverHeight = 84.0;
          final secondRow = topRow + maneuverHeight + AppSpacing.mapStack;
          final bottomRow = media.padding.bottom + gutter;

          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CankayaMap(
                    anchors: const [],
                    route: _route,
                    // Kullanıcının konumu alt kartın ARKASINA düşmesin:
                    // kamerayı yukarı itiyoruz, haritayı küçültmüyoruz.
                    cameraPadding: EdgeInsets.only(
                      top: topRow + maneuverHeight,
                      bottom: bottomRow + 120,
                    ),
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
                top: topRow,
                left: gutter,
                right: gutter,
                child: ManeuverBanner(
                  instruction: instruction,
                  distanceM: _controller.progress.distanceToManeuverM,
                  roadName: step?.name,
                ),
              ),
              if (_controller.progress.offRoute)
                Positioned(
                  top: secondRow,
                  left: gutter,
                  right: gutter,
                  child: OffRouteBanner(
                    distanceM: _controller.progress.offRouteDistanceM,
                    recalculating: _recalculating,
                    onRecalculate:
                        widget.onRecalculate == null ? null : _recalculate,
                  ),
                )
              else if (_controller.weakSignal)
                Positioned(
                  top: secondRow,
                  left: gutter,
                  right: gutter,
                  child: const _WeakSignalBanner(),
                ),
              // "Ortala" düğmesi ikinci şerit varken bir kat daha aşağıda
              // durmuyor: sol ALTTA, kartın hemen üstünde — kullanıcının
              // parmağının doğal olarak durduğu yer.
              if (!_controller.cameraFollows && position != null)
                Positioned(
                  left: gutter,
                  bottom: bottomRow + 116,
                  child: _RecenterButton(onPressed: _controller.recenter),
                ),
              Positioned(
                left: gutter,
                right: gutter,
                bottom: bottomRow,
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

/// Kamerayı kullanıcının konumuna geri alan düğme.
///
/// Yalnızca kullanıcı haritayı ELLE kaydırdıktan sonra beliriyor —
/// takip zaten açıkken bir "Ortala" düğmesi göstermek, hiçbir şey
/// yapmayan bir düğme demek.
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GlassSurface.thin(
    borderRadius: BorderRadius.circular(AppRadius.pill),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.my_location, size: 18, color: AppColors.live),
            const SizedBox(width: 6),
            Text(
              'Ortala',
              style: AppType.xs.copyWith(
                color: AppColors.live,
                fontWeight: AppType.semibold,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Rota tamamlandı ekranı (R-57).
///
/// Uygulamanın en olumlu anı — maskot burada yerinde: kullanıcı bütün
/// rotayı gezdi ve bunu kutlamak, gri bir bayrak ikonundan iyi.
class _FinishedOverlay extends StatelessWidget {
  const _FinishedOverlay();

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: AppMaterials.scrim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.slow,
            // Taşan yay burada doğru: kullanıcı bir işi BİTİRDİ, bu bir
            // kutlama anı (bkz. AppMotion.spring notu).
            curve: AppMotion.spring,
            builder:
                (context, value, child) => Transform.scale(
                  scale: 0.88 + 0.12 * value,
                  child: Opacity(opacity: value.clamp(0, 1), child: child),
                ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MascotFigure(height: 96),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Rota tamamlandı', style: AppType.h2),
                  const SizedBox(height: 2),
                  Text(
                    'Bütün durakları gezdin.',
                    style: AppType.muted(AppType.sm),
                  ),
                  const SizedBox(height: AppSpacing.md),
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
    ),
  );
}

class _WeakSignalBanner extends StatelessWidget {
  const _WeakSignalBanner();

  @override
  Widget build(BuildContext context) => GlassSurface(
    borderRadius: BorderRadius.circular(AppRadius.md),
    shadow: AppShadows.md,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 10,
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_off, size: 18, color: AppColors.warn),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'GPS sinyali zayıf. Açık bir alana geç.',
              style: AppType.xs,
            ),
          ),
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.warn.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_outlined,
              size: 28,
              color: AppColors.warn,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Konum alınamıyor',
            style: AppType.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.muted(AppType.sm),
          ),
          const SizedBox(height: AppSpacing.md),
          if (showSettings) ...[
            FilledButton(
              onPressed: onSettings,
              child: const Text('Ayarları aç'),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          OutlinedButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    ),
  );
}
