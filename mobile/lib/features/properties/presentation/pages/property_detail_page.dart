import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/favorite_button.dart';
import '../../../../shared/widgets/page_parts.dart';
import '../../../../shared/widgets/score_badge.dart';
import '../../../favorites/application/favorites_controller.dart';
import '../../../location_search/domain/location_search_models.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';
import '../../../map_data/domain/map_data_models.dart';
import '../../../map_data/presentation/widgets/map_item_details_sheet.dart';
import '../../../property_notes/data/api_property_note_gateway.dart';
import '../../../property_notes/presentation/property_note_section.dart';
import '../../../property_strengths/domain/strength_poi_gateway.dart';
import '../../../routes/application/routes_controller.dart';
import '../../../routes/domain/route_models.dart';
import '../../domain/property_gateway.dart';
import '../../domain/property_models.dart';
import '../property_format.dart';

/// Konut detay sayfası (W6 — skorun gerekçe tablosu).
///
/// ⚠️ SAYFA ÜÇ SORUYA SIRAYLA CEVAP VERİYOR (web `PropertyDetailPanel`
/// ile aynı kurgu):
///   1. Bu ev nerede, ne kadar, nasıl bir ev?
///   2. Skoru kaç ve bu iyi mi? (bant rozeti)
///   3. NEDEN? — güçlü/zayıf yönler, istenirse tam kriter tablosu
///
/// Eskiden bu sıra yoktu: fotoğraf, başlık, sentetik rozeti, rota düğmesi,
/// özellikler, bütçe, gerekçeler, tablo, harita art arda diziliydi ve
/// hiçbiri diğerinden görsel olarak ayrılmıyordu — dokuz kart, hepsi aynı
/// ağırlıkta.
///
/// ⚠️ BÜTÇE AYRI BİR BÖLÜMDE ve skor satırlarının dışında: mevcut skor
/// motoru bütçeyi hesaba katmıyor. Gerekçelerin arasına karıştırsaydık
/// kullanıcı "bütçem skorumu düşürmüş" sanırdı.
class PropertyDetailPage extends StatefulWidget {
  const PropertyDetailPage({
    required this.propertyId,
    required this.gateway,
    required this.favorites,
    required this.routes,
    required this.strengthPoiGateway,
    required this.client,
    this.onFavoriteChanged,
    super.key,
  });

  final String propertyId;
  final PropertyGateway gateway;
  final FavoritesController favorites;
  final RoutesController routes;
  final StrengthPoiGateway strengthPoiGateway;

  /// Kişisel not uçları için — web'de var olup mobilde eksik olan özellik.
  final ApiClient client;

