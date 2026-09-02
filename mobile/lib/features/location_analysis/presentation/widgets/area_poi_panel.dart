import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/brand_icon.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../../map_data/domain/map_data_models.dart';
import '../../../map_data/presentation/poi_category_colors.dart';
import '../../application/area_poi_controller.dart';
import '../../domain/area_poi.dart';

/// Analiz alanı içindeki hizmet noktaları paneli.
///
/// ⚠️ ÇEMBER BİR ŞEY ANLATMIYORDU
///
/// Kullanıcı yürüme süresini seçiyor, haritada bir nokta işaretliyor ve
/// sarı bir daire çıkıyordu — o kadar. "Bu alanda ne var?" sorusunun
/// cevabı hiçbir yerde yoktu; kullanıcı çemberin içindeki renkli noktaları
/// tek tek dürtmek zorundaydı.
///
/// Panel iki parçalı:
///   • Sol şerit: kategori seçici (haritadaki renk ve ikonun aynısı)
///   • Sağ: seçili kategorinin alan İÇİNDEKİ noktaları, merkeze uzaklığa
///     göre sıralı
///
/// Kategoriler arasında geçiş liste içeriğini değiştiriyor; her kategori
/// bir kez çekilip önbelleğe alınıyor (bkz. [AreaPoiController]).
class AreaPoiPanel extends StatefulWidget {
  const AreaPoiPanel({
    required this.controller,
    required this.categories,
    required this.walkingMinutes,
    required this.onPoiSelected,
    required this.onClose,
    super.key,
  });

  final AreaPoiController controller;

  /// Sunucudan gelen aktif POI kategorileri.
  final List<PoiCategory> categories;

  /// Çemberin kaç dakikalık yürüme alanı olduğu — başlıkta yazıyor.
  final int walkingMinutes;

  /// Listeden bir noktaya dokunulunca harita oraya taşınıyor.
  final ValueChanged<PoiMapItem> onPoiSelected;

  final VoidCallback onClose;

  @override
  State<AreaPoiPanel> createState() => _AreaPoiPanelState();
}

