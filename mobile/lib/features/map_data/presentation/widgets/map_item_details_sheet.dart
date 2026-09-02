import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/brand_icon.dart';
import '../../../../shared/widgets/page_parts.dart';
import '../../../../shared/widgets/score_badge.dart';
import '../../../properties/presentation/property_format.dart';
import '../../domain/map_data_models.dart';
import '../poi_category_colors.dart';

/// Haritada bir hizmet noktasına dokununca açılan alt sayfa (R-31).
///
/// ⚠️ HER KATEGORİ AYNI İKONLA GÖSTERİLİYORDU
///
/// Başlıktaki daire, kategori renginde ama içinde her zaman
/// `Icons.place_outlined` vardı — haritada market kırmızı bir daire +
/// beyaz alışveriş simgesiyken, alt sayfada aynı market kırmızı bir daire
/// + jenerik bir konum iğnesi oluyordu. Kullanıcı dokunduğu şeyle açılan
/// kartı eşleştiremiyordu. Artık haritadaki İKONUN AYNISI.
Future<void> showPoiDetailsSheet(
  BuildContext context, {
  required PoiMapItem poi,
  PoiCategory? category,
}) {
  final color = poiCategoryColor(poi.categoryCode);
  final iconAsset = poiCategoryIconAssets[poi.categoryCode];

  return showAppSheet<void>(
    context,
    builder:
        (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Haritadaki pinle BİREBİR aynı: renkli dolu daire +
                    // beyaz kategori ikonu.
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: AppShadows.xs,
                      ),
                      child: Center(
                        child: BrandIcon(
                          iconAsset == null
                              ? 'poi_generic_white.svg'
                              : iconAsset.split('/').last,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poi.name?.trim().isNotEmpty == true
                                ? poi.name!
                                : 'İsimsiz hizmet noktası',
                            style: AppType.h3,
                          ),
                          Text(
                            category?.displayNameTr ?? poi.categoryCode,
                            style: AppType.muted(AppType.xs),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _CoordinateRow(
                  latitude: poi.latitude,
                  longitude: poi.longitude,
                ),
              ],
            ),
          ),
        ),
  );
}

/// Haritada bir konuta dokununca açılan özet — MİSAFİR akışı.
///
/// Giriş yapan kullanıcı doğrudan tam detay sayfasına gidiyor; misafirin
/// skoru olmadığı için ona bu özet gösteriliyor ve neyin kilitli olduğu
/// söyleniyor.
Future<void> showPropertyDetailsSheet(
  BuildContext context,
  PropertyMapItem property, {
  VoidCallback? onUnlock,
}) {
  return showAppSheet<void>(
    context,
    builder:
        (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.mapProperty,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: BrandIcon(
                          'home_white.svg',
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${formatRent(property.monthlyRent)} / ay',
                            style: AppType.h3.copyWith(
                              fontSize: 18,
                              fontFeatures: AppType.tabularFigures,
                            ),
                          ),
                          Text(
                            '${property.roomCount} · ${property.areaM2} m²',
                            style: AppType.muted(AppType.sm),
                          ),
                        ],
                      ),
                    ),
                    if (property.totalScore case final score?)
                      ScoreBadge(
                        total: score,
                        band: scoreBandOf(score),
                        animate: false,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _FactRow(
                  icon: Icons.apartment,
                  label: 'Bina yaşı',
                  value:
                      property.buildingAge == null
                          ? '—'
                          : '${property.buildingAge} yıl',
                ),
                _FactRow(
                  icon: Icons.elevator_outlined,
                  label: 'Asansör',
                  value: switch (property.hasElevator) {
                    true => 'Var',
                    false => 'Yok',
                    null => '—',
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                _CoordinateRow(
                  latitude: property.latitude,
                  longitude: property.longitude,
                ),

                // Kilitli skor: misafire NEYİ kaçırdığını gösteriyoruz.
                if (onUnlock != null && property.totalScore == null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Bu evin sana uygunluk skoru ve gerekçesi hesap '
                            'ile açılıyor.',
                            style: AppType.xs.copyWith(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  FilledButton(
                    onPressed: onUnlock,
                    child: const Text('Ücretsiz hesap oluştur'),
                  ),
                ],

                if (property.isSynthetic) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Konut verisi sentetiktir — gerçek ilan değildir.',
                    style: AppType.muted(AppType.micro).copyWith(
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
  );
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.inkMuted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(label, style: AppType.sm)),
        Text(
          value,
          style: AppType.sm.copyWith(fontWeight: AppType.semibold),
        ),
      ],
    ),
  );
}

/// Koordinat satırı.
///
/// Ham "39.90123, 32.85431" bir kullanıcı bilgisi değil, geliştirici
/// bilgisi. Yine de kalıyor (mentor doğrulaması için) ama artık mikro
/// boyutta ve soluk — sayfanın gövdesi değil, dipnotu.
class _CoordinateRow extends StatelessWidget {
  const _CoordinateRow({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.place_outlined, size: 13, color: AppColors.inkMuted),
      const SizedBox(width: 4),
      Text(
        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
        style: AppType.muted(AppType.micro).copyWith(
          letterSpacing: 0,
          fontFeatures: AppType.tabularFigures,
        ),
      ),
    ],
  );
}
