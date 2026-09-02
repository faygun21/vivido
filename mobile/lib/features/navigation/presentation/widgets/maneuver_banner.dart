import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../properties/presentation/property_format.dart';
import '../../domain/maneuver_text.dart';

/// Navigasyonun üst manevra kartı (R-54).
///
/// ⚠️ NAVİGASYON EKRANI SÜRÜŞ SIRASINDA OKUNUYOR
///
/// Bu kart yolda, tek göz atışında okunmak zorunda. Eski hâli bir
/// `Card` + `titleMedium` idi; manevra metni ile mesafe aynı ağırlıktaydı
/// ve gözün önce nereye bakacağı belli değildi.
///
/// Yeni hiyerarşi: MESAFE en büyük (ne zaman dönmem lazım?), manevra
/// metni ikinci (ne yapmam lazım?), yol adı üçüncü (nereye?).
///
/// ⚠️ MESAFE SABİT GENİŞLİKLİ RAKAMLA. Sayaç saniyede bir güncelleniyor
/// ve orantısal rakamla metin sürekli sağa sola oynuyordu — sürüşte
/// okunamıyordu.
class ManeuverBanner extends StatelessWidget {
  const ManeuverBanner({
    required this.instruction,
    required this.distanceM,
    this.roadName,
    super.key,
  });

  final ManeuverInstruction? instruction;
  final double? distanceM;
  final String? roadName;

  @override
  Widget build(BuildContext context) {
    // Manevra YAKLAŞTIKÇA kart vurgulanıyor: 60 m altında dolu accent.
    // "Şimdi dön" anını renkle söylemek, metni okumaktan hızlı.
    final imminent = distanceM != null && distanceM! < 60;

    return AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.easeOut,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: imminent ? AppColors.accent : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color:
                  imminent
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.base,
              child: Icon(
                _icon(instruction?.icon),
                key: ValueKey(instruction?.icon),
                size: 30,
                color: imminent ? Colors.white : AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  distanceM == null ? '—' : formatDistance(distanceM!.round()),
                  style: AppType.h1.copyWith(
                    fontSize: 26,
                    height: 1.1,
                    color: imminent ? Colors.white : AppColors.ink,
                    fontFeatures: AppType.tabularFigures,
                  ),
                ),
                Text(
                  instruction?.text ?? 'Konum bekleniyor…',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sm.copyWith(
                    fontWeight: AppType.semibold,
                    color: imminent ? Colors.white : AppColors.ink,
                  ),
                ),
                if (roadName?.trim().isNotEmpty == true)
                  Text(
                    roadName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.xs.copyWith(
                      color:
                          imminent
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppColors.inkMuted,
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

IconData _icon(ManeuverIconKind? kind) => switch (kind) {
  ManeuverIconKind.left => Icons.turn_left,
  ManeuverIconKind.right => Icons.turn_right,
  ManeuverIconKind.slightLeft => Icons.turn_slight_left,
  ManeuverIconKind.slightRight => Icons.turn_slight_right,
  ManeuverIconKind.sharpLeft => Icons.turn_sharp_left,
  ManeuverIconKind.sharpRight => Icons.turn_sharp_right,
  ManeuverIconKind.uTurn => Icons.u_turn_left,
  ManeuverIconKind.merge => Icons.merge,
  ManeuverIconKind.ramp => Icons.ramp_right,
  ManeuverIconKind.roundabout => Icons.roundabout_right,
  ManeuverIconKind.arrive => Icons.flag,
  _ => Icons.straight,
};
