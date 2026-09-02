import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/storage/app_flags.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/mascot.dart';
import '../../../../shared/widgets/page_parts.dart';
import '../../../auth/application/session_controller.dart';
import '../../../favorites/application/favorites_controller.dart';
import '../../../location/application/user_location_controller.dart';
import '../../../location_analysis/application/area_poi_controller.dart';
import '../../../location_analysis/data/api_area_poi_gateway.dart';
import '../../../location_analysis/domain/location_analysis.dart';
import '../../../location_analysis/presentation/widgets/area_poi_panel.dart';
import '../../../location_analysis/presentation/widgets/location_analysis_controls.dart';
import '../../../location_search/application/location_search_controller.dart';
import '../../../location_search/domain/location_search_models.dart';
import '../../../location_search/presentation/widgets/location_search_panel.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';
import '../../../map_data/application/map_data_controller.dart';
import '../../../map_data/data/api_map_data_gateway.dart';
import '../../../map_data/domain/map_data_models.dart';
import '../../../map_data/presentation/widgets/map_item_details_sheet.dart';
import '../../../map_data/presentation/widgets/map_layer_button.dart';
import '../../../properties/application/property_catalog_controller.dart';
import '../../../properties/domain/property_gateway.dart';
import '../../../properties/presentation/pages/property_detail_page.dart';
import '../../../properties/presentation/property_format.dart';
import '../../../property_strengths/domain/strength_poi_gateway.dart';
import '../../../routes/application/routes_controller.dart';
import '../../../routes/domain/route_models.dart';

/// Harita sekmesi.
///
/// ⚠️ HARİTA EKRANIN KENDİSİ
///
/// Harita bir `Column`un içinde, üstünde persona kartı, altında yardım
/// metni, her yanında 16 px boşlukla duruyordu. Telefonun dar ekranında
/// haritaya kalan alan yarıdan azdı. Artık tam ekran; kontroller üstünde
/// yüzüyor — web'deki Keşfet ekranıyla aynı fikir.
///
/// ⚠️ KONTROLLER ORTAK BİR IZGARADAN BESLENİYOR
///
/// Eskiden her kontrol kendi sayısını taşıyordu: arama `top + 10`, katman
/// düğmesi `top + 74`, ipucu şeridi `bottom: 74`, analiz düğmesi
/// `bottom: 12`, rota şeridi `168` px genişlik ve `top + 70 / bottom: 90`.
/// Dar telefonda rota şeridi katman düğmesinin, kaydet düğmesi analiz
/// düğmesinin üstüne biniyordu. Hepsi artık [AppSpacing.mapGutter],
/// [AppSpacing.mapStack] ve [AppSpacing.mapControl] üzerinden hesaplanıyor.
class MapTab extends StatefulWidget {
  const MapTab({
    required this.controller,
    required this.propertyGateway,
    required this.propertyCatalog,
    required this.favorites,
    required this.routes,
    required this.userLocation,
    required this.searchController,
    required this.strengthPoiGateway,
    required this.onOpenAnchors,
    super.key,
  });

  final SessionController controller;
  final PropertyGateway propertyGateway;
  final PropertyCatalogController propertyCatalog;
  final FavoritesController favorites;
  final RoutesController routes;
  final StrengthPoiGateway strengthPoiGateway;

  /// Rotalar/Konutlar sekmeleriyle PAYLAŞILAN örnekler — bkz. `HomePage`.
  final UserLocationController userLocation;
  final LocationSearchController searchController;

  /// Önemli konum ekranını açar.
  ///
  /// Konumu olmayan kullanıcıya gösterilen şerit, kullanıcıyı bir yere
  /// GÖNDERMEK yerine oraya GÖTÜRÜYOR: "Profil sekmesinden ekle" demek,
  /// kullanıcıyı iki dokunuş uzaktaki bir menüyü aramaya bırakıyordu.
  final VoidCallback onOpenAnchors;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  late final MapDataController _mapData;

