import 'package:flutter/material.dart';

import '../../../favorites/application/favorites_controller.dart';
import '../../../routes/application/routes_controller.dart';
import '../../../routes/domain/route_models.dart';
import '../../../property_strengths/domain/strength_poi_gateway.dart';
import '../../application/property_catalog_controller.dart';
import '../../domain/property_gateway.dart';
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

  void _toggleRoute(int index) {
    final item = widget.controller.items[index];
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

  Future<void> _toggleFavorite(int index) async {
    final item = widget.controller.items[index];
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
                  'Profilin ve bütçene göre en yüksek skorlu '
                  '${controller.items.length} konut.',
                ),
                const SizedBox(height: 12),
                if (controller.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('Bütçene uygun konut bulunamadı.'),
                    ),
                  ),
                for (var index = 0; index < controller.items.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PropertySummaryCard(
                      rank: index + 1,
                      property: controller.items[index],
                      favoriteBusy: widget.favorites.busyPropertyIds.contains(
                        controller.items[index].id,
                      ),
                      inRoute: widget.routes.containsProperty(
                        controller.items[index].numericId ?? -1,
                      ),
                      onTap: () => _openDetail(controller.items[index].id),
                      onFavorite: () => _toggleFavorite(index),
                      onRoute: () => _toggleRoute(index),
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
