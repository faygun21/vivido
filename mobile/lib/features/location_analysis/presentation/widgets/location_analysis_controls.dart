import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/page_parts.dart';
import '../../domain/location_analysis.dart';

final class LocationAnalysisSettings {
  const LocationAnalysisSettings({
    required this.analysisRadiusKm,
    required this.walkingMinutes,
  });

  final double analysisRadiusKm;
  final int walkingMinutes;
}

class LocationAnalysisLauncher extends StatelessWidget {
  const LocationAnalysisLauncher({
    required this.hasSelectedLocation,
    required this.analysisRadiusKm,
    required this.walkingMinutes,
    required this.onOpen,
    required this.onClear,
    super.key,
  });

  final bool hasSelectedLocation;
  final double analysisRadiusKm;
  final int walkingMinutes;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label =
        hasSelectedLocation
            ? '${_formatRadius(analysisRadiusKm)} km · $walkingMinutes dk'
            : 'Konum analizi';

    // Harita üstündeki her kontrol gibi CAM: opak beyaz bir hap, haritayı
    // kesiyordu. Yükseklik de ortak — 48 px (bkz. AppSpacing.mapControl).
    return GlassSurface.thin(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: AppSpacing.mapControl,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              key: const Key('open-location-analysis'),
              onTap: onOpen,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  hasSelectedLocation ? 10 : AppSpacing.sm,
                  0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.radar,
                      size: 19,
                      color:
                          hasSelectedLocation
                              ? AppColors.accent
                              : AppColors.ink,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: AppType.xs.copyWith(
                        fontWeight: AppType.semibold,
                        fontFeatures: AppType.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (hasSelectedLocation) ...[
              const SizedBox(height: 24, child: VerticalDivider(width: 1)),
              IconButton(
                key: const Key('clear-location-analysis'),
                tooltip: 'Analiz alanını temizle',
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<LocationAnalysisSettings?> showLocationAnalysisSettingsSheet(
  BuildContext context, {
  required double analysisRadiusKm,
  required int walkingMinutes,
}) => showAppSheet<LocationAnalysisSettings>(
  context,
  builder:
      (_) => LocationAnalysisSheet(
        analysisRadiusKm: analysisRadiusKm,
        walkingMinutes: walkingMinutes,
      ),
);

class LocationAnalysisSheet extends StatefulWidget {
  const LocationAnalysisSheet({
    required this.analysisRadiusKm,
    required this.walkingMinutes,
    super.key,
  });

  final double analysisRadiusKm;
  final int walkingMinutes;

  @override
  State<LocationAnalysisSheet> createState() => _LocationAnalysisSheetState();
}

class _LocationAnalysisSheetState extends State<LocationAnalysisSheet> {
  late double _analysisRadiusKm;
  late int _walkingMinutes;

  @override
  void initState() {
    super.initState();
    _analysisRadiusKm = widget.analysisRadiusKm;
    _walkingMinutes = widget.walkingMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: 'Konum analizi',
            subtitle: 'Bir noktanın çevresini incele.',
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.radar,
                size: 20,
                color: AppColors.accent,
              ),
            ),
          ),
          // İki alanın ne işe yaradığı ÖNCE, kutular sonra: "Analiz alanı"
          // ve "Yürüme" etiketleri tek başına neyi ölçtüklerini
          // söylemiyordu.
          _LegendRow(
            color: AppColors.mapAnalysis,
            title: 'Analiz alanı',
            description: 'Seçtiğin noktanın etrafındaki inceleme yarıçapı',
          ),
          const SizedBox(height: 6),
          _LegendRow(
            color: AppColors.mapWalking,
            title: 'Yürüme erişimi',
            description: 'Bu sürede yürüyerek ulaşabileceğin yaklaşık alan',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _AnalysisDropdown<double>(
                  dropdownKey: const Key('analysis-radius-dropdown'),
                  label: 'Analiz alanı',
                  value: _analysisRadiusKm,
                  values: analysisRadiusOptionsKm,
                  itemLabel: (value) => '${_formatRadius(value)} km',
                  onChanged: (value) {
                    setState(() => _analysisRadiusKm = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnalysisDropdown<int>(
                  dropdownKey: const Key('walking-minutes-dropdown'),
                  label: 'Yürüme',
                  value: _walkingMinutes,
                  values: walkingMinuteOptions,
                  itemLabel: (value) => '$value dk',
                  onChanged: (value) {
                    setState(() => _walkingMinutes = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.touch_app_outlined,
                size: 16,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Uygula\'ya bastıktan sonra haritada bir noktaya dokun.',
                  style: AppType.muted(AppType.xs),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('apply-location-analysis'),
            onPressed: () {
              Navigator.of(context).pop(
                LocationAnalysisSettings(
                  analysisRadiusKm: _analysisRadiusKm,
                  walkingMinutes: _walkingMinutes,
                ),
              );
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Uygula ve nokta seç'),
          ),
        ],
      ),
    );
  }
}

/// Ayar kutusunun ne çizdiğini gösteren renk açıklaması.
class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.title,
    required this.description,
  });

  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Text.rich(
          TextSpan(
            style: AppType.muted(AppType.xs),
            children: [
              TextSpan(
                text: '$title — ',
                style: AppType.xs.copyWith(fontWeight: AppType.semibold),
              ),
              TextSpan(text: description),
            ],
          ),
        ),
      ),
    ],
  );
}

class _AnalysisDropdown<T> extends StatelessWidget {
  const _AnalysisDropdown({
    required this.dropdownKey,
    required this.label,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
  });

  final Key dropdownKey;
  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: dropdownKey,
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        for (final option in values)
          DropdownMenuItem<T>(value: option, child: Text(itemLabel(option))),
      ],
      onChanged: (nextValue) {
        if (nextValue != null) onChanged(nextValue);
      },
    );
  }
}

String _formatRadius(double radius) {
  return radius == radius.roundToDouble()
      ? radius.toStringAsFixed(0)
      : radius.toStringAsFixed(1);
}