  /// Analiz alanı içindeki hizmet noktaları — çember bırakıldığında
  /// açılan panelin verisi.
  late final AreaPoiController _areaPois;

  LocationSearchResult? _mapFocus;
  AnalysisCoordinate? _analysisCenter;
  double _analysisRadiusKm = defaultAnalysisRadiusKm;
  int _walkingMinutes = defaultWalkingMinutes;

  /// Analiz merkezi seçme kipi. Yalnızca "Uygula" sonrası açılır ve İLK
  /// dokunuşta kapanır — kipin açık kaldığını unutup haritayı kirletmesin.
  bool _pickingAnalysisPoint = false;

  // ── Rehber turu ──────────────────────────────────────────────────────
  final _flags = AppFlags();
  final _searchKey = GlobalKey();
  final _layersKey = GlobalKey();
  final _locationKey = GlobalKey();
  final _analysisKey = GlobalKey();
  bool _tourVisible = false;

  UserLocationController get _userLocation => widget.userLocation;

  @override
  void initState() {
    super.initState();
    _mapData = MapDataController(
      gateway: ApiMapDataGateway(widget.controller.client),
      authenticated: true,
    );
    _mapData.initialize();
    _areaPois = AreaPoiController(
      ApiAreaPoiGateway(widget.controller.client),
    );
    _maybeStartTour();
  }

  @override
  void dispose() {
    // `searchController` ve `userLocation` BURADA elden çıkarılmıyor:
    // sahibi `HomePage`, Rotalar sekmesi de aynı örnekleri kullanıyor.
    _mapData.dispose();
    _areaPois.dispose();
    super.dispose();
  }

  /// Analiz alanını kurar ve içindeki noktaları getirmeye başlar.
  void _setAnalysisCenter(AnalysisCoordinate center) {
    setState(() {
      _mapFocus = null;
      _analysisCenter = center;
      _pickingAnalysisPoint = false;
    });
    _areaPois.setArea(
      center: center,
      radiusM: walkingRadiusMetres(_walkingMinutes),
    );
  }

  void _clearAnalysis() {
    setState(() => _analysisCenter = null);
    _areaPois.clear();
  }

