import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../properties/presentation/property_format.dart';
import '../../../routes/domain/route_models.dart';

class NextStopSheet extends StatelessWidget {
  const NextStopSheet({
    required this.stop,
    required this.totalStops,
    required this.distanceM,
    required this.etaSeconds,
    required this.arrived,
    super.key,
  });

  final RouteStop? stop;
  final int totalStops;
  final double? distanceM;
  final int? etaSeconds;
  final bool arrived;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                arrived
                    ? const Color(0xFFD1FAE5)
                    : Theme.of(context).colorScheme.primaryContainer,
            child: Icon(arrived ? Icons.check : Icons.home_work_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  arrived ? 'Konut konumuna ulaştın' : 'Sıradaki konut',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  stop == null
                      ? 'Rota tamamlanıyor'
                      : [
                        '${stop!.sequence}/$totalStops',
                        stop!.property.neighborhood,
                        '${stop!.property.roomCount} · ${stop!.property.areaM2} m²',
                        if (distanceM != null)
                          formatDistance(distanceM!.round()),
                        if (etaSeconds != null) formatDuration(etaSeconds!),
                      ].whereType<String>().join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.gps_fixed, color: Color(0xFF1D74F5)),
        ],
      ),
    ),
  );
}
