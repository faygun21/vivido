import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_status_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/page_parts.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../../favorites/application/favorites_controller.dart';
import '../../../property_strengths/domain/strength_poi_gateway.dart';
import '../../../routes/application/routes_controller.dart';
import '../../../routes/domain/route_models.dart';
import '../../application/property_catalog_controller.dart';
import '../../domain/property_gateway.dart';
import '../../domain/property_models.dart';
import '../widgets/property_summary_card.dart';
import 'property_detail_page.dart';

/// Konutlar sekmesi — "Tümü" ve "Favorilerim" tek sayfada.
///
/// ⚠️ FAVORİLER AYRI BİR SEKME DEĞİL
///
/// Eskiden Favoriler kendi sekmesindeydi ve AYNI kartı gösteriyordu; alt
/// menüde beş etiket sıkışıyor, aynı arayüz iki yerde yaşıyordu. Favori,
/// konutun bir alt kümesi — filtre olması doğru yer. (Haritada ise ayrı bir
/// katman: orada kullanıcı favorilerini diğer evlerin ARASINDA görmek
/// istiyor, o yüzden orada filtre değil işaret.)
class PropertyListPage extends StatefulWidget {
  const PropertyListPage({
    required this.controller,
    required this.gateway,
    required this.favorites,
    required this.routes,
    required this.strengthPoiGateway,
    required this.client,
    required this.networkStatus,
    required this.showFavorites,
    required this.onShowFavoritesChanged,
    super.key,
  });

  final PropertyCatalogController controller;
  final PropertyGateway gateway;
  final FavoritesController favorites;
  final RoutesController routes;
  final StrengthPoiGateway strengthPoiGateway;
  final ApiClient client;
  final NetworkStatusController networkStatus;

  final bool showFavorites;
  final ValueChanged<bool> onShowFavoritesChanged;

  @override
  State<PropertyListPage> createState() => _PropertyListPageState();
}

