import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/page_parts.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../../location/application/user_location_controller.dart';
import '../../../location_search/application/location_search_controller.dart';
import '../../../location_search/domain/location_search_models.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';
import '../../../navigation/presentation/pages/navigation_page.dart';
import '../../../properties/presentation/property_format.dart';
import '../../application/routes_controller.dart';
import '../../domain/route_models.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({
    required this.controller,
    required this.anchors,
    required this.onShowOnMainMap,
    required this.userLocation,
    required this.searchController,
    required this.offline,
    super.key,
  });

  final RoutesController controller;
  final List<Anchor> anchors;
  final VoidCallback onShowOnMainMap;

  /// Haritayla PAYLAŞILAN konum denetleyicisi. Ayrı bir örnek kullansaydık
  /// kullanıcıdan izni iki kez isterdik ve haritadaki mavi nokta ile rota
  /// başlangıcı farklı koordinatları gösterebilirdi.
  final UserLocationController userLocation;

  /// Başlangıç noktası için adres araması.
  final LocationSearchController searchController;
  final bool offline;

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

/// Başlangıç noktasının kaynağı.
///
/// Eskiden yalnızca "önemli konumlar + Çankaya Merkez" vardı; web'de
/// başlangıç canlı konumdan ya da yazılan bir adresten seçilebiliyordu.
/// Mobil o iki seçeneği kazandı.
enum _StartKind { live, address, anchor, districtCenter }

class _RoutesPageState extends State<RoutesPage> {
  late final TextEditingController _nameController;
  final GlobalKey _activeRouteKey = GlobalKey();
  RouteTravelMode _mode = RouteTravelMode.car;

