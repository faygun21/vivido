import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../favorites/application/favorites_controller.dart';
import '../../../routes/application/routes_controller.dart';
import '../../../routes/domain/route_models.dart';
import '../../../property_strengths/domain/strength_poi_gateway.dart';
import '../../application/property_catalog_controller.dart';
import '../../domain/property_gateway.dart';
import '../../domain/property_models.dart';
import '../widgets/property_summary_card.dart';
import 'property_detail_page.dart';

class PropertyListPage extends StatefulWidget {
  const PropertyListPage({
    required this.controller,
    required this.gateway,
    required this.favorites,
    required this.routes,
    required this.strengthPoiGateway,
    super.key,
  });

  final PropertyCatalogController controller;
  final PropertyGateway gateway;
  final FavoritesController favorites;
  final RoutesController routes;
  final StrengthPoiGateway strengthPoiGateway;

  @override
  State<PropertyListPage> createState() => _PropertyListPageState();
}

class _PropertyListPageState extends State<PropertyListPage> {
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  Future<void> _openDetail(String propertyId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => PropertyDetailPage(
              propertyId: propertyId,
              gateway: widget.gateway,
              favorites: widget.favorites,
              routes: widget.routes,
              strengthPoiGateway: widget.strengthPoiGateway,
              onFavoriteChanged: widget.controller.updateFavorite,
            ),
      ),
    );
  }

  void _toggleRoute(PropertySummary item) {
    final id = item.numericId;
    if (id == null) return;
    final alreadySelected = widget.routes.containsProperty(id);
    if (alreadySelected) {
      widget.routes.removeProperty(id);
      return;
    }
    final added = widget.routes.addProperty(
      RouteDraftProperty.fromSummary(item),
    );
    if (!added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.routes.errorMessage ?? 'Konut rotaya eklenemedi.',
          ),
        ),
      );
    }
  }

  Future<void> _toggleFavorite(PropertySummary item) async {
    final desired = !item.isFavorite;
    final changed = await widget.favorites.setFavorite(item.id, desired);
    if (!mounted) return;
    if (changed) {
      widget.controller.updateFavorite(item.id, desired);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.favorites.errorMessage ?? 'Favori durumu güncellenemedi.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.controller,
          widget.favorites,
          widget.routes,
        ]),
        builder: (context, _) {
          final controller = widget.controller;
          if (controller.loading && controller.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.errorMessage != null && controller.items.isEmpty) {
            return _LoadError(
              message: controller.errorMessage!,
              onRetry: () => controller.load(force: true),
            );
          }
          return RefreshIndicator(
            onRefresh: () => controller.load(force: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'En uygun evler',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.showAll
                      ? 'Çankaya genelinde en yüksek skorlu '
                          '${controller.items.length} konut.'
                      : 'Önemli konumlarının çevresinde, profilin ve bütçene '
                          'göre en yüksek skorlu ${controller.items.length} konut.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),

                _FilterAndSortSection(
                  open: _filtersOpen,
                  controller: controller,
                  onToggle: () => setState(() => _filtersOpen = !_filtersOpen),
                  onClose: () => setState(() => _filtersOpen = false),
                ),
                const SizedBox(height: 10),

                // Anchor koridoru anahtarı — web'deki "Tüm evleri göster"in
                // karşılığı. Filtreyi SUNUCU uyguluyor, o yüzden anahtar
                // listeyi yeniden çekiyor.
                _ShowAllSwitch(
                  value: controller.showAll,
                  busy: controller.loading,
                  onChanged: controller.setShowAll,
                ),
                const SizedBox(height: 12),

                // Liste boşsa NEDENİ ayırt etmek gerekiyor: bütçeye uyan hiç
                // ev mi yok, yoksa evler var ama hiçbiri anchor koridoruna mı
                // düşmüyor? İkincisinde "bütçeni genişlet" demek yanıltıcı
                // olurdu — asıl çözüm koridoru açmak ya da konumları
                // gözden geçirmek.
                if (controller.items.isEmpty)
                  _EmptyState(
                    showAll: controller.showAll,
                    fallback: controller.nearestFallback,
                    onShowAll: () => controller.setShowAll(true),
                    onOpenFallback: (id) => _openDetail(id),
                  ),
                if (controller.items.isNotEmpty &&
                    controller.visibleItems.isEmpty)
                  _FilteredEmptyState(onClear: controller.clearFilters),
                for (final ranked in controller.visibleItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PropertySummaryCard(
                      rank: ranked.rank,
                      property: ranked.property,
                      favoriteBusy: widget.favorites.busyPropertyIds.contains(
                        ranked.property.id,
                      ),
                      inRoute: widget.routes.containsProperty(
                        ranked.property.numericId ?? -1,
                      ),
                      onTap: () => _openDetail(ranked.property.id),
                      onFavorite: () => _toggleFavorite(ranked.property),
                      onRoute: () => _toggleRoute(ranked.property),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterAndSortSection extends StatelessWidget {
  const _FilterAndSortSection({
    required this.open,
    required this.controller,
    required this.onToggle,
    required this.onClose,
  });

  final bool open;
  final PropertyCatalogController controller;
  final VoidCallback onToggle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final activeCount =
        (controller.hasActiveFilter ? 1 : 0) +
        (controller.sortOption != PropertySortOption.score ? 1 : 0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.tune),
            title: const Text(
              'Filtrele ve sırala',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle:
                controller.hasCustomView
                    ? Text(
                      '${controller.visibleItems.length} / '
                      '${controller.items.length} konut gösteriliyor',
                    )
                    : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (activeCount > 0) Badge(label: Text('$activeCount')),
                Icon(open ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            onTap: onToggle,
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Sırala',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final option in PropertySortOption.values)
                        ChoiceChip(
                          label: Text(_sortLabel(option)),
                          selected: controller.sortOption == option,
                          onSelected: (_) => controller.setSortOption(option),
                        ),
                    ],
                  ),
                  if (controller.roomCountOptions.length > 1) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Oda sayısı',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final roomCount in controller.roomCountOptions)
                          FilterChip(
                            label: Text(roomCount),
                            selected: controller.selectedRoomCounts.contains(
                              roomCount,
                            ),
                            onSelected:
                                (_) => controller.toggleRoomCount(roomCount),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            controller.hasActiveFilter
                                ? controller.clearFilters
                                : null,
                        child: const Text('Filtreleri temizle'),
                      ),
                      TextButton(
                        onPressed: onClose,
                        child: const Text('Kapat'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _sortLabel(PropertySortOption option) => switch (option) {
    PropertySortOption.score => 'Öneri (skor)',
    PropertySortOption.rentDescending => 'Kira: Azalan',
    PropertySortOption.rentAscending => 'Kira: Artan',
    PropertySortOption.areaDescending => 'm²: Azalan',
    PropertySortOption.areaAscending => 'm²: Artan',
  };
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        const Icon(Icons.filter_alt_off_outlined, size: 38),
        const SizedBox(height: 10),
        const Text('Bu filtrelerle eşleşen konut yok.'),
        TextButton(onPressed: onClear, child: const Text('Filtreleri temizle')),
      ],
    ),
  );
}

/// "Tüm evleri göster" anahtarı.
class _ShowAllSwitch extends StatelessWidget {
  const _ShowAllSwitch({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.inputBg,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Tüm Çankaya\'yı göster',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
            ),
          ),
          Switch(
            value: value,
            // Yükleme sırasında kilitli: anahtar sunucuya yeni bir istek
            // attırıyor, hızlı ard arda basmak yarış durumu yaratırdı.
            onChanged: busy ? null : onChanged,
          ),
        ],
      ),
    ),
  );
}

