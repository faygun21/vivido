import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/favorite_button.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../../../shared/widgets/score_badge.dart';
import '../../domain/property_models.dart';
import '../property_format.dart';

/// Konut kartı — liste, favoriler ve boş durum önerisi aynı kartı kullanır.
///
/// ⚠️ NELER DEĞİŞTİ
///
/// 1. **Adres iki satıra bölündü.** Kart en belirgin metin olarak
///    "Çankaya, Ankara" yazıyordu — her kartta aynı, hiçbir şey anlatmayan
///    bir satır. Artık sokak adı başlık gibi öne çıkıyor, mahalle/ilçe
///    altta soluk kalıyor (web `splitAddress` ile aynı).
///
/// 2. **Fiyat asıl başlık oldu.** Kiralık ev ararken ilk bakılan sayı kira;
///    kartın en büyük metni "3+1 · 95 m²" idi.
///
/// 3. **Güçlü/zayıf yön satırları rozetleşti.** Düz renkli metinlerdi
///    (`#047857` / `#B91C1C` — paletin dışında iki renk) ve gövde metniyle
///    aynı ağırlıktaydılar.
///
/// 4. **Eylem satırı hizalandı.** Favori kalbi ve "Rotaya ekle" sağa
///    yaslanmış iki ayrı bileşendi; şimdi kartın alt şeridinde, aralarında
///    ayraçla.
class PropertySummaryCard extends StatelessWidget {
  const PropertySummaryCard({
    required this.property,
    required this.onTap,
    required this.onFavorite,
    required this.onRoute,
    this.favoriteBusy = false,
    this.inRoute = false,
    this.rank,
    super.key,
  });

  final PropertySummary property;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onRoute;
  final bool favoriteBusy;
  final bool inRoute;

  /// Skor sıralamasındaki yeri. Filtre/sıralama değişse bile ÖZGÜN sıra
  /// korunuyor: "bu ev skor listesinde 3. sırada" bilgisi, kira sırasına
  /// geçildiğinde de anlamlı.
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final address = splitAddress(property.address);

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: inRoute ? AppColors.mapRoute.withValues(alpha: 0.45) : AppColors.border,
            width: inRoute ? 1.5 : 1,
          ),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rank != null) ...[
                    _RankBadge(rank!),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${formatRent(property.monthlyRent)} / ay',
                          style: AppType.h3.copyWith(
                            fontSize: 17,
                            fontWeight: AppType.bold,
                            letterSpacing: -0.3,
                            fontFeatures: AppType.tabularFigures,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${property.roomCount} · ${property.areaM2} m²',
                          style: AppType.sm.copyWith(
                            fontWeight: AppType.medium,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          address.primary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.muted(AppType.xs),
                        ),
                        if (address.secondary.isNotEmpty)
                          Text(
                            address.secondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.muted(AppType.micro).copyWith(
                              letterSpacing: 0,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ScoreBadge(
                    total: property.totalScore,
                    band: property.band,
                    animate: false,
                  ),
                ],
              ),
            ),

            // ── Gerekçe rozetleri ──────────────────────────────────────
            // Skorun NEDENİ karta sığmıyor; en güçlü ve en zayıf tek
            // kriter yeterli bir ipucu. Detay için kart açılıyor.
            if (property.topStrength != null || property.topWeakness != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (property.topStrength case final strength?)
                      _ReasonChip(text: strength, positive: true),
                    if (property.topWeakness case final weakness?)
                      _ReasonChip(text: weakness, positive: false),
                  ],
                ),
              ),

            const Divider(height: 1),

            // ── Eylem şeridi ───────────────────────────────────────────
            Row(
              children: [
                FavoriteButton(
                  isFavorite: property.isFavorite,
                  busy: favoriteBusy,
                  onPressed: onFavorite,
                  size: 20,
                ),
                const SizedBox(
                  height: 20,
                  child: VerticalDivider(width: 1),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onRoute,
                    icon: AnimatedSwitcher(
                      duration: AppMotion.fast,
                      child: Icon(
                        inRoute
                            ? Icons.check_circle
                            : Icons.add_location_alt_outlined,
                        key: ValueKey(inRoute),
                        size: 17,
                      ),
                    ),
                    label: Text(inRoute ? 'Rotada' : 'Rotaya ekle'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          inRoute ? AppColors.mapRoute : AppColors.inkMuted,
                      minimumSize: const Size.fromHeight(42),
                      shape: const RoundedRectangleBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skor sırası rozeti.
class _RankBadge extends StatelessWidget {
  const _RankBadge(this.rank);

  final int rank;

  @override
  Widget build(BuildContext context) {
    // İlk üç DOLU accent, gerisi soluk: "en uygun üç ev" bir liste
    // başlığı yazmadan görünüyor.
    final top = rank <= 3;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: top ? AppColors.accent : AppColors.inputBg,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: AppType.micro.copyWith(
          color: top ? AppColors.accentInk : AppColors.inkMuted,
          letterSpacing: 0,
          fontSize: 11,
          fontFeatures: AppType.tabularFigures,
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.text, required this.positive});

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.ok : AppColors.bad;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.check_rounded : Icons.remove_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: AppType.micro.copyWith(color: color, letterSpacing: 0),
          ),
        ],
      ),
    );
  }
}