  _StartKind _startKind = _StartKind.live;
  String? _startAnchorId;
  LocationSearchResult? _startAddress;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _defaultRouteName());
    widget.controller.loadRoutes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Seçili başlangıç noktası; henüz belirlenemiyorsa null.
  ///
  /// Canlı konum seçiliyken koordinat cihazdan gelene kadar null kalır —
  /// bu yüzden "Rotayı oluştur" düğmesi o an pasif olmalı, yoksa kullanıcı
  /// başlangıcı olmayan bir rota isteyebilirdi.
  RouteStart? get _selectedStart {
    switch (_startKind) {
      case _StartKind.live:
        final live = widget.userLocation.location;
        if (live == null) return null;
        return RouteStart(
          latitude: live.latitude,
          longitude: live.longitude,
          label: 'Canlı konumum',
        );
      case _StartKind.address:
        final address = _startAddress;
        if (address == null) return null;
        return RouteStart(
          latitude: address.latitude,
          longitude: address.longitude,
          label: address.label,
        );
      case _StartKind.anchor:
        for (final anchor in widget.anchors) {
          if (anchor.id == _startAnchorId) {
            return RouteStart(
              latitude: anchor.lat,
              longitude: anchor.lon,
              label: anchor.label,
            );
          }
        }
        return null;
      case _StartKind.districtCenter:
        return const RouteStart(
          latitude: 39.87,
          longitude: 32.85,
          label: 'Çankaya Merkez',
        );
    }
  }

  /// Canlı konumu ister ve başlangıç olarak seçer.
  Future<void> _useLiveLocation() async {
    setState(() => _startKind = _StartKind.live);
    final result = await widget.userLocation.request();
    if (!mounted || result != null) return;

    final message = widget.userLocation.message;
    if (message != null) _showMessage(message);
    // Konum alınamadıysa seçimi bırakmıyoruz: kullanıcı tekrar deneyebilsin,
    // ama düğme pasif kalacağı için başlangıcı olmayan rota isteyemez.
  }

  /// Rotayı hesaplar — KAYDETMEZ.
  Future<void> _previewRoute() async {
    FocusScope.of(context).unfocus();
    final start = _selectedStart;
    if (start == null) {
      _showMessage('Önce bir başlangıç noktası seç.');
      return;
    }

    final ok = await widget.controller.previewRoute(start: start, mode: _mode);
    if (!mounted) return;
    if (!ok) {
      _showMessage(widget.controller.errorMessage ?? 'Rota oluşturulamadı.');
      return;
    }
    _scrollToActiveRoute();
  }

  /// Ekrandaki rotayı isim sorarak kaydeder.
  Future<void> _saveActiveRoute() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _SaveRouteDialog(initialName: _defaultRouteName()),
    );
    if (name == null || !mounted) return;

    final ok = await widget.controller.saveActiveRoute(name: name);
    if (!mounted) return;
    if (!ok) {
      _showMessage(widget.controller.errorMessage ?? 'Rota kaydedilemedi.');
      return;
    }
    _showMessage('Rota kaydedildi.');
  }

  Future<void> _deleteRoute(RouteSummary route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rotayı sil'),
            content: Text('${route.name} rotası silinsin mi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final deleted = await widget.controller.deleteRoute(route.id);
    if (!mounted) return;
    _showMessage(
      deleted
          ? 'Rota silindi.'
          : widget.controller.errorMessage ?? 'Rota silinemedi.',
    );
  }

  Future<void> _removeStop(RouteStop stop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Durağı kaldır'),
            content: const Text(
              'Konut rotadan çıkarılıp kalan duraklar yeniden optimize edilecek.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Kaldır ve hesapla'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      final updated = await widget.controller.reoptimizeWithout(
        stop.propertyId,
      );
      if (!mounted) return;
      _showMessage(
        updated
            ? widget.controller.errorMessage ??
                'Konut çıkarıldı ve rota yeniden oluşturuldu.'
            : widget.controller.errorMessage ?? 'Rota yeniden oluşturulamadı.',
      );
    }
  }

  Future<void> _openRoute(RouteSummary route) async {
    final opened = await widget.controller.openRoute(route.id);
    if (!mounted) return;
    if (!opened) {
      _showMessage(widget.controller.errorMessage ?? 'Rota detayı açılamadı.');
      return;
    }
    _scrollToActiveRoute();
  }

  Future<void> _startNavigation(RouteDetail route) async {
    if (widget.offline) {
      _showMessage('Navigasyon için internet bağlantısı gereklidir.');
      return;
    }
    if (route.stopCount < 2) {
      _showMessage('Navigasyon için rotada en az iki konut bulunmalıdır.');
      return;
    }
    final location = await widget.userLocation.request();
    if (!mounted) return;
    if (location == null) {
      await _showLocationProblem();
      return;
    }

    final navigationRoute = await widget.controller.prepareNavigation(
      route: route,
      liveStart: RouteStart(
        latitude: location.latitude,
        longitude: location.longitude,
        label: 'Canlı konumum',
      ),
    );
    if (!mounted) return;
    if (navigationRoute == null) {
      _showMessage(
        widget.controller.errorMessage ??
            'Canlı konumundan rota hesaplanamadı.',
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => NavigationPage(
              route: navigationRoute,
              onRecalculate:
                  (position) => widget.controller.prepareNavigation(
                    route: navigationRoute,
                    liveStart: RouteStart(
                      latitude: position.latitude,
                      longitude: position.longitude,
                      label: 'Canlı konumum',
                    ),
                  ),
            ),
      ),
    );
  }

  Future<void> _startSavedNavigation(RouteSummary summary) async {
    final opened = await widget.controller.openRoute(summary.id);
    if (!mounted) return;
    final route = widget.controller.activeRoute;
    if (!opened || route == null) {
      _showMessage(widget.controller.errorMessage ?? 'Rota açılamadı.');
      return;
    }
    await _startNavigation(route);
  }

  Future<void> _showLocationProblem() async {
    final needsSettings = widget.userLocation.needsAppSettings;
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Canlı konum alınamadı'),
            content: Text(
              widget.userLocation.message ??
                  'Navigasyonu başlatmak için konum izni ve açık konum servisi gerekir.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
              if (needsSettings)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.userLocation.openSettings();
                  },
                  child: const Text('Ayarları aç'),
                ),
            ],
          ),
    );
  }

  /// Rota kartını görünür alana kaydırır.
  ///
  /// Hem kayıtlı rota açılınca hem yeni önizleme hesaplanınca gerekiyor:
  /// kart sayfanın altında kalıyor ve kaydırılmazsa kullanıcı "hiçbir şey
  /// olmadı" sanıyor.
  void _scrollToActiveRoute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeContext = _activeRouteKey.currentContext;
      if (activeContext == null) return;
      Scrollable.ensureVisible(
        activeContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.08,
      );
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            // Başlık AppBar'da; gövde doğrudan açıklamayla başlıyor.
            const PageIntro(
              'Konut listesinden 2–8 ev ekle; sistem en kısa ziyaret '
              'sırasını hesaplasın.',
            ),
            _RouteDraftCard(
              items: controller.draft,
              onRemove: controller.removeProperty,
              onClear: controller.clearDraft,
            ),
            const SizedBox(height: AppSpacing.md),
            // ROTA ADI BURADAN KALKTI: isim yalnızca KAYDEDERKEN soruluyor.
            // Önizleme için ad istemek, kullanıcıya daha görmediği bir şeyi
            // isimlendirtmek olurdu.
            _StartPointPicker(
              kind: _startKind,
              anchorId: _startAnchorId,
              address: _startAddress,
              anchors: widget.anchors,
              userLocation: widget.userLocation,
              searchController: widget.searchController,
              enabled: !controller.saving,
              onUseLive: _useLiveLocation,
              onUseAnchor:
                  (id) => setState(() {
                    _startKind = _StartKind.anchor;
                    _startAnchorId = id;
                  }),
              onUseAddress:
                  (result) => setState(() {
                    _startKind = _StartKind.address;
                    _startAddress = result;
                  }),
              onUseDistrictCenter:
                  () => setState(() => _startKind = _StartKind.districtCenter),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('ULAŞIM', style: AppType.micro),
            const SizedBox(height: 6),
            SegmentedButton<RouteTravelMode>(
              segments: const [
                ButtonSegment(
                  value: RouteTravelMode.car,
                  icon: Icon(Icons.directions_car_outlined, size: 18),
                  label: Text('Araç'),
                ),
                ButtonSegment(
                  value: RouteTravelMode.foot,
                  icon: Icon(Icons.directions_walk, size: 18),
                  label: Text('Yürüme'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged:
                  controller.saving
                      ? null
                      : (selection) {
                        setState(() => _mode = selection.first);
                      },
            ),
            if (controller.errorMessage case final error?) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.bad.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 17,
                      color: AppColors.bad,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        error,
                        style: AppType.xs.copyWith(color: AppColors.bad),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              // Başlangıç noktası belirlenemiyorsa (canlı konum seçili ama
              // koordinat henüz gelmediyse) düğme pasif: başlangıcı olmayan
              // bir rota istenemesin.
              onPressed:
                  controller.saving ||
                          controller.draft.length < minRouteStops ||
                          _selectedStart == null
                      ? null
                      : _previewRoute,
              icon:
                  controller.saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.route),
              label: Text(
                controller.saving ? 'Hesaplanıyor…' : 'Rotayı oluştur',
              ),
            ),
            if (controller.activeRoute != null) ...[
              const SizedBox(height: AppSpacing.lg),
              KeyedSubtree(
                key: _activeRouteKey,
                child: _ActiveRouteCard(
                  route: controller.activeRoute!,
                  busy: controller.saving,
                  // Kaydet düğmesi yalnızca kaydedilmemiş bir rota ya da
                  // kaydedilmiş ama DEĞİŞTİRİLMİŞ bir rota varken çıkıyor.
                  onSave:
                      controller.isPreviewing || controller.hasUnsavedChanges
                          ? _saveActiveRoute
                          : null,
                  onRemoveStop: _removeStop,
                  onShowOnMainMap: widget.onShowOnMainMap,
                  onNavigate:
                      widget.offline
                          ? null
                          : () => _startNavigation(controller.activeRoute!),
                  onClose: controller.closeActiveRoute,
                ),
              ),
            ],
            SectionHeader(
              'KAYITLI ROTALARIM',
              count:
                  controller.savedRoutes.isEmpty
                      ? null
                      : controller.savedRoutes.length,
              action: IconButton(
                onPressed:
                    controller.loading
                        ? null
                        : () => controller.loadRoutes(force: true),
                tooltip: 'Yenile',
                icon: const Icon(Icons.refresh, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ),
            if (controller.loading && controller.savedRoutes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.savedRoutes.isEmpty)
              const EmptyState(
                icon: Icons.route_outlined,
                title: 'Kayıtlı rotan yok',
                message:
                    'Bir rota oluşturup kaydettiğinde burada durur; '
                    'navigasyonu buradan başlatırsın.',
              )
            else
              for (final (index, route) in controller.savedRoutes.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: StaggeredEntrance(
                    index: index,
                    child: _SavedRouteCard(
                      route: route,
                      busy:
                          controller.openingRouteId == route.id ||
                          controller.deletingRouteIds.contains(route.id),
                      offline: widget.offline,
                      onOpen:
                          controller.openingRouteId == null
                              ? () => _openRoute(route)
                              : null,
                      onNavigate: () => _startSavedNavigation(route),
                      onDelete: () => _deleteRoute(route),
                    ),
                  ),
                ),
          ],
        );
      },
    ),
  );
}