  final void Function(String propertyId, bool isFavorite)? onFavoriteChanged;

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  PropertyDetail? _property;
  List<PoiMapItem> _highlightedPois = const [];
  bool _strengthPoisLoading = false;
  String? _strengthPoisError;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _errorMessage = null);
    try {
      final property = await widget.gateway.getPropertyDetail(
        widget.propertyId,
      );
      if (!mounted) return;
      setState(() => _property = property);
      await _loadStrengthPois(property);
    } on PropertyDataFailure catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on Object {
      if (mounted) setState(() => _errorMessage = 'Konut detayı yüklenemedi.');
    }
  }

  Future<void> _loadStrengthPois(PropertyDetail property) async {
    setState(() {
      _strengthPoisLoading = true;
      _strengthPoisError = null;
    });
    try {
      final pois = await widget.strengthPoiGateway.getHighlightedPois(
        propertyLatitude: property.latitude,
        propertyLongitude: property.longitude,
        strengths: property.score.strengths,
      );
      if (!mounted || _property?.id != property.id) return;
      setState(() => _highlightedPois = pois);
    } on StrengthPoiFailure catch (error) {
      if (mounted) setState(() => _strengthPoisError = error.message);
    } on Object {
      if (mounted) {
        setState(() => _strengthPoisError = 'Güçlü yön noktaları yüklenemedi.');
      }
    } finally {
      if (mounted && _property?.id == property.id) {
        setState(() => _strengthPoisLoading = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final property = _property;
    if (property == null) return;
    final desired = !property.isFavorite;

    // İYİMSER GÜNCELLEME: kalp sunucuyu beklemeden doluyor. Ağ turu
    // 200–400 ms ve o süre boyunca boş bir kalbe bakmak dokunuşun
    // kaydedilmediğini düşündürüyor.
    setState(() => _property = property.copyWith(isFavorite: desired));

    final changed = await widget.favorites.setFavorite(property.id, desired);
    if (!mounted) return;

    if (changed) {
      widget.onFavoriteChanged?.call(property.id, desired);
      return;
    }
    // Başarısızsa geri al ve söyle.
    setState(() => _property = property.copyWith(isFavorite: !desired));
    showAppSnack(
      context,
      widget.favorites.errorMessage ?? 'Favori durumu güncellenemedi.',
      tone: SnackTone.error,
    );
  }

  void _toggleRoute() {
    final property = _property;
    final id = property?.numericId;
    if (property == null || id == null) return;
    final wasSelected = widget.routes.containsProperty(id);
    var changed = true;
    if (wasSelected) {
      widget.routes.removeProperty(id);
    } else {
      changed = widget.routes.addProperty(
        RouteDraftProperty.fromDetail(property),
      );
    }
    setState(() {});
    showAppSnack(
      context,
      !changed
          ? widget.routes.errorMessage ?? 'Konut rotaya eklenemedi.'
          : wasSelected
          ? 'Konut rota taslağından çıkarıldı.'
          : 'Konut rota taslağına eklendi.',
      tone: changed ? SnackTone.success : SnackTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final property = _property;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konut detayı'),
        actions: [
          if (property != null)
            AnimatedBuilder(
              animation: widget.favorites,
              builder:
                  (context, _) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FavoriteButton(
                      isFavorite: property.isFavorite,
                      busy: widget.favorites.busyPropertyIds.contains(
                        property.id,
                      ),
                      onPressed: _toggleFavorite,
                    ),
                  ),
            ),
        ],
      ),
      body: switch ((property, _errorMessage)) {
        (final PropertyDetail loaded, _) => _DetailBody(
          property: loaded,
          client: widget.client,
          inRoute:
              loaded.numericId != null &&
              widget.routes.containsProperty(loaded.numericId!),
          onToggleRoute: _toggleRoute,
          onToggleFavorite: _toggleFavorite,
          favoriteBusy: widget.favorites.busyPropertyIds.contains(loaded.id),
          highlightedPois: _highlightedPois,
          strengthPoisLoading: _strengthPoisLoading,
          strengthPoisError: _strengthPoisError,
          onRetryStrengthPois: () => _loadStrengthPois(loaded),
        ),
        (null, final String message) => ErrorState(
          title: 'Konut detayı açılamadı',
          message: message,
          onRetry: _load,
        ),
        _ => const _DetailSkeleton(),
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.property,
    required this.client,
    required this.inRoute,
    required this.onToggleRoute,
    required this.onToggleFavorite,
    required this.favoriteBusy,
    required this.highlightedPois,
    required this.strengthPoisLoading,
    required this.strengthPoisError,
    required this.onRetryStrengthPois,
  });

  final PropertyDetail property;
  final ApiClient client;
  final bool inRoute;
  final VoidCallback onToggleRoute;
  final VoidCallback onToggleFavorite;
  final bool favoriteBusy;
  final List<PoiMapItem> highlightedPois;
  final bool strengthPoisLoading;
  final String? strengthPoisError;
  final VoidCallback onRetryStrengthPois;

  @override
  Widget build(BuildContext context) {
    final address = splitAddress(property.address);
    final mapItem = PropertyMapItem(
      id: property.id,
      externalRef: property.externalRef,
      latitude: property.latitude,
      longitude: property.longitude,
      monthlyRent: property.monthlyRent,
      areaM2: property.areaM2,
      roomCount: property.roomCount,
      totalScore: property.score.total,
      buildingAge: property.features.buildingAge,
      hasElevator: property.features.hasElevator,
      isSynthetic: property.isSynthetic,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        // ── 1. Bu ev nerede, ne kadar, nasıl bir ev? ──────────────────
        _HeroImage(isSynthetic: property.isSynthetic),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatRent(property.monthlyRent)} / ay',
                    style: AppType.h1.copyWith(
                      fontFeatures: AppType.tabularFigures,
                    ),
                  ),
                  Text(
                    '${property.roomCount} · ${property.areaM2} m²',
                    style: AppType.sm.copyWith(fontWeight: AppType.medium),
                  ),
                  const SizedBox(height: 4),
                  Text(address.primary, style: AppType.sm),
                  if (address.secondary.isNotEmpty)
                    Text(
                      address.secondary,
                      style: AppType.muted(AppType.xs),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ScoreBadge(
              total: property.score.total,
              band: property.score.band,
              size: ScoreBadgeSize.large,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Birincil eylemler yan yana: ikisi de aynı ağırlıkta kararlar.
        Row(
          children: [
            Expanded(
              child: FavoriteWideButton(
                isFavorite: property.isFavorite,
                busy: favoriteBusy,
                onPressed: onToggleFavorite,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _RouteButton(inRoute: inRoute, onPressed: onToggleRoute),
            ),
          ],
        ),

        // ── 2. Bu ev nasıl bir ev? ────────────────────────────────────
        const SectionHeader('BU EV NASIL BİR EV?'),
        _FactGrid(features: property.features),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            // ⚠️ "Yok"lar GİZLENMİYOR, soluk gösteriliyor. Tamamen
            // gizlemek kullanıcıyı "asansör bilgisi yok mu, asansör mü
            // yok?" diye düşündürüyordu.
            _FeatureTag('Asansör', property.features.hasElevator),
            _FeatureTag('Otopark', property.features.hasParking),
            _FeatureTag('Eşyalı', property.features.isFurnished),
            _FeatureTag('Evcil hayvan', property.features.petsAllowed),
          ],
        ),

        // ── Kişisel not (webde vardı, mobilde yoktu) ──────────────────
        const SizedBox(height: AppSpacing.lg),
        PropertyNoteSection(
          propertyId: property.id,
          gateway: ApiPropertyNoteGateway(client),
        ),

        // ── 3. NEDEN bu puan? ─────────────────────────────────────────
        const SectionHeader('BU EV SANA NEDEN BU PUANI ALDI?'),
        Text(
          'Puan, personana göre ağırlıklandırılmış yürüme süreleridir. Her '
          'kriter hedefine ne kadar yakınsa o kadar puan getirir.',
          style: AppType.muted(AppType.xs),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ReasonList(
          title: 'Neden uygun',
          rows: property.score.strengths,
          positive: true,
          emptyText: 'Öne çıkan güçlü bir kriter yok.',
        ),
        const SizedBox(height: AppSpacing.xs),
        _ReasonList(
          title: 'Neden daha az uygun',
          rows: property.score.weaknesses,
          positive: false,
          emptyText: 'Zayıf bir yönü yok — tüm kriterler hedefine yakın.',
        ),
        if (property.score.weakLink case final weakLink?) ...[
          const SizedBox(height: AppSpacing.xs),
          _WeakLinkCard(
            message: weakLink.message,
            points: weakLink.points,
          ),
        ],
        if (property.score.rows.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          _ScoreTable(rows: property.score.rows, total: property.score.total),
        ],

        // ── Bütçe (skorun DIŞINDA) ────────────────────────────────────
        const SectionHeader('BÜTÇE UYUMU'),
        _BudgetCard(budget: property.score.budget),

        // ── Konum ─────────────────────────────────────────────────────
        const SectionHeader('KONUM'),
        if (property.score.strengths.isNotEmpty) ...[
          _StrengthPoiNotice(
            loading: strengthPoisLoading,
            error: strengthPoisError,
            count: highlightedPois.length,
            onRetry: onRetryStrengthPois,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        SizedBox(
          height: 240,
          child: ExcludeFocus(
            child: CankayaMap(
              rounded: true,
              anchors: const [],
              focus: LocationSearchResult(
                id: 'property-${property.id}',
                label: property.address.formatted,
                kind: 'property',
                latitude: property.latitude,
                longitude: property.longitude,
                source: 'vivido',
              ),
              properties: [mapItem],
              highlightedPois: highlightedPois,
              onPoiTap: (poi) => showPoiDetailsSheet(context, poi: poi),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(property.externalRef, style: AppType.muted(AppType.micro)),
            const Spacer(),
            if (property.isSynthetic)
              Text(
                'Konut verisi sentetiktir',
                style: AppType.muted(AppType.micro),
              ),
          ],
        ),
      ],
    );
  }
}

/// Başlık görseli.
///
/// ⚠️ Backend DTO'sunda gerçek ilan fotoğrafı YOK (R-33): konut verisi
/// sentetik, fotoğraf alanı hiç üretilmedi. Tek bir temsili görsel
/// kullanılıyor ve bu AÇIKÇA etiketleniyor — sahte bir fotoğrafı gerçekmiş
/// gibi göstermek, kullanıcının ev kiralama kararını yanlış bilgiyle
/// beslemek olurdu.
class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.isSynthetic});

  final bool isSynthetic;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.lg),
    child: Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 7,
          child: Image.asset('assets/images/ev_resmi.png', fit: BoxFit.cover),
        ),
        // Alt kenarda koyulaşan bir geçiş: rozetin üstünde durduğu yer
        // görselin açık bir bölgesine denk gelirse metin okunmuyordu.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.28),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: AppSpacing.xs,
          bottom: AppSpacing.xs,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              isSynthetic ? 'Temsili görsel · sentetik veri' : 'Temsili görsel',
              style: AppType.micro.copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

