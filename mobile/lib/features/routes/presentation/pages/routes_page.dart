import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../location/application/user_location_controller.dart';
import '../../../location_search/application/location_search_controller.dart';
import '../../../location_search/domain/location_search_models.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text(
              'Ziyaret rotası',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Konut listesinden veya favorilerinden 2–8 ev ekle; sistem '
              'en uygun ziyaret sırasını oluştursun.',
            ),
            const SizedBox(height: 14),
            _RouteDraftCard(
              items: controller.draft,
              onRemove: controller.removeProperty,
              onClear: controller.clearDraft,
            ),
            const SizedBox(height: 16),
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
              onUseAnchor: (id) => setState(() {
                _startKind = _StartKind.anchor;
                _startAnchorId = id;
              }),
              onUseAddress: (result) => setState(() {
                _startKind = _StartKind.address;
                _startAddress = result;
              }),
              onUseDistrictCenter: () =>
                  setState(() => _startKind = _StartKind.districtCenter),
            ),
            const SizedBox(height: 12),
            SegmentedButton<RouteTravelMode>(
              segments: const [
                ButtonSegment(
                  value: RouteTravelMode.car,
                  icon: Icon(Icons.directions_car_outlined),
                  label: Text('Araç'),
                ),
                ButtonSegment(
                  value: RouteTravelMode.foot,
                  icon: Icon(Icons.directions_walk),
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
            if (controller.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                controller.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
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
              icon: controller.saving
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
              const SizedBox(height: 22),
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
                  onClose: controller.closeActiveRoute,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kayıtlı rotalarım',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      controller.loading
                          ? null
                          : () => controller.loadRoutes(force: true),
                  tooltip: 'Yenile',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (controller.loading && controller.savedRoutes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.savedRoutes.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Henüz kaydedilmiş bir rotan yok.'),
                ),
              )
            else
              for (final route in controller.savedRoutes)
                Card(
                  child: ListTile(
                    onTap:
                        controller.openingRouteId == null
                            ? () => _openRoute(route)
                            : null,
                    leading: CircleAvatar(
                      child: Icon(
                        route.mode == RouteTravelMode.car
                            ? Icons.directions_car
                            : Icons.directions_walk,
                      ),
                    ),
                    title: Text(
                      route.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${route.stopCount} durak · '
                      '${formatDistance(route.totalDistanceM)} · '
                      '${formatDuration(route.totalDurationS)}',
                    ),
                    trailing:
                        controller.openingRouteId == route.id ||
                                controller.deletingRouteIds.contains(route.id)
                            ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : IconButton(
                              tooltip: 'Rotayı sil',
                              onPressed: () => _deleteRoute(route),
                              icon: const Icon(Icons.delete_outline),
                            ),
                  ),
                ),
          ],
        );
      },
    ),
  );
}

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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Seçilen konutlar (${items.length}/$maxRouteStops)',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (items.isNotEmpty)
                TextButton(onPressed: onClear, child: const Text('Temizle')),
            ],
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Henüz rota taslağına konut eklenmedi.'),
            ),
          for (var index = 0; index < items.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(
                '${items[index].roomCount} · ${items[index].areaM2} m²',
              ),
              subtitle: Text(
                '${formatPrice(items[index].monthlyRent)} ₺ · '
                '${items[index].totalScore.round()} puan',
              ),
              trailing: IconButton(
                tooltip: 'Taslak rotadan çıkar',
                onPressed: () => onRemove(items[index].id),
                icon: const Icon(Icons.close),
              ),
            ),
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
    required this.onClose,
    this.onSave,
  });

  final RouteDetail route;
  final bool busy;
  final void Function(RouteStop stop) onRemoveStop;
  final VoidCallback onShowOnMainMap;
  final VoidCallback onClose;

  /// Kaydedilecek bir şey yoksa null — düğme hiç çizilmez.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  route.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Chip(label: Text(route.mode.label)),
              IconButton(
                tooltip: 'Aktif rotayı kapat',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _RouteMetric(
                  label: 'Mesafe',
                  value: formatDistance(route.totalDistanceM),
                ),
              ),
              Expanded(
                child: _RouteMetric(
                  label: 'Tahmini süre',
                  value: formatDuration(route.totalDurationS),
                ),
              ),
              Expanded(
                child: _RouteMetric(
                  label: 'Durak',
                  value: '${route.stopCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 280,
            child: ExcludeFocus(
              child: CankayaMap(anchors: const [], route: route),
            ),
          ),
          const SizedBox(height: 12),
          // Kaydetme çağrısı — rota HESAPLANDI ama kaydedilmedi.
          // Kullanıcının kaydedilmemiş bir rotayı kaydedilmiş sanmasını
          // engelleyen tek işaret bu.
          if (onSave != null) ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Bu rota henüz kaydedilmedi.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: busy ? null : onSave,
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: const Text('Rotayı kaydet'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Ziyaret sırası',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          for (final stop in route.stops)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${stop.sequence}')),
              title: Text(
                '${stop.property.roomCount} · ${stop.property.areaM2} m²',
              ),
              subtitle: Text(
                [
                  stop.property.neighborhood,
                  if (stop.legDistanceM != null)
                    formatDistance(stop.legDistanceM!),
                  if (stop.legDurationS != null)
                    formatDuration(stop.legDurationS!),
                ].whereType<String>().join(' · '),
              ),
              trailing: IconButton(
                tooltip: 'Duraktan çıkar ve yeniden hesapla',
                onPressed:
                    busy || route.stops.length <= minRouteStops
                        ? null
                        : () => onRemoveStop(stop),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: onShowOnMainMap,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Ana haritada göster'),
          ),
        ],
      ),
    ),
  );
}

class _RouteMetric extends StatelessWidget {
  const _RouteMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
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
        final locating =
            userLocation.status == UserLocationStatus.locating;
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

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(Icons.trip_origin, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: 8),
          Text(
            'Başlangıç noktası',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: enabled ? () => _open(context) : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  switch (kind) {
                    _StartKind.live => Icons.my_location,
                    _StartKind.address => Icons.place_outlined,
                    _StartKind.anchor => Icons.star_outline,
                    _StartKind.districtCenter => Icons.location_city_outlined,
                  },
                  size: 20,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.expand_more, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Future<void> _open(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _StartPointSheet(
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
    child: AnimatedBuilder(
      animation: widget.searchController,
      builder: (context, _) {
        final results = widget.searchController.results;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