/// Rota taslağı — kullanıcının seçtiği ama henüz hesaplanmamış evler.
class _RouteDraftCard extends StatelessWidget {
  const _RouteDraftCard({
    required this.items,
    required this.onRemove,
    required this.onClear,
  });

  final List<RouteDraftProperty> items;
  final void Function(int propertyId) onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final enough = items.length >= minRouteStops;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: enough ? AppColors.accentEdge : AppColors.border,
          width: enough ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 10, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seçilen konutlar',
                        style: AppType.sm.copyWith(
                          fontWeight: AppType.semibold,
                        ),
                      ),
                      // Sayaç kaç ev GEREKTİĞİNİ de söylüyor: "1/8"
                      // tek başına rotanın neden oluşturulamadığını
                      // açıklamıyordu.
                      Text(
                        enough
                            ? '${items.length} / $maxRouteStops ev'
                            : 'En az $minRouteStops ev gerekiyor '
                                '(${items.length} seçildi)',
                        style: AppType.muted(AppType.micro).copyWith(
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                if (items.isNotEmpty)
                  TextButton(onPressed: onClear, child: const Text('Temizle')),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_location_alt_outlined,
                    size: 18,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Konutlar sekmesinden "Rotaya ekle" ile ev seç.',
                      style: AppType.muted(AppType.xs),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final (index, item) in items.indexed) ...[
              const Divider(height: 1),
              _DraftRow(
                index: index,
                item: item,
                onRemove: () => onRemove(item.id),
              ),
            ],
        ],
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.index,
    required this.item,
    required this.onRemove,
  });

  final int index;
  final RouteDraftProperty item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 6, 4, 6),
    child: Row(
      children: [
        // Taslakta numara YOK — sıra henüz belli değil. Nokta, "bu bir
        // seçim" diyor; numaralı rozet, hesaplanmış rotanın işareti.
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.roomCount} · ${item.areaM2} m²',
                style: AppType.sm.copyWith(fontWeight: AppType.medium),
              ),
              Text(
                '${formatRent(item.monthlyRent)} · '
                '${item.totalScore.round()} puan',
                style: AppType.muted(AppType.micro).copyWith(letterSpacing: 0),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Taslaktan çıkar',
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 18),
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );
}