  /// Rehber turu yalnızca İLK açılışta ve harita yerleştikten sonra.
  ///
  /// Hemen başlatılsaydı tur, henüz çizilmemiş bir haritanın üstünde
  /// açılırdı: kullanıcı neyin anlatıldığını göremezdi.
  Future<void> _maybeStartTour() async {
    if (await _flags.isSet(AppFlags.seenMapTour)) return;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _tourVisible = true);
  }

  Future<void> _finishTour() async {
    setState(() => _tourVisible = false);
    await _flags.set(AppFlags.seenMapTour);
  }

  /// Konum düğmesi. Konum İSTENMEDEN alınmıyor — uygulama açılır açılmaz
  /// izin sormak, kullanıcının neden sorulduğunu anlamadan reddetmesine yol
  /// açıyor ve bir kez "bir daha sorma" denince sistem diyaloğu bir daha
  /// hiç açılmıyor.
  Future<void> _goToMyLocation() async {
    final result = await _userLocation.request();
    if (!mounted) return;

    if (result != null) {
      setState(() {
        _mapFocus = LocationSearchResult(
          id: 'canli-konum',
          label: 'Canlı konumum',
          kind: 'live',
          source: 'device',
          latitude: result.latitude,
          longitude: result.longitude,
        );
      });
      return;
    }

    final message = _userLocation.message;
    if (message == null) return;
    showAppSnack(
      context,
      message,
      tone: SnackTone.error,
      action:
          _userLocation.needsAppSettings
              ? SnackBarAction(
                label: 'Ayarlar',
                onPressed: _userLocation.openSettings,
              )
              : null,
    );
  }

  /// Haritada bir konuta dokunulunca.
  ///
  /// Rota DÜZENLEME KİPİNDEYKEN (haritada bir rota açıkken) dokunuş detay
  /// açmak yerine durağı ekliyor/çıkarıyor ve rota yeniden optimize
  /// ediliyor. Web'de de böyle: rota kipindeyken pin'ler seçim aracı
  /// hâline geliyor.
  Future<void> _handlePropertyTap(PropertyMapItem property) async {
    final route = widget.routes.activeRoute;
    final id = int.tryParse(property.id);
    if (route == null || id == null) {
      await _openProperty(property.id);
      return;
    }

    final current = route.propertyIds;
    final next =
        current.contains(id)
            ? current.where((value) => value != id).toList()
            : [...current, id];

    final ok = await widget.routes.reoptimize(next);
    if (!mounted || ok) return;
    final message = widget.routes.errorMessage;
    if (message != null) showAppSnack(context, message, tone: SnackTone.error);
  }

  Future<void> _openProperty(String propertyId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => PropertyDetailPage(
              propertyId: propertyId,
              gateway: widget.propertyGateway,
              favorites: widget.favorites,
              routes: widget.routes,
              strengthPoiGateway: widget.strengthPoiGateway,
              client: widget.controller.client,
              onFavoriteChanged: widget.propertyCatalog.updateFavorite,
            ),
      ),
    );
  }

  Future<void> _removeStopFromMap(int propertyId) async {
    final route = widget.routes.activeRoute;
    if (route == null) return;
    final next =
        route.propertyIds.where((value) => value != propertyId).toList();
    final ok = await widget.routes.reoptimize(next);
    if (!mounted || ok) return;
    final message = widget.routes.errorMessage;
    if (message != null) showAppSnack(context, message, tone: SnackTone.error);
  }

  Future<void> _saveRouteFromMap() async {
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => _MapSaveRouteDialog(
            initialName: widget.routes.activeRoute?.name ?? 'Ziyaret rotası',
          ),
    );
    if (name == null || !mounted) return;

    final ok = await widget.routes.saveActiveRoute(name: name);
    if (!mounted) return;
    showAppSnack(
      context,
      ok ? 'Rota kaydedildi.' : widget.routes.errorMessage ?? 'Rota kaydedilemedi.',
      tone: ok ? SnackTone.success : SnackTone.error,
    );
  }

  Future<void> _openLocationAnalysisSettings() async {
    final settings = await showLocationAnalysisSettingsSheet(
      context,
      analysisRadiusKm: _analysisRadiusKm,
      walkingMinutes: _walkingMinutes,
    );
    if (!mounted || settings == null) return;

    setState(() {
      _analysisRadiusKm = settings.analysisRadiusKm;
      _walkingMinutes = settings.walkingMinutes;
      // "Uygula" analizi hemen ÇİZMEZ, önce nokta seçtirir. Eskiden alan
      // haritaya her dokunuşta kuruluyordu: kullanıcı haritayı gezerken
      // istemediği hâlde sarı daire çıkıyordu.
      _pickingAnalysisPoint = true;
    });

    // Alan zaten kuruluysa yeni yarıçapla yeniden hesaplanıyor: kullanıcı
    // yürüme süresini 15'ten 30'a çıkardığında liste eski çemberin
    // sonuçlarını göstermeye devam etseydi çember ile liste yalan söylerdi.
    final center = _analysisCenter;
    if (center != null) {
      _areaPois.setArea(
        center: center,
        radiusM: walkingRadiusMetres(settings.walkingMinutes),
      );
    }
  }

  /// Favori konutları harita öğesine çevirir.
  ///
  /// Favori kaydı skoru ve koordinatı zaten taşıyor (`PropertySummary`);
  /// haritaya ayrı bir istek atmaya gerek yok.
  List<PropertyMapItem> get _favoriteMapItems {
    if (!_mapData.favoritesVisible) return const [];
    return [
      for (final entry in widget.favorites.items)
        if (entry.property case final property?)
          PropertyMapItem(
            id: property.id,
            externalRef: property.externalRef,
            latitude: property.latitude,
            longitude: property.longitude,
            monthlyRent: property.monthlyRent,
            areaM2: property.areaM2,
            roomCount: property.roomCount,
            totalScore: property.totalScore,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _mapData,
        widget.routes,
        widget.favorites,
        _userLocation,
        _areaPois,
      ]),
      builder: (context, _) => _buildStack(context),
    );
  }

  Widget _buildStack(BuildContext context) {
    final media = MediaQuery.of(context);
    final anchors = widget.controller.profile?.anchors ?? const <Anchor>[];
    final route = widget.routes.activeRoute;

    // ── IZGARA ────────────────────────────────────────────────────────
    // Tek bir hesap: her kontrol bu üç değerden türüyor.
    const gutter = AppSpacing.mapGutter;
    final topRow = media.padding.top + gutter;
    final secondRow = topRow + AppSpacing.mapSearchHeight + AppSpacing.mapStack;
    final bottomRow = gutter;
    // Sağdaki düğme sütununun kapladığı genişlik — soldaki yüzeyler bu
    // kadar geride bitiyor ki üst üste binmesinler.
    const rightColumn = AppSpacing.mapControl + gutter;

    // BİR KEZ kuruluyor: iki yerde çağrılsaydı (şeridin kendisi ve rota
    // şeridinin başlangıç hesabı) her yeniden çizimde giriş animasyonu
    // baştan başlardı.
    final banner = _statusBanner(anchors);

    return Stack(
      children: [
        Positioned.fill(
          child: CankayaMap(
            anchors: anchors,
            focus: _mapFocus,
            analysisCenter: _analysisCenter,
            analysisRadiusKm: _analysisRadiusKm,
            walkingMinutes: _walkingMinutes,
            pois: _mapData.pois,
            // Analiz listesindeki noktalar haritada da VURGULU: listede
            // "Migros 240 m" okuyan kullanıcı onu haritada aramak zorunda
            // kalmıyor.
            highlightedPois: _areaPois.highlighted,
            properties:
                _mapData.propertiesVisible ? _mapData.properties : const [],
            favorites: _favoriteMapItems,
            // ⚠️ ANCHOR KORİDORU KULLANICIYA GÖSTERİLMİYOR — kesik çizgili
            // alan mentorun doğrulaması içindi, doğrulama bitti. Katmana
            // DOKUNULMADI, yalnızca veri akışı kesildi.
            anchorCorridor: null,
            route: route,
            userLocation: _userLocation.location,
            onBoundsChanged: _mapData.updateViewport,
            onPoiTap:
                (poi) => showPoiDetailsSheet(
                  context,
                  poi: poi,
                  category: _mapData.categoryFor(poi.categoryCode),
                ),
            onPropertyTap: _handlePropertyTap,
            onMapTap: (latitude, longitude) {
              if (!_pickingAnalysisPoint) return;
              _setAnalysisCenter(
                AnalysisCoordinate(latitude: latitude, longitude: longitude),
              );
            },
          ),
        ),

        // ── Üst sıra: arama ────────────────────────────────────────────
        Positioned(
          top: topRow,
          left: gutter,
          right: gutter,
          child: KeyedSubtree(
            key: _searchKey,
            child: LocationSearchPanel(
              controller: widget.searchController,
              // Arama yalnızca haritayı o noktaya taşır; analiz alanı
              // ÇİZMEZ. Adres aramak "burayı analiz et" demek değil,
              // "buraya bak" demek.
              onSelected: (result) => setState(() => _mapFocus = result),
              onCleared: () => setState(() => _mapFocus = null),
            ),
          ),
        ),

        // ── Sağ sütun: katmanlar, konum ────────────────────────────────
        Positioned(
          top: secondRow,
          right: gutter,
          child: Column(
            children: [
              KeyedSubtree(
                key: _layersKey,
                child: MapLayerButton(
                  controller: _mapData,
                  favoriteCount: widget.favorites.items.length,
                ),
              ),
              const SizedBox(height: AppSpacing.mapStack),
              KeyedSubtree(
                key: _locationKey,
                child: MapCircleButton(
                  icon:
                      _userLocation.status == UserLocationStatus.ready
                          ? Icons.my_location
                          : Icons.location_searching,
                  busy: _userLocation.status == UserLocationStatus.locating,
                  active: _userLocation.location != null,
                  tooltip: 'Konumuma git',
                  onPressed: _goToMyLocation,
                ),
              ),
            ],
          ),
        ),

        // ── Durum şeridi ───────────────────────────────────────────────
        // TEK bir yuva, öncelik sıralı. Eskiden üç ayrı şerit üç ayrı
        // yerde duruyordu ve ikisi aynı anda çıkabiliyordu.
        if (banner != null)
          Positioned(
            top: secondRow,
            left: gutter,
            right: rightColumn + gutter,
            child: banner,
          ),

        // ── Rota kipi ──────────────────────────────────────────────────
        if (route != null) ...[
          Positioned(
            left: gutter,
            // Durum şeridi varsa onun altından başlıyor.
            top: secondRow + (banner == null ? 0 : 56),
            bottom: bottomRow + AppSpacing.mapControl + AppSpacing.mapStack,
            child: _RouteStopsRail(
              route: route,
              busy: widget.routes.saving,
              onRemove: _removeStopFromMap,
              onClose: widget.routes.closeActiveRoute,
            ),
          ),
          if (widget.routes.isPreviewing || widget.routes.hasUnsavedChanges)
            Positioned(
              right: gutter,
              bottom: bottomRow,
              child: FilledButton.icon(
                onPressed: widget.routes.saving ? null : _saveRouteFromMap,
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('Rotayı kaydet'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppSpacing.mapControl),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  elevation: 6,
                  shadowColor: AppColors.accent.withValues(alpha: 0.4),
                ),
              ),
            ),
        ]
        // Analiz araçları rota kipinde GİZLİ: o an kullanıcı rota
        // kuruyor, iki farklı iş aynı köşede yarışmasın.
        else if (_analysisCenter != null)
          // ── Alan içi hizmet noktaları ────────────────────────────────
          // Alan kurulduğunda düğmenin YERİNE panel geçiyor: ikisi de
          // aynı işin parçası ve alt köşede iki ayrı yüzeyin yarışması
          // gerekmiyor. Panel katlanınca düğme kadar yer kaplıyor.
          Positioned(
            left: gutter,
            right: gutter,
            bottom: bottomRow,
            child: KeyedSubtree(
              key: _analysisKey,
              child: AreaPoiPanel(
                controller: _areaPois,
                categories: _mapData.categories,
                walkingMinutes: _walkingMinutes,
                onPoiSelected: (poi) {
                  setState(() {
                    _mapFocus = LocationSearchResult(
                      id: 'area-poi-${poi.id}',
                      label: poi.name ?? 'Hizmet noktası',
                      kind: 'poi',
                      source: 'vivido',
                      latitude: poi.latitude,
                      longitude: poi.longitude,
                    );
                  });
                },
                onClose: _clearAnalysis,
              ),
            ),
          )
        else
          Positioned(
            left: gutter,
            bottom: bottomRow,
            child: KeyedSubtree(
              key: _analysisKey,
              child: LocationAnalysisLauncher(
                hasSelectedLocation: false,
                analysisRadiusKm: _analysisRadiusKm,
                walkingMinutes: _walkingMinutes,
                onOpen: _openLocationAnalysisSettings,
                onClear: _clearAnalysis,
              ),
            ),
          ),

        // ── Rehber turu ────────────────────────────────────────────────
        if (_tourVisible)
          Positioned.fill(
            child: GuideTour(
              onFinished: _finishTour,
              // Maskot alt menünün ÜSTÜNDE dursun; sıfır olsaydı ekranın
              // en altına oturur ve menü onu yarıya kadar keserdi.
              bottomInset: AppSpacing.xs,
              steps: [
                const TourStep(
                  title: 'Hoş geldin 👋',
                  text:
                      'Sana en uygun kiralık evleri haritada nasıl '
                      'bulacağını göstereyim. Bir dakika sürer.',
                ),
                TourStep(
                  title: 'Arama',
                  text:
                      'Aradığın mahalleyi, caddeyi veya bir adresi yazıp '
                      'haritayı doğrudan oraya taşıyabilirsin.',
                  targetKey: _searchKey,
                ),
                TourStep(
                  title: 'Katmanlar',
                  text:
                      'Haritada hangi konutların ve hizmetlerin '
                      'görüneceğini buradan seçersin. Favorilerin altın '
                      'yıldızla işaretlenir.',
                  targetKey: _layersKey,
                ),
                TourStep(
                  title: 'Konumum',
                  text:
                      'Bulunduğun yeri haritada görmek ve rotalarına '
                      'başlangıç yapmak için.',
                  targetKey: _locationKey,
                ),
                TourStep(
                  title: 'Çevre analizi',
                  text:
                      'Seçtiğin bir noktanın çevresindeki yürüme mesafesini '
                      've analiz alanını buradan ayarlarsın.',
                  targetKey: _analysisKey,
                ),
                // ⚠️ SON ADIM SEKME DEĞİŞTİRMİYOR. Bir zamanlar `onEnter`
                // ile Konutlar sekmesine geçiyordu; o geçiş `MapTab`'i
                // ağaçtan söküyor, tur onunla birlikte yok oluyor ve
                // `onFinished` hiç çalışmadığı için bayrak yazılmıyordu —
                // tur her açılışta yeniden başlıyordu. Yönlendirme
                // metinde kalıyor, eylem kullanıcıda.
                const TourStep(
                  title: 'Hazırsın 🎉',
                  text:
                      'Alttaki Konutlar sekmesinde sana en uygun evlerin '
                      'sıralı listesini ve puan gerekçelerini bulacaksın. '
                      'Rehberi tekrar açmak için Profil › Rehberi göster.',
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Durum şeridi — öncelik: nokta seçimi > hata > boş anchor ipucu.
  Widget? _statusBanner(List<Anchor> anchors) {
    if (_pickingAnalysisPoint) {
      return _MapBanner(
        icon: Icons.touch_app_outlined,
        text: 'Analiz için haritada bir nokta seç',
        tone: _BannerTone.action,
        onDismiss: () => setState(() => _pickingAnalysisPoint = false),
      );
    }
    if (_mapData.errorMessage case final message?) {
      return _MapBanner(
        icon: Icons.cloud_off_outlined,
        text: message,
        tone: _BannerTone.error,
      );
    }
    if (anchors.isEmpty) {
      return _MapBanner(
        icon: Icons.place_outlined,
        text: 'Skorların için düzenli gittiğin yerleri ekle',
        onTap: widget.onOpenAnchors,
      );
    }
    return null;
  }
}

enum _BannerTone { info, action, error }

/// Harita üstünde yüzen ince bilgi şeridi.
class _MapBanner extends StatelessWidget {
  const _MapBanner({
    required this.icon,
    required this.text,
    this.tone = _BannerTone.info,
    this.onDismiss,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final _BannerTone tone;
  final VoidCallback? onDismiss;

  /// Verilirse şeridin tamamı dokunulabilir olur ve sağında bir ok çıkar.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Eylem şeridi DOLU accent: kullanıcıdan bir şey bekleniyor ve bunun
    // bilgi şeridinden ayrışması gerekiyor.
    final solid = tone == _BannerTone.action;
    final accentColor = switch (tone) {
      _BannerTone.action => AppColors.accentInk,
      _BannerTone.error => AppColors.bad,
      _BannerTone.info => AppColors.accent,
    };

    Widget content = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        10,
        onDismiss == null ? AppSpacing.sm : 4,
        10,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppType.xs.copyWith(
                height: 1.35,
                color: solid ? AppColors.accentInk : AppColors.ink,
                fontWeight:
                    solid || onTap != null
                        ? AppType.semibold
                        : AppType.regular,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 17, color: accentColor),
              tooltip: 'Vazgeç',
              visualDensity: VisualDensity.compact,
            )
          else if (onTap != null)
            Icon(Icons.chevron_right, size: 18, color: accentColor),
        ],
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: content,
      );
    }

    // Şerit yukarıdan İNEREK geliyor — geldiği yön (üstteki arama çubuğu)
    // ile kaybolduğu yön aynı.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.base,
      curve: AppMotion.easeOut,
      builder:
          (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, -10 * (1 - value)),
              child: child,
            ),
          ),
      child:
          solid
              ? DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.accent,
                ),
                child: content,
              )
              : GlassSurface(
                borderRadius: BorderRadius.circular(AppRadius.md),
                shadow: AppShadows.md,
                child: content,
              ),
    );
  }
}

