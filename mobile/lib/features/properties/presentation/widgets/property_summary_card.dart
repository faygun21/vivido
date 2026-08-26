import 'package:flutter/material.dart';

import '../../domain/property_models.dart';
import '../property_format.dart';

class PropertySummaryCard extends StatelessWidget {
  const PropertySummaryCard({
    required this.property,
    required this.onTap,
    required this.onFavorite,
    required this.onRoute,
    this.favoriteBusy = false,
    this.inRoute = false,
    this.rank,
    super.key,
  });

  final PropertySummary property;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onRoute;
  final bool favoriteBusy;
  final bool inRoute;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final bandColor = scoreBandColor(property.band);
    final address =
        property.address.formatted.trim().isEmpty
            ? 'Çankaya / Ankara'
            : property.address.formatted;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rank != null) ...[
                    CircleAvatar(
                      radius: 17,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        '$rank',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${property.roomCount} · ${property.areaM2} m²',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: bandColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          property.totalScore.round().toString(),
                          style: TextStyle(
                            color: bandColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          scoreBandLabel(property.band),
                          style: TextStyle(color: bandColor, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${formatPrice(property.monthlyRent)} ₺ / ay',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (property.topStrength != null) ...[
                const SizedBox(height: 7),
                Text(
                  '✓ ${property.topStrength}',
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontSize: 12,
                  ),
                ),
              ],
              if (property.topWeakness != null) ...[
                const SizedBox(height: 3),
                Text(
                  '✕ ${property.topWeakness}',
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: favoriteBusy ? null : onFavorite,
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
                  TextButton.icon(
                    onPressed: onRoute,
                    icon: Icon(inRoute ? Icons.check_circle : Icons.add_road),
                    label: Text(inRoute ? 'Rotada' : 'Rotaya ekle'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
