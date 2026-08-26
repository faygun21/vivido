import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';
import '../../../properties/presentation/property_format.dart';
import '../../application/routes_controller.dart';
import '../../domain/route_models.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({
    required this.controller,
    required this.anchors,
    required this.onShowOnMainMap,
    super.key,
  });

  final RoutesController controller;
  final List<Anchor> anchors;
  final VoidCallback onShowOnMainMap;

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  late final TextEditingController _nameController;
  final GlobalKey _activeRouteKey = GlobalKey();
  RouteTravelMode _mode = RouteTravelMode.car;
  String _startId = _defaultStartId;

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

  RouteStart get _selectedStart {
    for (final anchor in widget.anchors) {
      if (anchor.id == _startId) {
        return RouteStart(
          latitude: anchor.lat,
          longitude: anchor.lon,
          label: anchor.label,
        );
      }
    }
    return const RouteStart(
      latitude: 39.87,
      longitude: 32.85,
      label: 'Çankaya Merkez',
    );
  }

  Future<void> _createRoute() async {
    FocusScope.of(context).unfocus();
    final created = await widget.controller.createRoute(
      name: _nameController.text,
      start: _selectedStart,
      mode: _mode,
    );
    if (!mounted) return;
    if (!created) {
      _showMessage(widget.controller.errorMessage ?? 'Rota oluşturulamadı.');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rota oluşturuldu ve hesabına kaydedildi.')),
    );
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
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              enabled: !controller.saving,
              decoration: const InputDecoration(
                labelText: 'Rota adı',
                prefixIcon: Icon(Icons.edit_road),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _startId,
              decoration: const InputDecoration(
                labelText: 'Başlangıç noktası',
                prefixIcon: Icon(Icons.trip_origin),
              ),
              items: [
                const DropdownMenuItem(
                  value: _defaultStartId,
                  child: Text('Çankaya Merkez'),
                ),
                for (final anchor in widget.anchors)
                  DropdownMenuItem(value: anchor.id, child: Text(anchor.label)),
              ],
              onChanged:
                  controller.saving
                      ? null
                      : (value) {
                        if (value != null) setState(() => _startId = value);
                      },
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
              onPressed:
                  controller.saving || controller.draft.length < minRouteStops
                      ? null
                      : _createRoute,
              icon:
                  controller.saving
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.route),
              label: Text(
                controller.saving ? 'Hesaplanıyor…' : 'Rotayı optimize et',
              ),
            ),
            if (controller.activeRoute != null) ...[
              const SizedBox(height: 22),
              KeyedSubtree(
                key: _activeRouteKey,
                child: _ActiveRouteCard(
                  route: controller.activeRoute!,
                  busy: controller.saving,
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
  });

  final RouteDetail route;
  final bool busy;
  final void Function(RouteStop stop) onRemoveStop;
  final VoidCallback onShowOnMainMap;
  final VoidCallback onClose;

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

const _defaultStartId = '__cankaya__';

String _defaultRouteName() {
  final now = DateTime.now();
  return 'Ziyaret Rotası ${now.day.toString().padLeft(2, '0')}.'
      '${now.month.toString().padLeft(2, '0')}.${now.year}';
}