/// Haritanın solunda duran rota durakları şeridi.
///
/// Rotalar sekmesindeki tam listeyi tekrar etmiyor: haritada asıl gereken
/// "hangi ev kaçıncı sırada" ve "bunu çıkar".
class _RouteStopsRail extends StatelessWidget {
  const _RouteStopsRail({
    required this.route,
    required this.busy,
    required this.onRemove,
    required this.onClose,
  });

  final RouteDetail route;
  final bool busy;
  final ValueChanged<int> onRemove;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SizedBox(
    // Genişlik ekranın yarısını AŞMIYOR: sabit 168 px, küçük telefonlarda
    // haritanın yarısını kapatıyordu.
    width: (MediaQuery.sizeOf(context).width * 0.46).clamp(150.0, 190.0),
    child: GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 6, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${route.stops.length} durak · '
                    '${formatDuration(route.totalDurationS)}',
                    style: AppType.xs.copyWith(fontWeight: AppType.semibold),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 17),
                  tooltip: 'Rotayı kapat',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: route.stops.length,
              itemBuilder: (context, index) {
                final stop = route.stops[index];
                // Son iki durakta çıkarma kapalı: rota en az 2 durak
                // istiyor, düğmeyi aktif bırakmak kullanıcıyı hata
                // mesajına yürütmek olurdu.
                final canRemove = !busy && route.stops.length > minRouteStops;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(10, 1, 2, 1),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.mapRoute,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${stop.sequence}',
                          style: AppType.micro.copyWith(
                            color: Colors.white,
                            letterSpacing: 0,
                            fontFeatures: AppType.tabularFigures,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          '${stop.property.roomCount} · '
                          '${stop.property.areaM2} m²',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.xs,
                        ),
                      ),
                      IconButton(
                        onPressed:
                            canRemove ? () => onRemove(stop.propertyId) : null,
                        icon: const Icon(Icons.remove_circle_outline, size: 16),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: 'Rotadan çıkar',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 6, AppSpacing.sm, 8),
            child: Text(
              'Eklemek için haritada bir eve dokun',
              style: AppType.muted(AppType.micro).copyWith(letterSpacing: 0),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Haritadan kaydederken ad soran diyalog.
class _MapSaveRouteDialog extends StatefulWidget {
  const _MapSaveRouteDialog({required this.initialName});

  final String initialName;

  @override
  State<_MapSaveRouteDialog> createState() => _MapSaveRouteDialogState();
}

class _MapSaveRouteDialogState extends State<_MapSaveRouteDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rotayı kaydet'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Rota adı'),
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        child: const Text('Kaydet'),
      ),
    ],
  );
}
