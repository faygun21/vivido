import 'package:flutter/material.dart';

import '../../application/map_data_controller.dart';
import '../poi_category_colors.dart';

class MapLayerButton extends StatelessWidget {
  const MapLayerButton({required this.controller, super.key});

  final MapDataController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 3,
          shape: const CircleBorder(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                key: const ValueKey('map-layer-button'),
                tooltip: 'Harita katmanları',
                onPressed: () => _showLayerSheet(context),
                icon:
                    controller.isLoading || controller.isViewportLoading
                        ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.layers_outlined),
              ),
              if (controller.errorMessage != null)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: 9),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLayerSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _MapLayerSheet(controller: controller),
    );
  }
}

class _MapLayerSheet extends StatelessWidget {
  const _MapLayerSheet({required this.controller});

  final MapDataController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Harita katmanları',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Konutları ve birden fazla hizmet kategorisini birlikte görüntüleyebilirsin.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: controller.propertiesVisible,
                  onChanged: (_) => controller.toggleProperties(),
                  secondary: const _LayerDot(color: Color(0xFFEA580C)),
                  title: const Text('Konutlar'),
                  subtitle: Text('${controller.properties.length} konut'),
                ),
                const Divider(),
                for (final category in controller.categories)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: controller.selectedCategories.contains(
                      category.code,
                    ),
                    onChanged: (_) => controller.toggleCategory(category.code),
                    secondary: _LayerDot(
                      color: poiCategoryColor(category.code),
                    ),
                    title: Text(category.displayNameTr),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                if (controller.categories.isEmpty && !controller.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('POI kategorileri yüklenemedi.'),
                  ),
                if (controller.isLoading || controller.isViewportLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: LinearProgressIndicator(),
                  ),
                if (controller.errorMessage case final message?) ...[
                  const SizedBox(height: 8),
                  Text(message, style: TextStyle(color: colors.error)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: controller.retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tekrar dene'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LayerDot extends StatelessWidget {
  const _LayerDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
      child: const SizedBox.square(dimension: 18),
    );
  }
}