/// Liste boşken çıkan durum kartı.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.showAll,
    required this.fallback,
    required this.onShowAll,
    required this.onOpenFallback,
  });

  final bool showAll;
  final PropertySummary? fallback;
  final VoidCallback onShowAll;
  final ValueChanged<String> onOpenFallback;

  @override
  Widget build(BuildContext context) {
    // "Tüm Çankaya" zaten açıksa koridoru suçlayamayız: gerçekten bütçeye
    // uyan ev yok demektir.
    if (showAll) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(
          child: Text(
            'Bütçene uygun konut bulunamadı.\n'
            'Profil sekmesinden kira aralığını genişletebilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkMuted, height: 1.5),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          const Icon(Icons.place_outlined, size: 36, color: AppColors.inkMuted),
          const SizedBox(height: 12),
          const Text(
            'Önemli konumlarının çevresinde bütçene uyan ev çıkmadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inkMuted, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (fallback != null) ...[
            const Text(
              'Alana en yakın ev:',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 8),
            PropertySummaryCard(
              rank: 1,
              property: fallback!,
              favoriteBusy: false,
              inRoute: false,
              onTap: () => onOpenFallback(fallback!.id),
              onFavorite: () {},
              onRoute: () {},
            ),
            const SizedBox(height: 16),
          ],
          OutlinedButton(
            onPressed: onShowAll,
            child: const Text('Tüm Çankaya\'yı göster'),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Tekrar dene'),
          ),
        ],
      ),
    ),
  );
}