class _AreaPoiPanelState extends State<AreaPoiPanel> {
  /// Panel katlanabiliyor: haritanın alt yarısını kalıcı olarak kaplayan
  /// bir liste, kullanıcının çemberi taşımasını engelliyordu.
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    // İlk kategori kendiliğinden seçiliyor: boş bir panel açıp "şimdi bir
    // şey seç" demek, kullanıcıya fazladan bir adım yüklüyor.
    final first = widget.categories.firstOrNull;
    if (first != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.select(first.code);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;

        return GlassSurface(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                walkingMinutes: widget.walkingMinutes,
                count: controller.items.length,
                loading: controller.loading,
                expanded: _expanded,
                onToggle: () => setState(() => _expanded = !_expanded),
                onClose: widget.onClose,
              ),

              AnimatedSize(
                duration: AppMotion.base,
                curve: AppMotion.easeOut,
                alignment: Alignment.topCenter,
                child:
                    _expanded
                        ? SizedBox(
                          // Yükseklik ekrana oranlı: sabit bir değer küçük
                          // telefonda haritayı yutuyor, büyük telefonda
                          // boşluk bırakıyordu.
                          height: (MediaQuery.sizeOf(context).height * 0.30)
                              .clamp(180.0, 300.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _CategoryRail(
                                categories: widget.categories,
                                selected: controller.selectedCategory,
                                onSelect: controller.select,
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: _ResultList(
                                  controller: controller,
                                  onPoiSelected: widget.onPoiSelected,
                                ),
                              ),
                            ],
                          ),
                        )
                        : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.walkingMinutes,
    required this.count,
    required this.loading,
    required this.expanded,
    required this.onToggle,
    required this.onClose,
  });

  final int walkingMinutes;
  final int count;
  final bool loading;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onToggle,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 8, 4, 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.mapWalking.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_walk,
              size: 17,
              color: AppColors.mapWalkingEdge,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$walkingMinutes dk yürüme alanı',
                  style: AppType.sm.copyWith(fontWeight: AppType.semibold),
                ),
                Text(
                  loading
                      ? 'Aranıyor…'
                      : count == 0
                      ? 'Bu kategoride nokta yok'
                      : '$count nokta bulundu',
                  style: AppType.muted(AppType.micro).copyWith(
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          AnimatedRotation(
            turns: expanded ? 0 : 0.5,
            duration: AppMotion.base,
            curve: AppMotion.easeOut,
            child: const Icon(
              Icons.expand_more,
              size: 20,
              color: AppColors.inkMuted,
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Analizi kapat',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    ),
  );
}

/// Soldaki dikey kategori şeridi.
///
/// Yatay çipler yerine DİKEY şerit: sekiz kategori yatay bir satıra
/// sığmıyor ve kullanıcı listeyi okurken yana kaydırmak zorunda kalıyordu.
/// Dikey şerit hepsini aynı anda gösteriyor.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<PoiCategory> categories;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 58,
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = category.code == selected;
        final color = poiCategoryColor(category.code);
        final asset = poiCategoryIconAssets[category.code];

        return Pressable(
          onTap: () => onSelect(category.code),
          scale: 0.94,
          child: Tooltip(
            message: category.displayNameTr,
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? color.withValues(alpha: 0.14)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Seçili değilken işaret SOLUYOR, kaybolmuyor: hangi
                  // rengin hangi kategori olduğu bilgisi hep gerekli.
                  AnimatedOpacity(
                    opacity: isSelected ? 1 : 0.55,
                    duration: AppMotion.fast,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: BrandIcon(
                          asset == null
                              ? 'poi_generic_white.svg'
                              : asset.split('/').last,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _shortLabel(category.displayNameTr),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppType.micro.copyWith(
                      fontSize: 9,
                      letterSpacing: 0,
                      color: isSelected ? AppColors.ink : AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  /// 58 px'lik şeritte "Kafe ve restoran" sığmıyor; ilk kelime yeterli
  /// ayırt edici — tam adı `Tooltip` taşıyor.
  static String _shortLabel(String label) {
    final firstWord = label.split(RegExp(r'[ /]')).first;
    return firstWord.length > 9 ? '${firstWord.substring(0, 8)}…' : firstWord;
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.controller, required this.onPoiSelected});

  final AreaPoiController controller;
  final ValueChanged<PoiMapItem> onPoiSelected;

  @override
  Widget build(BuildContext context) {
    if (controller.errorMessage case final message?) {
      return _Centered(
        icon: Icons.cloud_off_outlined,
        text: message,
        action: TextButton(
          onPressed: () {
            final code = controller.selectedCategory;
            if (code != null) controller.reload(code);
          },
          child: const Text('Tekrar dene'),
        ),
      );
    }
    if (controller.loading && controller.items.isEmpty) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    if (controller.selectedCategory == null) {
      return const _Centered(
        icon: Icons.arrow_back,
        text: 'Soldan bir kategori seç.',
      );
    }
    if (controller.items.isEmpty) {
      return const _Centered(
        icon: Icons.search_off,
        text: 'Bu yürüme alanında bu kategoriden nokta yok.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 6),
      itemCount: controller.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 12),
      itemBuilder:
          (context, index) => _ResultRow(
            item: controller.items[index],
            onTap: () => onPoiSelected(controller.items[index].poi),
          ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.item, required this.onTap});

  final AreaPoi item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = item.poi.name?.trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 8, AppSpacing.xs, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name == null || name.isEmpty ? 'İsimsiz nokta' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.sm.copyWith(
                  fontWeight: AppType.medium,
                  color:
                      name == null || name.isEmpty
                          ? AppColors.inkMuted
                          : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            // Mesafe ve süre YAN YANA, sabit genişlikli rakamla: liste
            // boyunca sayılar hizalı kalıyor.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDistance(item.distanceM),
                  style: AppType.xs.copyWith(
                    fontWeight: AppType.semibold,
                    fontFeatures: AppType.tabularFigures,
                  ),
                ),
                Text(
                  '~${item.walkingMinutes} dk',
                  style: AppType.micro.copyWith(
                    letterSpacing: 0,
                    color: AppColors.inkMuted,
                    fontFeatures: AppType.tabularFigures,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDistance(double metres) =>
      metres < 1000
          ? '${metres.round()} m'
          : '${(metres / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: AppColors.inkMuted),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppType.muted(AppType.xs),
          ),
          if (action != null) action!,
        ],
      ),
    ),
  );
}
