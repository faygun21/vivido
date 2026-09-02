import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/brand_icon.dart';
import '../../../map_data/presentation/poi_category_colors.dart';
import '../../domain/life_criteria.dart';

/// Yaşam kriterlerinin önem sıralaması (R-16).
///
/// ⚠️ NELER DEĞİŞTİ
///
/// 1. **Kendi başlığını taşımıyor.** Hem bu bileşen hem çağıran ekran
///    "Yaşam kriterleri ve önem sırası" yazıyordu — aynı başlık iki kez.
///    Başlık artık çağıranın sorumluluğu ([SectionHeader]).
///
/// 2. **Kriterler HARİTADAKİ renk ve ikonlarını taşıyor.** Bunlar POI
///    kategorileriyle aynı şeyler (market, eczane, park…) ama listede
///    numaralı gri dairelerdi; kullanıcı "park" satırının haritadaki
///    yeşil noktalarla aynı şey olduğunu göremiyordu.
///
/// 3. **Göreli önem çubukla.** "Göreli önem: %22" satırı ile bir alttaki
///    "%19" arasındaki fark okunmuyordu; çubuk bunu bir bakışta veriyor.
class LifeCriteriaOrderList extends StatelessWidget {
  const LifeCriteriaOrderList({
    required this.categoryOrder,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<String> categoryOrder;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (categoryOrder.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.bad.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          'Bu persona için yaşam kriterleri yüklenemedi.',
          style: AppType.sm.copyWith(color: AppColors.bad),
        ),
      );
    }

    // En yüksek önem, çubukları oranlamak için: en üstteki her zaman dolu
    // görünsün, aradaki farklar okunur kalsın.
    final topShare = lifeCriterionImportancePercent(0, categoryOrder.length);

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: categoryOrder.length,
      onReorderItem:
          enabled
              ? (oldIndex, newIndex) {
                final reordered = List<String>.of(categoryOrder);
                final item = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, item);
                onChanged(List.unmodifiable(reordered));
              }
              : (_, _) {},
      itemBuilder: (context, index) {
        final code = categoryOrder[index];
        final importance = lifeCriterionImportancePercent(
          index,
          categoryOrder.length,
        );
        final color = poiCategoryColor(code);
        final iconAsset = poiCategoryIconAssets[code];

        return Padding(
          key: ValueKey('life-criterion-$code'),
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Text(
                  '${index + 1}',
                  style: AppType.micro.copyWith(
                    letterSpacing: 0,
                    fontFeatures: AppType.tabularFigures,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Haritadaki POI pininin küçültülmüş hâli.
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: BrandIcon(
                      iconAsset == null
                          ? 'poi_generic_white.svg'
                          : iconAsset.split('/').last,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lifeCriterionLabel(code),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sm.copyWith(
                          fontWeight: AppType.medium,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end:
                                      topShare == 0
                                          ? 0
                                          : importance / topShare,
                                ),
                                duration: AppMotion.base,
                                curve: AppMotion.easeOut,
                                builder:
                                    (context, value, _) =>
                                        LinearProgressIndicator(
                                          value: value,
                                          minHeight: 4,
                                          color: color,
                                          backgroundColor: AppColors.inputBg,
                                        ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 30,
                            child: Text(
                              '%$importance',
                              textAlign: TextAlign.right,
                              style: AppType.micro.copyWith(
                                letterSpacing: 0,
                                fontFeatures: AppType.tabularFigures,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ReorderableDragStartListener(
                  key: ValueKey('life-criterion-drag-$code'),
                  index: index,
                  enabled: enabled,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: AppColors.line,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