/// Kayıtlı rota kartı.
class _SavedRouteCard extends StatelessWidget {
  const _SavedRouteCard({
    required this.route,
    required this.busy,
    required this.offline,
    required this.onOpen,
    required this.onNavigate,
    required this.onDelete,
  });

  final RouteSummary route;
  final bool busy;
  final bool offline;
  final VoidCallback? onOpen;
  final VoidCallback onNavigate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onOpen,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.mapRoute.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              route.mode == RouteTravelMode.car
                  ? Icons.directions_car
                  : Icons.directions_walk,
              size: 19,
              color: AppColors.mapRoute,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sm.copyWith(fontWeight: AppType.semibold),
                ),
                Text(
                  '${route.stopCount} durak · '
                  '${formatDistance(route.totalDistanceM)} · '
                  '${formatDuration(route.totalDurationS)}',
                  style: AppType.muted(AppType.micro).copyWith(
                    letterSpacing: 0,
                    fontFeatures: AppType.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              tooltip:
                  offline
                      ? 'Navigasyon için internet gerekiyor'
                      : 'Navigasyonu başlat',
              onPressed: offline ? null : onNavigate,
              icon: const Icon(Icons.navigation_outlined, size: 19),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Rotayı sil',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 19),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    ),
  );
}

class _ActiveRouteCard extends StatelessWidget {
  const _ActiveRouteCard({
    required this.route,
    required this.busy,
    required this.onRemoveStop,
    required this.onShowOnMainMap,
    required this.onNavigate,
    required this.onClose,
    this.onSave,
  });

