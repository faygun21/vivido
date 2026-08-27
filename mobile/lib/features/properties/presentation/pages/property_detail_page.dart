import 'package:flutter/material.dart';

import '../../../favorites/application/favorites_controller.dart';
import '../../../location_search/domain/location_search_models.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';
import '../../../map_data/domain/map_data_models.dart';
import '../../../map_data/presentation/widgets/map_item_details_sheet.dart';
import '../../../property_strengths/domain/strength_poi_gateway.dart';
import '../../../routes/application/routes_controller.dart';
import '../../../routes/domain/route_models.dart';
import '../../domain/property_gateway.dart';
import '../../domain/property_models.dart';
import '../property_format.dart';

class PropertyDetailPage extends StatefulWidget {
  const PropertyDetailPage({
    required this.propertyId,
    required this.gateway,
    required this.favorites,
    required this.routes,
    required this.strengthPoiGateway,
    this.onFavoriteChanged,
    super.key,
  });

  final String propertyId;
  final PropertyGateway gateway;
  final FavoritesController favorites;
  final RoutesController routes;
  final StrengthPoiGateway strengthPoiGateway;
  final void Function(String propertyId, bool isFavorite)? onFavoriteChanged;

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  PropertyDetail? _property;
  List<PoiMapItem> _highlightedPois = const [];
  bool _strengthPoisLoading = false;
  String? _strengthPoisError;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _errorMessage = null);
    try {
      final property = await widget.gateway.getPropertyDetail(
        widget.propertyId,
      );
      if (!mounted) return;
      setState(() => _property = property);
      await _loadStrengthPois(property);
    } on PropertyDataFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on Object {
      if (mounted) {
        setState(() => _errorMessage = 'Konut detayı yüklenemedi.');
      }
    }
  }

  Future<void> _loadStrengthPois(PropertyDetail property) async {
    setState(() {
      _strengthPoisLoading = true;
      _strengthPoisError = null;
    });
    try {
      final pois = await widget.strengthPoiGateway.getHighlightedPois(
        propertyLatitude: property.latitude,
        propertyLongitude: property.longitude,
        strengths: property.score.strengths,
      );
      if (!mounted || _property?.id != property.id) return;
      setState(() => _highlightedPois = pois);
    } on StrengthPoiFailure catch (error) {
      if (mounted) setState(() => _strengthPoisError = error.message);
    } on Object {
      if (mounted) {
        setState(() => _strengthPoisError = 'Güçlü yön noktaları yüklenemedi.');
      }
    } finally {
      if (mounted && _property?.id == property.id) {
        setState(() => _strengthPoisLoading = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final property = _property;
    if (property == null) return;
    final desired = !property.isFavorite;
    final changed = await widget.favorites.setFavorite(property.id, desired);
    if (!mounted) return;
    if (changed) {
      setState(() => _property = property.copyWith(isFavorite: desired));
      widget.onFavoriteChanged?.call(property.id, desired);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            desired ? 'Favorilere eklendi.' : 'Favorilerden çıkarıldı.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.favorites.errorMessage ?? 'Favori durumu güncellenemedi.',
          ),
        ),
      );
    }
  }

  void _toggleRoute() {
    final property = _property;
    final id = property?.numericId;
    if (property == null || id == null) return;
    final alreadySelected = widget.routes.containsProperty(id);
    var changed = true;
    if (alreadySelected) {
      widget.routes.removeProperty(id);
    } else {
      changed = widget.routes.addProperty(
        RouteDraftProperty.fromDetail(property),
      );
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !changed
              ? widget.routes.errorMessage ?? 'Konut rotaya eklenemedi.'
              : alreadySelected
              ? 'Konut rota taslağından çıkarıldı.'
              : 'Konut rota taslağına eklendi.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final property = _property;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konut detayı'),
        actions: [
          if (property != null)
            AnimatedBuilder(
              animation: widget.favorites,
              builder:
                  (context, _) => IconButton(
                    onPressed:
                        widget.favorites.busyPropertyIds.contains(property.id)
                            ? null
                            : _toggleFavorite,
                    tooltip:
                        property.isFavorite
                            ? 'Favorilerden çıkar'
                            : 'Favorilere ekle',
                    icon: Icon(
                      property.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color:
                          property.isFavorite ? const Color(0xFFE11D48) : null,
                    ),
                  ),
            ),
        ],
      ),
      body:
          property == null
              ? _errorMessage == null
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: _load,
                            child: const Text('Tekrar dene'),
                          ),
                        ],
                      ),
                    ),
                  )
              : _PropertyDetailBody(
                property: property,
                inRoute:
                    property.numericId != null &&
                    widget.routes.containsProperty(property.numericId!),
                onToggleRoute: _toggleRoute,
                highlightedPois: _highlightedPois,
                strengthPoisLoading: _strengthPoisLoading,
                strengthPoisError: _strengthPoisError,
                onRetryStrengthPois: () => _loadStrengthPois(property),
              ),
    );
  }
}

