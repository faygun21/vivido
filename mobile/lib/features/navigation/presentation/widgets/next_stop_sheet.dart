import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../properties/presentation/property_format.dart';
import '../../../routes/domain/route_models.dart';

/// Navigasyonun alt "sıradaki durak" kartı (R-54).
///
/// ⚠️ İLERLEME GÖRÜNMÜYORDU. "2/5" tek satırlık bir metnin içinde,
/// mahalle adı ve metrekareyle aynı ağırlıkta kayboluyordu — kullanıcı
/// rotanın neresinde olduğunu göremiyordu. Artık üstte bir ilerleme
/// çubuğu ve ayrı bir sayaç var.
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
  Widget build(BuildContext context) {
    final sequence = stop?.sequence;
    final progress =
        sequence == null || totalStops == 0
            ? 1.0
            : (sequence - (arrived ? 0 : 1)) / totalStops;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.lg,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // İlerleme çubuğu kartın TEPESİNDE, kenardan kenara: rotanın
          // ne kadarının bittiğini tek bakışta gösteriyor.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0, 1)),
            duration: AppMotion.slow,
            curve: AppMotion.easeOut,
            builder:
                (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 3,
                  color: arrived ? AppColors.ok : AppColors.mapRoute,
                  backgroundColor: AppColors.inputBg,
                ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppMotion.base,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        arrived
                            ? AppColors.ok.withValues(alpha: 0.14)
                            : AppColors.mapRoute.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    arrived ? Icons.check_rounded : Icons.home_work_outlined,
                    size: 20,
                    color: arrived ? AppColors.ok : AppColors.mapRoute,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              arrived
                                  ? 'Konut konumuna ulaştın'
                                  : 'Sıradaki konut',
                              style: AppType.sm.copyWith(
                                fontWeight: AppType.semibold,
                                color: arrived ? AppColors.ok : AppColors.ink,
                              ),
                            ),
                          ),
                          if (sequence != null)
                            Text(
                              '$sequence / $totalStops',
                              style: AppType.micro.copyWith(
                                letterSpacing: 0,
                                fontFeatures: AppType.tabularFigures,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        stop == null
                            ? 'Rota tamamlanıyor'
                            : [
                              stop!.property.neighborhood,
                              '${stop!.property.roomCount} · '
                                  '${stop!.property.areaM2} m²',
                            ].whereType<String>().join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.muted(AppType.xs),
                      ),
                      if (distanceM != null || etaSeconds != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (distanceM != null) ...[
                              const Icon(
                                Icons.straighten,
                                size: 13,
                                color: AppColors.inkMuted,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                formatDistance(distanceM!.round()),
                                style: AppType.xs.copyWith(
                                  fontWeight: AppType.semibold,
                                  fontFeatures: AppType.tabularFigures,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            if (etaSeconds != null) ...[
                              const Icon(
                                Icons.schedule,
                                size: 13,
                                color: AppColors.inkMuted,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                formatDuration(etaSeconds!),
                                style: AppType.xs.copyWith(
                                  fontWeight: AppType.semibold,
                                  fontFeatures: AppType.tabularFigures,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