class _RouteButton extends StatelessWidget {
  const _RouteButton({required this.inRoute, required this.onPressed});

  final bool inRoute;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppMotion.fast,
    curve: AppMotion.easeOut,
    decoration: BoxDecoration(
      color: inRoute ? AppColors.mapRoute.withValues(alpha: 0.10) : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(
        color:
            inRoute
                ? AppColors.mapRoute.withValues(alpha: 0.45)
                : AppColors.border,
        width: inRoute ? 1.5 : 1.25,
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                inRoute ? Icons.check_circle : Icons.add_location_alt_outlined,
                size: 20,
                color: inRoute ? AppColors.mapRoute : AppColors.inkMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  inRoute ? 'Rotada' : 'Rotaya ekle',
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sm.copyWith(
                    fontWeight: AppType.semibold,
                    color: inRoute ? AppColors.mapRoute : AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.features});

  final PropertyFeatures features;

  @override
  Widget build(BuildContext context) {
    final facts = <(IconData, String, String?)>[
      (
        Icons.layers_outlined,
        'Kat',
        formatFloor(features.floorNo, features.totalFloors),
      ),
      (
        Icons.apartment,
        'Bina yaşı',
        features.buildingAge == null ? null : '${features.buildingAge} yıl',
      ),
      (
        Icons.square_foot,
        'm² başı kira',
        features.rentPerM2 == null ? null : formatRent(features.rentPerM2!),
      ),
      (
        Icons.account_balance_wallet_outlined,
        'Depozito',
        features.deposit == null ? null : formatRent(features.deposit!),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const Divider(height: 1),
            IntrinsicHeight(
              child: Row(
                children: [
                  for (var col = 0; col < 2; col++) ...[
                    if (col > 0) const VerticalDivider(width: 1),
                    Expanded(child: _Fact(facts[row * 2 + col])),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.data);

  final (IconData, String, String?) data;

  @override
  Widget build(BuildContext context) {
    final (icon, label, value) = data;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 10,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppType.muted(AppType.micro).copyWith(
                  letterSpacing: 0,
                )),
                Text(
                  // Bilinmeyen değer "Belirtilmedi" değil "—": dört
                  // kutunun ikisinde uzun bir kelime, ızgarayı bozuyordu.
                  value ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sm.copyWith(
                    fontWeight: AppType.semibold,
                    color: value == null ? AppColors.inkMuted : AppColors.ink,
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

class _FeatureTag extends StatelessWidget {
  const _FeatureTag(this.label, this.active);

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: active ? AppColors.accentSoft : AppColors.inputBg,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(
        color: active ? AppColors.accentEdge : Colors.transparent,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          active ? Icons.check_rounded : Icons.remove_rounded,
          size: 13,
          color: active ? AppColors.accent : AppColors.inkMuted,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppType.xs.copyWith(
            color: active ? AppColors.accent : AppColors.inkMuted,
            fontWeight: active ? AppType.semibold : AppType.regular,
          ),
        ),
      ],
    ),
  );
}

class _ReasonList extends StatelessWidget {
  const _ReasonList({
    required this.title,
    required this.rows,
    required this.positive,
    required this.emptyText,
  });

  final String title;
  final List<PropertyScoreRow> rows;
  final bool positive;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.ok : AppColors.bad;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                positive ? Icons.thumb_up_outlined : Icons.thumb_down_outlined,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppType.xs.copyWith(
                  color: color,
                  fontWeight: AppType.semibold,
                ),
              ),
            ],
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(emptyText, style: AppType.muted(AppType.xs)),
            ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.label,
                          style: AppType.sm.copyWith(
                            fontWeight: AppType.medium,
                          ),
                        ),
                        Text(
                          '${formatMinutes(row.durationMin)} · hedef '
                          '≤${formatMinutes(row.targetMin)}',
                          style: AppType.muted(AppType.micro).copyWith(
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Alt skorun kendisi bir çubukla da anlatılıyor: "68"
                  // tek başına 100 üzerinden mi 10 üzerinden mi belli
                  // değildi.
                  SizedBox(
                    width: 54,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          row.subScore.round().toString(),
                          style: AppType.sm.copyWith(
                            color: color,
                            fontWeight: AppType.bold,
                            fontFeatures: AppType.tabularFigures,
                          ),
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: (row.subScore / 100).clamp(0, 1),
                            ),
                            duration: AppMotion.page,
                            curve: AppMotion.easeOut,
                            builder:
                                (context, value, _) => LinearProgressIndicator(
                                  value: value,
                                  minHeight: 3,
                                  color: color,
                                  backgroundColor: color.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                          ),
                        ),
                      ],
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

class _WeakLinkCard extends StatelessWidget {
  const _WeakLinkCard({required this.message, required this.points});

  final String message;
  final double points;

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
        const Icon(Icons.link_off, size: 18, color: AppColors.warn),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zayıf halka etkisi',
                style: AppType.xs.copyWith(
                  fontWeight: AppType.semibold,
                  color: AppColors.warn,
                ),
              ),
              Text(message, style: AppType.muted(AppType.xs)),
            ],
          ),
        ),
        Text(
          points.toStringAsFixed(1),
          style: AppType.h3.copyWith(
            color: AppColors.warn,
            fontFeatures: AppType.tabularFigures,
          ),
        ),
      ],
    ),
  );
}

