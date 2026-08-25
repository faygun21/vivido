import 'package:flutter/material.dart';

import '../../domain/map_data_models.dart';
import '../poi_category_colors.dart';

Future<void> showPoiDetailsSheet(
  BuildContext context, {
  required PoiMapItem poi,
  PoiCategory? category,
}) {
  final categoryName = category?.displayNameTr ?? poi.categoryCode;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: poiCategoryColor(
                        poi.categoryCode,
                      ).withValues(alpha: 0.16),
                      foregroundColor: poiCategoryColor(poi.categoryCode),
                      child: const Icon(Icons.place_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poi.name?.trim().isNotEmpty == true
                                ? poi.name!
                                : 'İsimsiz hizmet noktası',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(categoryName),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Konum: ${poi.latitude.toStringAsFixed(5)}, '
                  '${poi.longitude.toStringAsFixed(5)}',
                ),
              ],
            ),
          ),
        ),
  );
}

Future<void> showPropertyDetailsSheet(
  BuildContext context,
  PropertyMapItem property,
) {
  final score = property.totalScore;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFFFEDD5),
                      foregroundColor: Color(0xFFC2410C),
                      child: Icon(Icons.home_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${property.roomCount} · ${property.areaM2} m²',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${_formatPrice(property.monthlyRent)} ₺ / ay',
                            style: const TextStyle(
                              color: Color(0xFFC2410C),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (score != null) ...[
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.auto_awesome,
                    label: 'Uygunluk skoru',
                    value: '${score.toStringAsFixed(1)} / 100',
                  ),
                ],
                if (property.buildingAge != null)
                  _DetailRow(
                    icon: Icons.apartment,
                    label: 'Bina yaşı',
                    value: '${property.buildingAge}',
                  ),
                if (property.hasElevator != null)
                  _DetailRow(
                    icon: Icons.elevator_outlined,
                    label: 'Asansör',
                    value: property.hasElevator! ? 'Var' : 'Yok',
                  ),
                const SizedBox(height: 10),
                Text(
                  'Konum: ${property.latitude.toStringAsFixed(5)}, '
                  '${property.longitude.toStringAsFixed(5)}',
                ),
                if (property.isSynthetic) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(label: Text('Konut verisi sentetiktir')),
                  ),
                ],
              ],
            ),
          ),
        ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

String _formatPrice(double value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
