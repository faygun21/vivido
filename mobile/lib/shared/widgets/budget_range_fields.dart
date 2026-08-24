import 'package:flutter/material.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Aylık kira aralığı (isteğe bağlı)',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
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
                  labelText: 'Minimum',
                  prefixIcon: Icon(Icons.payments_outlined),
                  suffixText: '₺',
                ),
                validator: _validateBudget,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                key: const ValueKey('maximum-monthly-budget'),
                controller: maxController,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Maksimum',
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
        Text(
          'İki alanı da boş bırakırsan bütçe filtresi uygulanmaz.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