class _PropertyListPageState extends State<PropertyListPage> {
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.load();
    widget.favorites.load();
  }

  Future<void> _openDetail(String propertyId) async {
    if (widget.showFavorites && !_requireOnline('Konut detayı')) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => PropertyDetailPage(
              propertyId: propertyId,
              gateway: widget.gateway,
              favorites: widget.favorites,
              routes: widget.routes,
              strengthPoiGateway: widget.strengthPoiGateway,
              client: widget.client,
              onFavoriteChanged: widget.controller.updateFavorite,
            ),
      ),
    );
    if (mounted && widget.showFavorites) {
      await widget.favorites.load(force: true);
    }
  }

  void _toggleRoute(PropertySummary item) {
    final id = item.numericId;
    if (id == null) return;
    if (widget.routes.containsProperty(id)) {
      widget.routes.removeProperty(id);
      return;
    }
    final added = widget.routes.addProperty(
      RouteDraftProperty.fromSummary(item),
    );
    if (!added && mounted) {
      showAppSnack(
        context,
        widget.routes.errorMessage ?? 'Konut rotaya eklenemedi.',
        tone: SnackTone.error,
      );
    }
  }

  Future<void> _toggleFavorite(PropertySummary item) async {
    final desired = !item.isFavorite;
    final changed = await widget.favorites.setFavorite(item.id, desired);
    if (!mounted) return;
    if (changed) {
      widget.controller.updateFavorite(item.id, desired);
      return;
    }
    showAppSnack(
      context,
      widget.favorites.errorMessage ?? 'Favori durumu güncellenemedi.',
      tone: SnackTone.error,
    );
  }

  bool _requireOnline(String operation) {
    if (!widget.networkStatus.isOffline &&
        !widget.favorites.showingCachedData) {
      return true;
    }
    showAppSnack(
      context,
      '$operation internet bağlantısı gerektirir. Bağlantın geldiğinde '
      'tekrar deneyebilirsin.',
      tone: SnackTone.error,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.controller,
          widget.favorites,
          widget.routes,
        ]),
        builder: (context, _) {
          return Column(
            children: [
              // Segment sabit duruyor, liste onun altında kayıyor: iki
              // görünüm arasında geçerken kullanıcının anahtarı yeniden
              // araması gerekmiyor.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  AppSpacing.sm,
                ),
                child: _ViewSegment(
                  showFavorites: widget.showFavorites,
                  favoriteCount: widget.favorites.items.length,
                  onChanged: widget.onShowFavoritesChanged,
                ),
              ),
              Expanded(
                // Geçiş çapraz solma: iki liste de aynı yeri paylaşıyor,
                // kayma hangisinin "yan tarafta" olduğunu ima ederdi.
                child: AnimatedSwitcher(
                  duration: AppMotion.base,
                  switchInCurve: AppMotion.easeOut,
                  child:
                      widget.showFavorites
                          ? _buildFavorites()
                          : _buildCatalog(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Tümü ────────────────────────────────────────────────────────────

  Widget _buildCatalog() {
    final controller = widget.controller;
    if (controller.loading && controller.items.isEmpty) {
      return const SkeletonList(key: ValueKey('catalog-loading'));
    }
    if (controller.errorMessage != null && controller.items.isEmpty) {
      return ErrorState(
        key: const ValueKey('catalog-error'),
        title: 'Konut listesi yüklenemedi',
        message: controller.errorMessage!,
        onRetry: () => controller.load(force: true),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('catalog'),
      onRefresh: () => controller.load(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        children: [
          PageIntro(
            controller.showAll
                ? 'Çankaya genelinde profiline ve bütçene göre en yüksek '
                    'skorlu ${controller.items.length} konut.'
                : 'Önemli konumlarının çevresinde, profiline ve bütçene göre '
                    'en yüksek skorlu ${controller.items.length} konut.',
          ),
          _FilterBar(
            open: _filtersOpen,
            controller: controller,
            onToggle: () => setState(() => _filtersOpen = !_filtersOpen),
          ),
          const SizedBox(height: AppSpacing.xs),
          _ShowAllSwitch(
            value: controller.showAll,
            busy: controller.loading,
            onChanged: controller.setShowAll,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Liste boşsa NEDENİ ayırt etmek gerekiyor: bütçeye uyan hiç ev
          // mi yok, yoksa evler var ama hiçbiri anchor koridoruna mı
          // düşmüyor? İkincisinde "bütçeni genişlet" demek yanıltıcı olurdu.
          if (controller.items.isEmpty)
            _CatalogEmpty(
              showAll: controller.showAll,
              fallback: controller.nearestFallback,
              onShowAll: () => controller.setShowAll(true),
              onOpenFallback: _openDetail,
            )
          else if (controller.visibleItems.isEmpty)
            EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'Bu filtrelerle eşleşen konut yok',
              message: 'Filtreleri temizleyip tekrar deneyebilirsin.',
              action: OutlinedButton(
                onPressed: controller.clearFilters,
                child: const Text('Filtreleri temizle'),
              ),
            )
          else
            for (final (index, ranked) in controller.visibleItems.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: StaggeredEntrance(
                  index: index,
                  child: PropertySummaryCard(
                    key: ValueKey(ranked.property.id),
                    rank: ranked.rank,
                    property: ranked.property,
                    favoriteBusy: widget.favorites.busyPropertyIds.contains(
                      ranked.property.id,
                    ),
                    inRoute: widget.routes.containsProperty(
                      ranked.property.numericId ?? -1,
                    ),
                    onTap: () => _openDetail(ranked.property.id),
                    onFavorite: () => _toggleFavorite(ranked.property),
                    onRoute: () => _toggleRoute(ranked.property),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  // ── Favorilerim ─────────────────────────────────────────────────────

  Widget _buildFavorites() {
    final favorites = widget.favorites;
    if (favorites.loading && favorites.items.isEmpty) {
      return const SkeletonList(key: ValueKey('favorites-loading'), itemCount: 3);
    }
    if (favorites.errorMessage != null && favorites.items.isEmpty) {
      return ErrorState(
        key: const ValueKey('favorites-error'),
        title: 'Favoriler yüklenemedi',
        message: favorites.errorMessage!,
        onRetry: () => favorites.load(force: true),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('favorites'),
      onRefresh: () => favorites.load(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        children: [
          const PageIntro(
            'Kaydettiğin konutlar haritada altın yıldızla işaretlenir; '
            'buradan detaylarına bakabilir veya rotana ekleyebilirsin.',
          ),
          if (favorites.showingCachedData) ...[
            _CachedNotice(),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (favorites.items.isEmpty)
            const EmptyState(
              showMascot: true,
              title: 'Henüz favorin yok',
              message:
                  'Beğendiğin evleri kalp simgesiyle kaydet; hepsi burada ve '
                  'haritada bir arada dursun.',
            )
          else
            for (final (index, entry) in favorites.items.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: StaggeredEntrance(
                  index: index,
                  child:
                      entry.property == null
                          // Sunucu bu konutu artık döndürmüyor (ilan
                          // kaldırılmış olabilir). Kaydı sessizce gizlemek,
                          // kullanıcının favorisinin "kaybolduğu" hissini
                          // verirdi; açıkça söyleyip silme yolu veriyoruz.
                          ? _MissingFavorite(
                            propertyId: entry.propertyId,
                            busy: favorites.busyPropertyIds.contains(
                              entry.propertyId,
                            ),
                            onRemove:
                                () => _removeFavoriteById(entry.propertyId),
                          )
                          : PropertySummaryCard(
                            key: ValueKey(entry.propertyId),
                            property: entry.property!,
                            favoriteBusy: favorites.busyPropertyIds.contains(
                              entry.propertyId,
                            ),
                            inRoute: widget.routes.containsProperty(
                              entry.property!.numericId ?? -1,
                            ),
                            onTap: () => _openDetail(entry.propertyId),
                            onFavorite: () => _toggleFavorite(entry.property!),
                            onRoute: () => _toggleRoute(entry.property!),
                          ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _removeFavoriteById(String propertyId) async {
    if (!_requireOnline('Favori güncelleme')) return;
    final changed = await widget.favorites.setFavorite(propertyId, false);
    if (!mounted) return;
    if (changed) {
      widget.controller.updateFavorite(propertyId, false);
      return;
    }
    showAppSnack(
      context,
      widget.favorites.errorMessage ?? 'Favori durumu güncellenemedi.',
      tone: SnackTone.error,
    );
  }
}

/// Tümü / Favorilerim anahtarı.
class _ViewSegment extends StatelessWidget {
  const _ViewSegment({
    required this.showFavorites,
    required this.favoriteCount,
    required this.onChanged,
  });

  final bool showFavorites;
  final int favoriteCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.inputBg,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      children: [
        Expanded(
          child: _SegmentButton(
            label: 'Tümü',
            selected: !showFavorites,
            onTap: () => onChanged(false),
          ),
        ),
        Expanded(
          child: _SegmentButton(
            label: 'Favorilerim',
            count: favoriteCount,
            selected: showFavorites,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    ),
  );
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.97,
    child: AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      decoration: BoxDecoration(
        color: selected ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: selected ? AppShadows.xs : null,
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: AppType.sm.copyWith(
                fontWeight: selected ? AppType.semibold : AppType.medium,
                color: selected ? AppColors.ink : AppColors.inkMuted,
              ),
              child: Text(label),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color:
                      selected ? AppColors.accentSoftStrong : AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$count',
                  style: AppType.micro.copyWith(
                    letterSpacing: 0,
                    fontSize: 10,
                    color: selected ? AppColors.accent : AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Filtre ve sıralama şeridi.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.open,
    required this.controller,
    required this.onToggle,
  });

  final bool open;
  final PropertyCatalogController controller;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final activeCount =
        (controller.hasActiveFilter ? 1 : 0) +
        (controller.sortOption != PropertySortOption.score ? 1 : 0);

    return AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.easeOut,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: activeCount > 0 ? AppColors.accentEdge : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Pressable(
            onTap: onToggle,
            scale: 0.995,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 18,
                    color:
                        activeCount > 0
                            ? AppColors.accent
                            : AppColors.inkMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Filtrele ve sırala',
                      style: AppType.sm.copyWith(
                        fontWeight: AppType.medium,
                      ),
                    ),
                  ),
                  if (controller.hasCustomView)
                    Text(
                      '${controller.visibleItems.length} / '
                      '${controller.items.length}',
                      style: AppType.muted(AppType.xs).copyWith(
                        fontFeatures: AppType.tabularFigures,
                      ),
                    ),
                  // Ok, panelin açık olduğunu DÖNEREK söylüyor: iki ayrı
                  // ikon arasında geçmek yerine tek bir öğe hareket ediyor.
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: AppMotion.base,
                    curve: AppMotion.easeOut,
                    child: const Icon(
                      Icons.expand_more,
                      size: 20,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.base,
            curve: AppMotion.easeOut,
            alignment: Alignment.topCenter,
            child:
                open
                    ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        0,
                        AppSpacing.sm,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('SIRALA', style: AppType.micro),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final option in PropertySortOption.values)
                                ChoiceChip(
                                  label: Text(_sortLabel(option)),
                                  selected: controller.sortOption == option,
                                  onSelected:
                                      (_) => controller.setSortOption(option),
                                ),
                            ],
                          ),
                          if (controller.roomCountOptions.length > 1) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text('ODA SAYISI', style: AppType.micro),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final room in controller.roomCountOptions)
                                  FilterChip(
                                    label: Text(room),
                                    selected: controller.selectedRoomCounts
                                        .contains(room),
                                    onSelected:
                                        (_) => controller.toggleRoomCount(room),
                                  ),
                              ],
                            ),
                          ],
                          if (controller.hasActiveFilter) ...[
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: controller.clearFilters,
                                child: const Text('Filtreleri temizle'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                    : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  static String _sortLabel(PropertySortOption option) => switch (option) {
    PropertySortOption.score => 'Öneri',
    PropertySortOption.rentDescending => 'Kira ↓',
    PropertySortOption.rentAscending => 'Kira ↑',
    PropertySortOption.areaDescending => 'm² ↓',
    PropertySortOption.areaAscending => 'm² ↑',
  };
}

/// "Tüm Çankaya'yı göster" anahtarı — filtreyi SUNUCU uyguluyor.
class _ShowAllSwitch extends StatelessWidget {
  const _ShowAllSwitch({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 2, 6, 2),
    decoration: BoxDecoration(
      color: AppColors.surfaceSunken,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tüm Çankaya\'yı göster',
                style: AppType.sm.copyWith(fontWeight: AppType.medium),
              ),
              Text(
                value
                    ? 'Önemli konum filtresi kapalı'
                    : 'Yalnızca önemli konumlarının çevresi',
                style: AppType.muted(AppType.micro).copyWith(letterSpacing: 0),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          // Yükleme sırasında kilitli: anahtar sunucuya yeni bir istek
          // attırıyor, hızlı ard arda basmak yarış durumu yaratırdı.
          onChanged: busy ? null : onChanged,
        ),
      ],
    ),
  );
}

class _CatalogEmpty extends StatelessWidget {
  const _CatalogEmpty({
    required this.showAll,
    required this.fallback,
    required this.onShowAll,
    required this.onOpenFallback,
  });

  final bool showAll;
  final PropertySummary? fallback;
  final VoidCallback onShowAll;
  final ValueChanged<String> onOpenFallback;

  @override
  Widget build(BuildContext context) {
    // "Tüm Çankaya" zaten açıksa koridoru suçlayamayız: gerçekten bütçeye
    // uyan ev yok demektir.
    if (showAll) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Bütçene uygun konut bulunamadı',
        message:
            'Profil sekmesinden kira aralığını genişletmeyi deneyebilirsin.',
      );
    }

    return Column(
      children: [
        EmptyState(
          icon: Icons.place_outlined,
          title: 'Çevrende bütçene uyan ev çıkmadı',
          message:
              'Önemli konumlarının yakınında bütçene uygun konut yok. Tüm '
              'Çankaya\'yı açarak daha geniş bakabilirsin.',
          action: FilledButton.tonal(
            onPressed: onShowAll,
            child: const Text('Tüm Çankaya\'yı göster'),
          ),
        ),
        if (fallback != null) ...[
          const SectionHeader('ALANA EN YAKIN EV'),
          PropertySummaryCard(
            property: fallback!,
            onTap: () => onOpenFallback(fallback!.id),
            onFavorite: () {},
            onRoute: () {},
          ),
        ],
      ],
    );
  }
}

class _CachedNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.warn.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.warn.withValues(alpha: 0.22)),
    ),
    child: Row(
      children: [
        const Icon(Icons.offline_pin_outlined, size: 18, color: AppColors.warn),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Çevrimdışı favoriler gösteriliyor. Detay, güncelleme ve rota '
            'işlemleri internet gerektirir.',
            style: AppType.xs.copyWith(height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _MissingFavorite extends StatelessWidget {
  const _MissingFavorite({
    required this.propertyId,
    required this.busy,
    required this.onRemove,
  });

  final String propertyId;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, 4, AppSpacing.xs),
    decoration: BoxDecoration(
      color: AppColors.surfaceSunken,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.home_work_outlined,
          size: 20,
          color: AppColors.inkMuted,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bu konut artık listede değil',
                style: AppType.sm.copyWith(fontWeight: AppType.medium),
              ),
              Text('Konut #$propertyId', style: AppType.muted(AppType.micro)),
            ],
          ),
        ),
        IconButton(
          onPressed: busy ? null : onRemove,
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: 'Favorilerden çıkar',
        ),
      ],
    ),
  );
}
