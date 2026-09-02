import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/brand_icon.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/page_parts.dart';
import '../../application/map_data_controller.dart';
import '../poi_category_colors.dart';

/// Harita katmanları düğmesi.
///
/// Artık ortak [MapCircleButton] kullanıyor: eskiden kendi `Material` +
/// `IconButton` sarmalı vardı ve yanındaki konum düğmesiyle farklı boyut,
/// farklı gölge, farklı dokunma hedefindeydi — üst üste duran iki düğme
/// aynı görünmüyordu.
class MapLayerButton extends StatelessWidget {
  const MapLayerButton({
    required this.controller,
    this.favoriteCount = 0,
    super.key,
  });

  final MapDataController controller;

  /// Kaç favori var — kullanıcı tiki açmadan önce ne bekleyeceğini bilsin.
  final int favoriteCount;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder:
          (context, _) => MapCircleButton(
            key: const ValueKey('map-layer-button'),
            icon: Icons.layers_outlined,
            tooltip: 'Harita katmanları',
            busy: controller.isLoading || controller.isViewportLoading,
            badge: controller.errorMessage != null,
            onPressed: () => _showLayerSheet(context),
          ),
    );
  }

  Future<void> _showLayerSheet(BuildContext context) => showAppSheet<void>(
    context,
    builder:
        (_) => _MapLayerSheet(
          controller: controller,
          favoriteCount: favoriteCount,
        ),
  );
}

class _MapLayerSheet extends StatelessWidget {
  const _MapLayerSheet({required this.controller, required this.favoriteCount});

  final MapDataController controller;
  final int favoriteCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık SABİT, liste onun altında kayıyor: kapatma düğmesi
              // uzun kategori listesinde kaybolmasın.
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, 10, 0),
                child: SheetHeader(
                  title: 'Harita katmanları',
                  subtitle:
                      'Konutları ve hizmet kategorilerini birlikte göster.',
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Konutlar ve favoriler ────────────────────────
                      // Favori satırı konut satırının hemen ALTINDA çünkü aynı
                      // şeyin (ev) bir alt kümesi; POI kategorilerinden ayrıldığı
                      // yer bu. Web'deki `PoiLayerPanel` sıralamasıyla aynı.
                      _LayerRow(
                        icon: const BrandIcon(
                          'home_white.svg',
                          size: 15,
                          color: Colors.white,
                        ),
                        swatch: AppColors.mapProperty,
                        title: 'Konutlar',
                        subtitle: '${controller.properties.length} konut',
                        value: controller.propertiesVisible,
                        onChanged: (_) => controller.toggleProperties(),
                      ),
                      _LayerRow(
                        icon: const BrandIcon(
                          'star_white.svg',
                          size: 15,
                          color: Colors.white,
                        ),
                        swatch: AppColors.mapFavorite,
                        title: 'Favorilerim',
                        // Sayı, tiki açmadan önce ne bekleyeceğini söyler: boş bir
                        // katmanı açıp "çalışmıyor mu?" diye düşünmesin.
                        subtitle:
                            favoriteCount == 0
                                ? 'Henüz favori yok'
                                : '$favoriteCount konut',
                        value: controller.favoritesVisible,
                        onChanged:
                            favoriteCount == 0
                                ? null
                                : (_) => controller.toggleFavorites(),
                      ),

                      if (controller.authenticated)
                        _LayerRow(
                          icon: const Icon(
                            Icons.route_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                          swatch: AppColors.mapAnchorArea,
                          title: 'Tüm Çankaya\'yı göster',
                          subtitle:
                              controller.showAllProperties
                                  ? 'Önemli konum filtresi kapalı'
                                  : controller.anchorCorridor == null
                                  ? 'Kayıtlı önemli konum bulunamadı'
                                  : 'Önemli konumlarının çevresindeki konutlar',
                          value: controller.showAllProperties,
                          onChanged:
                              controller.isLoading
                                  ? null
                                  : (_) => controller.toggleShowAllProperties(),
                        ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Divider(),
                      ),

                      // ── Hizmet noktaları ─────────────────────────────────
                      // ⚠️ Kategoriler eskiden düz renkli noktalarla listeleniyordu
                      // ve haritadaki işaret renkli daire + BEYAZ İKON'du. Panelde
                      // ikon yoksa kullanıcı hangi rengin hangi kategori olduğunu
                      // panelden haritaya bakarak eşlemek zorunda kalıyordu.
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text('HİZMET NOKTALARI', style: AppType.micro),
                      ),
                      for (final category in controller.categories)
                        _LayerRow(
                          icon: BrandIcon(
                            poiCategoryIconAssets[category.code] == null
                                ? 'poi_generic_white.svg'
                                : poiCategoryIconAssets[category.code]!
                                    .split('/')
                                    .last,
                            size: 14,
                            color: Colors.white,
                          ),
                          swatch: poiCategoryColor(category.code),
                          title: category.displayNameTr,
                          value: controller.selectedCategories.contains(
                            category.code,
                          ),
                          onChanged:
                              (_) => controller.toggleCategory(category.code),
                        ),

                      if (controller.categories.isEmpty &&
                          !controller.isLoading)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm,
                          ),
                          child: Text(
                            'POI kategorileri yüklenemedi.',
                            style: AppType.muted(AppType.sm),
                          ),
                        ),

                      if (controller.isLoading || controller.isViewportLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.sm),
                          child: LinearProgressIndicator(minHeight: 3),
                        ),

                      if (controller.errorMessage case final message?) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.bad.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 18,
                                color: AppColors.bad,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(child: Text(message, style: AppType.xs)),
                              TextButton(
                                onPressed: controller.retry,
                                child: const Text('Tekrar dene'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Katman satırı — renkli işaret + ad + anahtar.
///
/// İşaret HARİTADAKİ pinin küçültülmüş hâli (renkli daire + beyaz ikon):
/// kullanıcı panelde gördüğü şeyi haritada aramak zorunda kalmıyor.
class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.icon,
    required this.swatch,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final Widget icon;
  final Color swatch;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? () => onChanged!(!value) : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.easeOut,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  // Kapalı katmanın işareti SOLUYOR, kaybolmuyor: rengin
                  // hangi kategoriye ait olduğu bilgisi kapalıyken de
                  // gerekli.
                  color: value ? swatch : swatch.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: value ? AppShadows.xs : null,
                ),
                child: Center(child: icon),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppType.sm.copyWith(fontWeight: AppType.medium),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: AppType.muted(AppType.xs)),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
