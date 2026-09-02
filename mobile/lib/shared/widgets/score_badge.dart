import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../features/properties/presentation/property_format.dart';

/// Skor rozeti — konut kartı, detay sayfası ve harita alt sayfası aynı
/// rozeti kullanır.
///
/// Üç yerde ayrı ayrı yazılmıştı ve üçü de farklıydı: kartta 18 px kalın
/// sayı + 10 px etiket, detayda 25 px + varsayılan etiket, alt sayfada
/// hiç rozet yok, düz bir satır ("Uygunluk skoru 72,4 / 100"). Aynı sayı
/// üç ayrı biçimde okunuyordu.
///
/// ⚠️ RENK BANT BAŞINA — sayı tek başına anlamlı değil.
/// "77" iyi mi kötü mü? Bandın rengi ve etiketi bu soruyu cevaplıyor;
/// rozet ikisini birden taşımak zorunda.
enum ScoreBadgeSize {
  /// Liste kartı.
  compact,

  /// Detay sayfası başlığı.
  large,
}

class ScoreBadge extends StatelessWidget {
  const ScoreBadge({
    required this.total,
    required this.band,
    this.size = ScoreBadgeSize.compact,
    this.animate = true,
    super.key,
  });

  final double total;
  final String band;
  final ScoreBadgeSize size;

  /// Sayı sıfırdan hedefe sayarak gelsin mi.
  ///
  /// Sayaç yalnızca detay sayfasında açık: uzun bir listede otuz kartın
  /// aynı anda sayması gürültü olur, sayının kendisi okunamaz.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final color = scoreBandColor(band);
    final large = size == ScoreBadgeSize.large;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? AppSpacing.sm : 10,
        vertical: large ? 10 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(large ? AppRadius.md : AppRadius.sm),
        // İnce kenar, açık zeminde rozetin sınırını belli ediyor: yalnızca
        // %12 dolgu, beyaz kartın üstünde bir "leke" gibi duruyordu.
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedScore(
            total: total,
            animate: animate,
            style: (large ? AppType.h1 : AppType.h2).copyWith(
              color: color,
              fontWeight: AppType.bold,
              fontSize: large ? 26 : 19,
              height: 1.1,
              letterSpacing: -0.5,
              fontFeatures: AppType.tabularFigures,
            ),
          ),
          Text(
            scoreBandLabel(band),
            style: AppType.micro.copyWith(
              color: color,
              fontSize: large ? 11 : 10,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Skoru sıfırdan hedefe sayan metin.
///
/// Sayaç bir süs değil: sayının BÜYÜKLÜĞÜNÜ hissettiriyor. 42 ile 92
/// arasındaki fark durağan iki rakamda göze çarpmıyor, sayarken çarpıyor.
/// Sabit genişlikli rakamlar (`tabularFigures`) şart — yoksa sayarken
/// metnin genişliği değişir ve rozet titrer.
class _AnimatedScore extends StatelessWidget {
  const _AnimatedScore({
    required this.total,
    required this.animate,
    required this.style,
  });

  final double total;
  final bool animate;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final text = total.round().toString();
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      return Text(text, style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: total),
      duration: AppMotion.page,
      curve: AppMotion.easeOut,
      builder:
          (context, value, _) => Text(value.round().toString(), style: style),
    );
  }
}

/// Skor bandını gösteren ince çip — rozet için yer olmayan yerlerde
/// (rota durağı satırı, arama sonucu) kullanılır.
class BandChip extends StatelessWidget {
  const BandChip({required this.band, super.key});

  final String band;

  @override
  Widget build(BuildContext context) {
    final color = scoreBandColor(band);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        scoreBandLabel(band),
        style: AppType.micro.copyWith(color: Colors.white, letterSpacing: 0.2),
      ),
    );
  }
}
