import 'package:flutter/material.dart';

import '../../../../core/network/network_status_controller.dart';
import '../../../properties/application/property_catalog_controller.dart';
import '../../../properties/domain/property_gateway.dart';
import '../../../properties/presentation/pages/property_detail_page.dart';
import '../../../properties/presentation/widgets/property_summary_card.dart';
import '../../../property_strengths/domain/strength_poi_gateway.dart';
import '../../../routes/application/routes_controller.dart';
import '../../../routes/domain/route_models.dart';
import '../../application/favorites_controller.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    required this.controller,
    required this.propertyGateway,
    required this.propertyCatalog,
    required this.routes,
    required this.strengthPoiGateway,
    required this.networkStatus,
    super.key,
  });

  final FavoritesController controller;
  final PropertyGateway propertyGateway;
  final PropertyCatalogController propertyCatalog;
  final RoutesController routes;
  final StrengthPoiGateway strengthPoiGateway;
  final NetworkStatusController networkStatus;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  Future<void> _openDetail(String propertyId) async {
    if (!_requireOnline('Konut detayı')) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => PropertyDetailPage(
              propertyId: propertyId,
              gateway: widget.propertyGateway,
              favorites: widget.controller,
              routes: widget.routes,
              strengthPoiGateway: widget.strengthPoiGateway,
              onFavoriteChanged: (id, isFavorite) {
                widget.propertyCatalog.updateFavorite(id, isFavorite);
              },
            ),
      ),
    );
    await widget.controller.load(force: true);
  }

  void _toggleRoute(int index) {
    if (!_requireOnline('Rota işlemleri')) return;
    final property = widget.controller.items[index].property;
    final id = property?.numericId;
    if (property == null || id == null) return;
    if (widget.routes.containsProperty(id)) {
      widget.routes.removeProperty(id);
      return;
    }
    final added = widget.routes.addProperty(
      RouteDraftProperty.fromSummary(property),
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

  Future<void> _removeFavorite(String propertyId) async {
    if (!_requireOnline('Favori güncelleme')) return;
    final changed = await widget.controller.setFavorite(propertyId, false);
    if (!mounted) return;
    if (changed) {
      widget.propertyCatalog.updateFavorite(propertyId, false);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.controller.errorMessage ?? 'Favori durumu güncellenemedi.',
        ),
      ),
    );
  }

  bool _requireOnline(String operation) {
    if (!widget.networkStatus.isOffline &&
        !widget.controller.showingCachedData) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$operation internet bağlantısı gerektirir. '
          'Bağlantın geldiğinde tekrar deneyebilirsin.',
        ),
      ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AnimatedBuilder(
      animation: Listenable.merge([widget.controller, widget.routes]),
      builder: (context, _) {
        final controller = widget.controller;
        if (controller.loading && controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage != null && controller.items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(controller.errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => controller.load(force: true),
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => controller.load(force: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Favorilerim',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kaydettiğin konutları inceleyebilir veya ziyaret rotana '
                'ekleyebilirsin.',
              ),
              const SizedBox(height: 14),
              if (controller.showingCachedData) ...[
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const ListTile(
                    leading: Icon(Icons.offline_pin_outlined),
                    title: Text('Çevrimdışı favoriler'),
                    subtitle: Text(
                      'Cihazda daha önce saklanan temel bilgiler gösteriliyor. '
                      'Detay, güncelleme ve rota işlemleri internet gerektirir.',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (controller.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 90),
                  child: Column(
                    children: [
                      const Icon(Icons.favorite_border, size: 52),
                      const SizedBox(height: 12),
                      Text(
                        controller.showingCachedData
                            ? 'Cihazda saklanmış favori bulunamadı.'
                            : 'Henüz favori konutun yok.',
                      ),
                    ],
                  ),
                ),
              for (var index = 0; index < controller.items.length; index++) ...[
                if (controller.items[index].property == null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.home_work_outlined),
                      title: const Text('Bu konut artık listede değil.'),
                      subtitle: Text(
                        'Konut #${controller.items[index].propertyId}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Favorilerden çıkar',
                        onPressed:
                            controller.busyPropertyIds.contains(
                                  controller.items[index].propertyId,
                                )
                                ? null
                                : () => _removeFavorite(
                                  controller.items[index].propertyId,
                                ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PropertySummaryCard(
                      property: controller.items[index].property!,
                      favoriteBusy: controller.busyPropertyIds.contains(
                        controller.items[index].propertyId,
                      ),
                      inRoute: widget.routes.containsProperty(
                        controller.items[index].property!.numericId ?? -1,
                      ),
                      onTap:
                          () => _openDetail(controller.items[index].propertyId),
                      onFavorite:
                          () => _removeFavorite(
                            controller.items[index].propertyId,
                          ),
                      onRoute: () => _toggleRoute(index),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