  final RouteDetail route;
  final bool busy;
  final void Function(RouteStop stop) onRemoveStop;
  final VoidCallback onShowOnMainMap;
  final VoidCallback? onNavigate;
  final VoidCallback onClose;

  /// Kaydedilecek bir şey yoksa null — düğme hiç çizilmez.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final canNavigate = route.legs.any((leg) => leg.steps.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.mapRoute.withValues(alpha: 0.35)),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Başlık ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 10, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.h3,
                      ),
                      Text(
                        route.mode.label,
                        style: AppType.muted(AppType.micro).copyWith(
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Aktif rotayı kapat',
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 19),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // ── Özet sayılar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _RouteMetric(
                        label: 'MESAFE',
                        value: formatDistance(route.totalDistanceM),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _RouteMetric(
                        label: 'SÜRE',
                        value: formatDuration(route.totalDurationS),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _RouteMetric(
                        label: 'DURAK',
                        value: '${route.stopCount}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Harita ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: SizedBox(
              height: 220,
              child: ExcludeFocus(
                child: CankayaMap(
                  rounded: true,
                  anchors: const [],
                  route: route,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Kaydetme çağrısı ──────────────────────────────────────
          // Rota HESAPLANDI ama kaydedilmedi. Kullanıcının kaydedilmemiş
          // bir rotayı kaydedilmiş sanmasını engelleyen tek işaret bu.
          if (onSave != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 8, 8, 8),
                decoration: BoxDecoration(
                  color: AppColors.warn.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.warn.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bookmark_border,
                      size: 18,
                      color: AppColors.warn,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Bu rota henüz kaydedilmedi.',
                        style: AppType.xs.copyWith(color: AppColors.warn),
                      ),
                    ),
                    FilledButton(
                      onPressed: busy ? null : onSave,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        textStyle: AppType.xs.copyWith(
                          fontWeight: AppType.semibold,
                        ),
                      ),
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              ),
            ),

          // ── Ziyaret sırası ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, 4),
            child: Text('ZİYARET SIRASI', style: AppType.micro),
          ),
          for (final (index, stop) in route.stops.indexed)
            _StopRow(
              stop: stop,
              isLast: index == route.stops.length - 1,
              canRemove: !busy && route.stops.length > minRouteStops,
              onRemove: () => onRemoveStop(stop),
            ),

          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShowOnMainMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Haritada'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canNavigate ? onNavigate : null,
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Navigasyon'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rotadaki tek durak.
///
/// ⚠️ SIRA ÇİZGİYLE ANLATILIYOR. Eskiden her durak ayrı bir `ListTile`
/// ve numaralı bir daireydi; aralarında görsel bir bağ yoktu ve liste
/// "rota" değil "seçim listesi" gibi okunuyordu. Numaraların arasındaki
/// dikey çizgi, bunun bir GÜZERGÂH olduğunu söylüyor.
class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.isLast,
    required this.canRemove,
    required this.onRemove,
  });

  final RouteStop stop;
  final bool isLast;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final detail = [
      stop.property.neighborhood,
      if (stop.legDistanceM != null) formatDistance(stop.legDistanceM!),
      if (stop.legDurationS != null) formatDuration(stop.legDurationS!),
    ].whereType<String>().join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, 4, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.mapRoute,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${stop.sequence}',
                    style: AppType.micro.copyWith(
                      color: Colors.white,
                      letterSpacing: 0,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.mapRoute.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stop.property.roomCount} · '
                      '${stop.property.areaM2} m²',
                      style: AppType.sm.copyWith(fontWeight: AppType.medium),
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: AppType.muted(AppType.micro).copyWith(
                          letterSpacing: 0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Duraktan çıkar ve yeniden hesapla',
              onPressed: canRemove ? onRemove : null,
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMetric extends StatelessWidget {
  const _RouteMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      children: [
        Text(
          value,
          style: AppType.sm.copyWith(
            fontWeight: AppType.bold,
            fontFeatures: AppType.tabularFigures,
          ),
        ),
        Text(label, style: AppType.micro.copyWith(fontSize: 10)),
      ],
    ),
  );
}