/// Tam kriter tablosu — kapalı başlıyor.
///
/// Üç sütun: Kriter | Süre | Puan. Katkı sütunu ("puan × ağırlık") ve
/// yoğunluk metni içsel hesap detaylarıydı; kullanıcı için jargon gibi
/// duruyordu. Web de aynı üç sütunu gösteriyor.
class _ScoreTable extends StatefulWidget {
  const _ScoreTable({required this.rows, required this.total});

  final List<PropertyScoreRow> rows;
  final double total;

  @override
  State<_ScoreTable> createState() => _ScoreTableState();
}

class _ScoreTableState extends State<_ScoreTable> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceSunken,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tüm kriterler (${widget.rows.length})',
                    style: AppType.sm.copyWith(fontWeight: AppType.medium),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
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
              _open
                  ? Column(
                    children: [
                      const Divider(height: 1),
                      for (final row in widget.rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 7,
                          ),
                          child: Row(
                            children: [
                              _StatusDot(row.status),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(row.label, style: AppType.xs),
                              ),
                              Text(
                                formatMinutes(row.durationMin),
                                style: AppType.xs.copyWith(
                                  fontFeatures: AppType.tabularFigures,
                                ),
                              ),
                              SizedBox(
                                width: 38,
                                child: Text(
                                  row.subScore.round().toString(),
                                  textAlign: TextAlign.right,
                                  style: AppType.xs.copyWith(
                                    fontWeight: AppType.semibold,
                                    fontFeatures: AppType.tabularFigures,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('TOPLAM', style: AppType.micro),
                            ),
                            Text(
                              widget.total.toStringAsFixed(1),
                              style: AppType.sm.copyWith(
                                fontWeight: AppType.bold,
                                fontFeatures: AppType.tabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                  : const SizedBox(width: double.infinity),
        ),
      ],
    ),
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'strong' => AppColors.ok,
      'ok' => AppColors.good,
      'fair' => AppColors.warn,
      _ => AppColors.bad,
    };
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget});

  final PropertyBudgetFit budget;

  @override
  Widget build(BuildContext context) {
    // Durum rengi mesajın TONUNU taşıyor: bütçenin altında kalmak
    // (`info`) ile bütçeyi aşmak (`warn`) aynı renkte olamaz.
    final color = switch (budget.status) {
      'within' => AppColors.ok,
      'below' => AppColors.info,
      'above' => AppColors.warn,
      _ => AppColors.inkMuted,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  budget.message,
                  style: AppType.sm.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
          if (budget.ratioToMax case final ratio?) ...[
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio.clamp(0, 1)),
                duration: AppMotion.page,
                curve: AppMotion.easeOut,
                builder:
                    (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 5,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Bütçe üst sınırının %${(ratio * 100).round()}\'i',
              style: AppType.muted(AppType.micro).copyWith(letterSpacing: 0),
            ),
          ],
        ],
      ),
    );
  }
}

