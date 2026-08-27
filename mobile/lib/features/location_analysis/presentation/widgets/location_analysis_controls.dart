import 'package:flutter/material.dart';

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
    final colors = Theme.of(context).colorScheme;
    final label =
        hasSelectedLocation
            ? '${_formatRadius(analysisRadiusKm)} km · $walkingMinutes dk'
            : 'Konum analizi';

    return Material(
      elevation: 3,
      color: colors.surface,
      shadowColor: colors.shadow.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const Key('open-location-analysis'),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.radar, size: 20, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.tune, size: 18),
                ],
              ),
            ),
          ),
          if (hasSelectedLocation) ...[
            SizedBox(
              height: 28,
              child: VerticalDivider(width: 1, color: colors.outlineVariant),
            ),
            IconButton(
              key: const Key('clear-location-analysis'),
              tooltip: 'Analiz alanını temizle',
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 19),
            ),
          ],
        ],
      ),
    );
  }
}

Future<LocationAnalysisSettings?> showLocationAnalysisSettingsSheet(
  BuildContext context, {
  required double analysisRadiusKm,
  required int walkingMinutes,
}) => showModalBottomSheet<LocationAnalysisSettings>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  sheetAnimationStyle: AnimationStyle.noAnimation,
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
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: const Icon(Icons.radar),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konum analizi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text('Analiz alanını ve yürüme süresini ayarla.'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 12),
          Text(
            'Ayarlar seçili konuma uygulanır. Konum seçili değilse haritaya dokun veya bir konum ara.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const Key('apply-location-analysis'),
                  onPressed: () {
                    Navigator.of(context).pop(
                      LocationAnalysisSettings(
                        analysisRadiusKm: _analysisRadiusKm,
                        walkingMinutes: _walkingMinutes,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Uygula'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