/// Başlangıç noktası seçici.
///
/// Web'deki tek satırlık konum kutusunun mobil karşılığı: en üstte canlı
/// konum, altında kayıtlı önemli konumlar, altında adres araması.
class _StartPointPicker extends StatelessWidget {
  const _StartPointPicker({
    required this.kind,
    required this.anchorId,
    required this.address,
    required this.anchors,
    required this.userLocation,
    required this.searchController,
    required this.enabled,
    required this.onUseLive,
    required this.onUseAnchor,
    required this.onUseAddress,
    required this.onUseDistrictCenter,
  });

  final _StartKind kind;
  final String? anchorId;
  final LocationSearchResult? address;
  final List<Anchor> anchors;
  final UserLocationController userLocation;
  final LocationSearchController searchController;
  final bool enabled;
  final VoidCallback onUseLive;
  final ValueChanged<String> onUseAnchor;
  final ValueChanged<LocationSearchResult> onUseAddress;
  final VoidCallback onUseDistrictCenter;

  String get _summary {
    switch (kind) {
      case _StartKind.live:
        final locating = userLocation.status == UserLocationStatus.locating;
        if (locating) return 'Konumun alınıyor…';
        return userLocation.location == null
            ? 'Canlı konumum (henüz alınmadı)'
            : 'Canlı konumum';
      case _StartKind.address:
        return address?.label ?? 'Adres seç';
      case _StartKind.anchor:
        for (final anchor in anchors) {
          if (anchor.id == anchorId) return anchor.label;
        }
        return 'Önemli konum seç';
      case _StartKind.districtCenter:
        return 'Çankaya Merkez';
    }
  }