class _PropertyDetailBody extends StatelessWidget {
  const _PropertyDetailBody({
    required this.property,
    required this.inRoute,
    required this.onToggleRoute,
    required this.highlightedPois,
    required this.strengthPoisLoading,
    required this.strengthPoisError,
    required this.onRetryStrengthPois,
  });

  final PropertyDetail property;
  final bool inRoute;
  final VoidCallback onToggleRoute;
  final List<PoiMapItem> highlightedPois;
  final bool strengthPoisLoading;
  final String? strengthPoisError;
  final VoidCallback onRetryStrengthPois;

  @override
  Widget build(BuildContext context) {
    final bandColor = scoreBandColor(property.score.band);
    final mapItem = PropertyMapItem(
      id: property.id,
      externalRef: property.externalRef,
      latitude: property.latitude,
      longitude: property.longitude,
      monthlyRent: property.monthlyRent,
      areaM2: property.areaM2,
      roomCount: property.roomCount,
      totalScore: property.score.total,
      buildingAge: property.features.buildingAge,
      hasElevator: property.features.hasElevator,
      isSynthetic: property.isSynthetic,
    );
    final focus = LocationSearchResult(
      id: 'property-${property.id}',
      label: property.address.formatted,
      kind: 'property',
      latitude: property.latitude,
      longitude: property.longitude,
      source: 'vivido',
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.asset(
                  'assets/images/ev_resmi.png',
                  fit: BoxFit.cover,
                ),
              ),
              const Positioned(
                right: 10,
                bottom: 10,
                child: Chip(label: Text('Temsili görsel')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${property.roomCount} · ${property.areaM2} m²',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.address.formatted.isEmpty
                        ? 'Çankaya / Ankara'
                        : property.address.formatted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${formatPrice(property.monthlyRent)} ₺ / ay',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bandColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    property.score.total.round().toString(),
                    style: TextStyle(
                      color: bandColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 25,
                    ),
                  ),
                  Text(
                    scoreBandLabel(property.score.band),
                    style: TextStyle(color: bandColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (property.isSynthetic) ...[
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Chip(label: Text('Konut verisi sentetiktir')),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: onToggleRoute,
          icon: Icon(inRoute ? Icons.check_circle : Icons.add_road),
          label: Text(inRoute ? 'Rota taslağında' : 'Ziyaret rotasına ekle'),
        ),
        const SizedBox(height: 18),
        Text(
          'Konut özellikleri',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.1,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _FactTile(
              icon: Icons.layers_outlined,
              label: 'Kat',
              value: _formatFloor(
                property.features.floorNo,
                property.features.totalFloors,
              ),
            ),
            _FactTile(
              icon: Icons.apartment,
              label: 'Bina yaşı',
              value:
                  property.features.buildingAge == null
                      ? 'Belirtilmedi'
                      : '${property.features.buildingAge} yıl',
            ),
            _FactTile(
              icon: Icons.square_foot,
              label: 'm² başı kira',
              value:
                  property.features.rentPerM2 == null
                      ? 'Belirtilmedi'
                      : '${formatPrice(property.features.rentPerM2!)} ₺',
            ),
            _FactTile(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Depozito',
              value:
                  property.features.deposit == null
                      ? 'Belirtilmedi'
                      : '${formatPrice(property.features.deposit!)} ₺',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FeatureChip(
              label: 'Asansör',
              enabled: property.features.hasElevator,
            ),
            _FeatureChip(
              label: 'Otopark',
              enabled: property.features.hasParking,
            ),
            _FeatureChip(
              label: 'Eşyalı',
              enabled: property.features.isFurnished,
            ),
            _FeatureChip(
              label: 'Evcil hayvan',
              enabled: property.features.petsAllowed,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bütçe uyumu',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(property.score.budget.message),
                if (property.score.budget.ratioToMax != null) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: property.score.budget.ratioToMax!.clamp(0, 1),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _ScoreReasons(
          title: 'Neden uygun?',
          rows: property.score.strengths,
          color: const Color(0xFF047857),
          emptyText: 'Öne çıkan güçlü bir kriter yok.',
        ),
        const SizedBox(height: 12),
        _ScoreReasons(
          title: 'Neden daha az uygun?',
          rows: property.score.weaknesses,
          color: const Color(0xFFB91C1C),
          emptyText: 'Belirgin bir zayıf yön bulunmuyor.',
        ),
        if (property.score.weakLink != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('Zayıf halka etkisi'),
              subtitle: Text(property.score.weakLink!.message),
              trailing: Text(
                property.score.weakLink!.points.toStringAsFixed(1),
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
        if (property.score.rows.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            child: ExpansionTile(
              title: Text('Tüm kriterler (${property.score.rows.length})'),
              children: [
                for (final row in property.score.rows)
                  ListTile(
                    dense: true,
                    title: Text(row.label),
                    subtitle: Text(
                      '${row.durationMin.toStringAsFixed(1)} dk · '
                      'hedef ${row.targetMin.toStringAsFixed(0)} dk',
                    ),
                    trailing: Text(
                      row.subScore.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'Konum',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (property.score.strengths.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Güçlü yön hizmet noktaları'),
              subtitle: Text(
                strengthPoisLoading
                    ? 'Haritada vurgulanacak noktalar yükleniyor…'
                    : strengthPoisError ??
                        '${highlightedPois.length} nokta haritada gösteriliyor.',
              ),
              trailing:
                  strengthPoisLoading
                      ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : strengthPoisError != null
                      ? IconButton(
                        tooltip: 'Tekrar dene',
                        onPressed: onRetryStrengthPois,
                        icon: const Icon(Icons.refresh),
                      )
                      : null,
            ),
          ),
        if (property.score.strengths.isNotEmpty) const SizedBox(height: 10),
        SizedBox(
          height: 250,
          child: ExcludeFocus(
            child: CankayaMap(
              anchors: const [],
              focus: focus,
              properties: [mapItem],
              highlightedPois: highlightedPois,
              onPoiTap: (poi) => showPoiDetailsSheet(context, poi: poi),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${property.latitude.toStringAsFixed(5)}, '
          '${property.longitude.toStringAsFixed(5)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(enabled ? Icons.check : Icons.close, size: 17),
    label: Text(label),
    side: BorderSide(
      color:
          enabled
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}

class _ScoreReasons extends StatelessWidget {
  const _ScoreReasons({
    required this.title,
    required this.rows,
    required this.color,
    required this.emptyText,
  });

  final String title;
  final List<PropertyScoreRow> rows;
  final Color color;
  final String emptyText;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty) Text(emptyText),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 7, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(row.label)),
                  Text('${row.subScore.toStringAsFixed(0)}/100'),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

String _formatFloor(int? floor, int? total) {
  if (floor == null && total == null) return 'Belirtilmedi';
  if (floor == null) return '$total katlı';
  if (total == null) return '$floor. kat';
  return '$floor / $total';
}
