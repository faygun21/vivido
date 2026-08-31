import 'package:flutter/material.dart';

class OffRouteBanner extends StatelessWidget {
  const OffRouteBanner({
    required this.distanceM,
    required this.recalculating,
    this.onRecalculate,
    super.key,
  });

  final double distanceM;
  final bool recalculating;
  final VoidCallback? onRecalculate;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFE0B2),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded),
          const SizedBox(width: 8),
          Expanded(child: Text('Rotadan ${distanceM.round()} m uzaktasın.')),
          if (onRecalculate != null)
            TextButton(
              onPressed: recalculating ? null : onRecalculate,
              child: Text(recalculating ? 'Hesaplanıyor…' : 'Rotayı yenile'),
            ),
        ],
      ),
    ),
  );
}
