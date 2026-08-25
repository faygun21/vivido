import 'package:flutter/material.dart';

import '../../domain/location_analysis.dart';

class LocationAnalysisControls extends StatelessWidget {
  const LocationAnalysisControls({
    required this.hasSelectedLocation,
    required this.analysisRadiusKm,
    required this.walkingMinutes,
    required this.onAnalysisRadiusChanged,
    required this.onWalkingMinutesChanged,
    required this.onClear,
    super.key,
  });

  final bool hasSelectedLocation;
  final double analysisRadiusKm;
  final int walkingMinutes;
  final ValueChanged<double> onAnalysisRadiusChanged;
  final ValueChanged<int> onWalkingMinutesChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.radar, size: 20),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Konum analizi',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (hasSelectedLocation)
                  IconButton(
                    key: const Key('clear-location-analysis'),
                    tooltip: 'Analiz alanını temizle',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClear,
                    icon: const Icon(Icons.close, size: 20),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _AnalysisDropdown<double>(
                    dropdownKey: const Key('analysis-radius-dropdown'),
                    label: 'Analiz alanı',
                    value: analysisRadiusKm,
                    values: analysisRadiusOptionsKm,
                    itemLabel: (value) => '${_formatRadius(value)} km',
                    onChanged: onAnalysisRadiusChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AnalysisDropdown<int>(
                    dropdownKey: const Key('walking-minutes-dropdown'),
                    label: 'Yürüme',
                    value: walkingMinutes,
                    values: walkingMinuteOptions,
                    itemLabel: (value) => '$value dk',
                    onChanged: onWalkingMinutesChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _statusText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String get _statusText {
    if (!hasSelectedLocation) {
      return 'Alanı görmek için haritaya dokun veya konum ara.';
    }
    if (walkingMinutes >= 15) {
      return '$walkingMinutes dakikalık yaklaşık yürüme alanı gösteriliyor.';
    }
    return '$walkingMinutes dakikalık yürüme alanı gösteriliyor.';
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
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: dropdownKey,
          value: value,
          isDense: true,
          isExpanded: true,
          items: [
            for (final option in values)
              DropdownMenuItem<T>(
                value: option,
                child: Text(itemLabel(option)),
              ),
          ],
          onChanged: (nextValue) {
            if (nextValue != null) onChanged(nextValue);
          },
        ),
      ),
    );
  }
}

String _formatRadius(double radius) {
  return radius == radius.roundToDouble()
      ? radius.toStringAsFixed(0)
      : radius.toStringAsFixed(1);
}
