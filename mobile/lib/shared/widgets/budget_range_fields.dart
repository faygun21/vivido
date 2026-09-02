import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

double? parseBudgetInput(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  return normalized.isEmpty ? null : double.tryParse(normalized);
}

class BudgetRangeFields extends StatelessWidget {
  const BudgetRangeFields({
    required this.minController,
    required this.maxController,
    this.enabled = true,
    super.key,
  });

  final TextEditingController minController;
  final TextEditingController maxController;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // ⚠️ Kendi başlığını taşımıyor: hem bu bileşen hem çağıran ekran
    // "Aylık kira aralığı" yazıyordu.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('minimum-monthly-budget'),
                controller: minController,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'En az',
                  suffixText: '₺',
                ),
                validator: _validateBudget,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextFormField(
                key: const ValueKey('maximum-monthly-budget'),
                controller: maxController,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'En çok',
                  suffixText: '₺',
                ),
                validator: (value) {
                  final formatError = _validateBudget(value);
                  if (formatError != null) return formatError;
                  final minimum = parseBudgetInput(minController.text);
                  final maximum = parseBudgetInput(value ?? '');
                  if (minimum != null && maximum != null && minimum > maximum) {
                    return 'Minimumdan az olamaz.';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.info_outline,
              size: 14,
              color: AppColors.inkMuted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'İkisini de boş bırakırsan bütçe filtresi uygulanmaz.',
                style: AppType.muted(AppType.micro).copyWith(letterSpacing: 0),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String? _validateBudget(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return null;
  final parsed = parseBudgetInput(raw);
  if (parsed == null) return 'Geçerli bir sayı gir.';
  if (parsed < 0) return 'Negatif olamaz.';
  return null;
}