  /// Başlangıç henüz belli değil mi — düğme o zaman uyarı rengiyle
  /// çiziliyor, "Rotayı oluştur" da kapalı kalıyor.
  bool get _unresolved => switch (kind) {
    _StartKind.live => userLocation.location == null,
    _StartKind.address => address == null,
    _StartKind.anchor => anchorId == null,
    _StartKind.districtCenter => false,
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('BAŞLANGIÇ NOKTASI', style: AppType.micro),
      const SizedBox(height: 6),
      Pressable(
        onTap: enabled ? () => _open(context) : null,
        scale: 0.99,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSunken,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _unresolved ? AppColors.warn.withValues(alpha: 0.4) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  switch (kind) {
                    _StartKind.live => Icons.my_location,
                    _StartKind.address => Icons.place_outlined,
                    _StartKind.anchor => Icons.push_pin_outlined,
                    _StartKind.districtCenter => Icons.location_city_outlined,
                  },
                  size: 17,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sm.copyWith(
                    fontWeight: AppType.medium,
                    color: _unresolved ? AppColors.warn : AppColors.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.unfold_more,
                size: 18,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Future<void> _open(BuildContext context) async {
    await showAppSheet<void>(
      context,
      builder:
          (sheetContext) => _StartPointSheet(
            anchors: anchors,
            searchController: searchController,
            onUseLive: () {
              Navigator.pop(sheetContext);
              onUseLive();
            },
            onUseAnchor: (id) {
              Navigator.pop(sheetContext);
              onUseAnchor(id);
            },
            onUseAddress: (result) {
              Navigator.pop(sheetContext);
              onUseAddress(result);
            },
            onUseDistrictCenter: () {
              Navigator.pop(sheetContext);
              onUseDistrictCenter();
            },
          ),
    );
  }
}

/// Başlangıç seçim alt sayfası.
class _StartPointSheet extends StatefulWidget {
  const _StartPointSheet({
    required this.anchors,
    required this.searchController,
    required this.onUseLive,
    required this.onUseAnchor,
    required this.onUseAddress,
    required this.onUseDistrictCenter,
  });

  final List<Anchor> anchors;
  final LocationSearchController searchController;
  final VoidCallback onUseLive;
  final ValueChanged<String> onUseAnchor;
  final ValueChanged<LocationSearchResult> onUseAddress;
  final VoidCallback onUseDistrictCenter;

  @override
  State<_StartPointSheet> createState() => _StartPointSheetState();
}

class _StartPointSheetState extends State<_StartPointSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      top: 12,
      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
    ),
    // ⚠️ KAYDIRILABİLİR OLMAK ZORUNDA. Klavye açılınca alt sayfaya kalan
    // yükseklik düşüyor ve sabit bir Column taşıyor ("BOTTOM OVERFLOWED").
    // Önemli konumu çok olan kullanıcıda liste zaten uzuyor.
    child: AnimatedBuilder(
      animation: widget.searchController,
      builder: (context, _) {
        final results = widget.searchController.results;
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHeader(
                title: 'Başlangıç noktası',
                subtitle: 'Rota buradan başlayacak.',
              ),
              // Canlı konum EN ÜSTTE: en sık istenen seçenek.
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location, color: AppColors.accent),
                title: const Text('Canlı konumum'),
                subtitle: const Text('Bulunduğun yerden başla'),
                onTap: widget.onUseLive,
              ),
              const Divider(),
              TextField(
                controller: _query,
                decoration: const InputDecoration(
                  hintText: 'Adres veya mahalle ara',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: widget.searchController.search,
              ),
              const SizedBox(height: 8),
              if (results.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(result.label),
                        onTap: () => widget.onUseAddress(result),
                      );
                    },
                  ),
                ),
              if (widget.anchors.isNotEmpty) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Önemli konumların',
                    style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
                  ),
                ),
                for (final anchor in widget.anchors)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.star_outline),
                    title: Text(anchor.label),
                    onTap: () => widget.onUseAnchor(anchor.id),
                  ),
              ],
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_city_outlined),
                title: const Text('Çankaya Merkez'),
                subtitle: const Text('Konum vermeden başla'),
                onTap: widget.onUseDistrictCenter,
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Kaydetme sırasında ad soran diyalog.
class _SaveRouteDialog extends StatefulWidget {
  const _SaveRouteDialog({required this.initialName});

  final String initialName;

  @override
  State<_SaveRouteDialog> createState() => _SaveRouteDialogState();
}

class _SaveRouteDialogState extends State<_SaveRouteDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rotayı kaydet'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Rota adı'),
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Kaydet'),
      ),
    ],
  );
}

String _defaultRouteName() {
  final now = DateTime.now();
  return 'Ziyaret Rotası ${now.day.toString().padLeft(2, '0')}.'
      '${now.month.toString().padLeft(2, '0')}.${now.year}';
}