class _StrengthPoiNotice extends StatelessWidget {
  const _StrengthPoiNotice({
    required this.loading,
    required this.error,
    required this.count,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final int count;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        error != null ? Icons.error_outline : Icons.auto_awesome,
        size: 16,
        color: error != null ? AppColors.bad : AppColors.accent,
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          loading
              ? 'Güçlü yön noktaları yükleniyor…'
              : error ??
                  'Bu evi güçlü yapan $count hizmet noktası haritada '
                      'işaretlendi.',
          style: AppType.muted(AppType.xs),
        ),
      ),
      if (loading)
        const SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      else if (error != null)
        IconButton(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: 'Tekrar dene',
          visualDensity: VisualDensity.compact,
        ),
    ],
  );
}

/// Detay iskeleti — gelecek içeriğin ölçüsünü önceden gösteriyor.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.xs,
      AppSpacing.page,
      AppSpacing.xl,
    ),
    children: [
      const AspectRatio(aspectRatio: 16 / 7, child: _SkeletonBox()),
      const SizedBox(height: AppSpacing.sm),
      const SizedBox(height: 76, child: _SkeletonBox()),
      const SizedBox(height: AppSpacing.sm),
      const SizedBox(height: 50, child: _SkeletonBox()),
      const SizedBox(height: AppSpacing.lg),
      const SizedBox(height: 110, child: _SkeletonBox()),
    ],
  );
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.inputBg,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
  );
}
