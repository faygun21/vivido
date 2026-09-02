import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';

/// Rotadan sapma uyarısı (R-55).
///
/// ⚠️ Renk paletin DIŞINDAYDI (`#FFE0B2` — Material amber 100). Krem
/// zeminde ve turuncu accent'in yanında ikinci bir sarı, ekranı
/// karıştırıyordu. Artık `--warn` ailesinden.
///
/// Şerit dokunuşu ENGELLEMİYOR: navigasyon sırasında ekranın üstünü
/// kapatan bir uyarı, haritayı okunmaz yapardı — bu yüzden ince ve
/// yalnızca gerektiğinde.
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
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.base,
    curve: AppMotion.easeOut,
    builder:
        (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -8 * (1 - value)),
            child: child,
          ),
        ),
    child: Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.warn,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.md,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 19,
            color: Colors.white,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Rotadan ${distanceM.round()} m uzaktasın.',
              style: AppType.xs.copyWith(
                color: Colors.white,
                fontWeight: AppType.semibold,
                fontFeatures: AppType.tabularFigures,
              ),
            ),
          ),
          if (onRecalculate != null)
            TextButton(
              onPressed: recalculating ? null : onRecalculate,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white70,
                minimumSize: const Size(0, 34),
              ),
              child: Text(recalculating ? 'Hesaplanıyor…' : 'Yenile'),
            ),
        ],
      ),
    ),
  );
}
