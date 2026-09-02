import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/network/network_status_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../anchors/presentation/pages/anchor_manager_page.dart';
import '../../../auth/application/session_controller.dart';
import '../../../favorites/application/favorites_controller.dart';
import '../../../favorites/data/api_favorites_gateway.dart';
import '../../../favorites/data/cached_favorites_gateway.dart';
import '../../../favorites/data/secure_favorite_cache.dart';
import '../../../location/application/user_location_controller.dart';
import '../../../location_search/application/location_search_controller.dart';
import '../../../location_search/data/api_location_search_gateway.dart';
import '../../../properties/application/property_catalog_controller.dart';
import '../../../properties/data/api_property_gateway.dart';
import '../../../properties/data/cached_property_gateway.dart';
import '../../../properties/data/secure_property_list_cache.dart';
import '../../../properties/domain/property_gateway.dart';
import '../../../properties/presentation/pages/property_list_page.dart';
import '../../../property_strengths/data/api_strength_poi_gateway.dart';
import '../../../property_strengths/domain/strength_poi_gateway.dart';
import '../../../routes/application/routes_controller.dart';
import '../../../routes/data/api_routes_gateway.dart';
import '../../../routes/data/cached_routes_gateway.dart';
import '../../../routes/data/secure_route_list_cache.dart';
import '../../../routes/presentation/pages/routes_page.dart';
import 'map_tab.dart';
import 'profile_tab.dart';

/// Uygulama kabuğu.
///
/// ⚠️ BEŞ SEKME DÖRDE İNDİ
///
/// Eskiden Harita · Konutlar · Favoriler · Rotalar · Profil vardı. İki
/// sorun: (1) 11,5 px'lik beş etiket dar telefonda sıkışıyordu, (2)
/// "Konutlar" ve "Favoriler" AYNI kart tipini iki ayrı sekmede
/// gösteriyordu — favori, konutun bir alt kümesi, ayrı bir yer değil.
///
/// Favoriler artık iki yerde yaşıyor ve ikisi de doğru yer:
///   • Konutlar sekmesinde bir segment (Tümü / Favorilerim)
///   • Haritada bir katman (altın yıldız)
///
/// Web'in modeliyle aynı: katman panelinde favori satırı + favori listesi.
class HomePage extends StatefulWidget {
  const HomePage({required this.controller, this.initialIndex = 0, super.key})
    : assert(initialIndex >= 0 && initialIndex < 4);

  final SessionController controller;
  final int initialIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Sekme sırası — birden fazla yerde indeks karşılaştırıldığı için
/// isimlendirildi. `_selectedIndex == 2` okunmuyordu.
enum _Tab { map, properties, routes, profile }

class _HomePageState extends State<HomePage> {
  late _Tab _tab;
  late final PropertyGateway _propertyGateway;
  late final PropertyCatalogController _propertyCatalog;
  late final FavoritesController _favorites;
  late final RoutesController _routes;
  late final StrengthPoiGateway _strengthPoiGateway;
  late final NetworkStatusController _networkStatus;
  bool _wasOffline = false;

  /// Harita sekmesi rehberi yeniden başlatmak için bu anahtarla yeniden
  /// kuruluyor: `MapTab` turu `initState`'te okuyor.
  Key _mapKey = UniqueKey();

  /// Konut listesi "Favorilerim" segmentiyle açılsın mı — rehberin son
  /// adımı ve harita üstündeki ipuçları buraya yönlendirebiliyor.
  bool _propertiesShowFavorites = false;

  /// Konum ve adres araması BURADA yaşıyor, harita ekranında değil: hem
  /// harita hem Rotalar sekmesi kullanıyor. Ayrı örnekler olsaydı
  /// kullanıcıdan konum izni iki kez istenir, haritadaki mavi nokta ile
  /// rota başlangıcı farklı koordinatları gösterebilirdi.
  late final UserLocationController _userLocation;
  late final LocationSearchController _searchController;

  @override
  void initState() {
    super.initState();
    _tab = _Tab.values[widget.initialIndex];
    final userId =
        widget.controller.user?.id ??
        widget.controller.user?.email ??
        'unknown-user';
    _propertyGateway = CachedPropertyGateway(
      remote: ApiPropertyGateway(widget.controller.client),
      cache: SecurePropertyListCache(),
      userId: userId,
    );
    _propertyCatalog = PropertyCatalogController(_propertyGateway);
    _favorites = FavoritesController(
      CachedFavoritesGateway(
        remote: ApiFavoritesGateway(widget.controller.client),
        cache: SecureFavoriteCache(),
        userId: userId,
      ),
    );
    _routes = RoutesController(
      CachedRoutesGateway(
        remote: ApiRoutesGateway(widget.controller.client),
        cache: SecureRouteListCache(),
        userId: userId,
      ),
    );
    _userLocation = UserLocationController();
    _searchController = LocationSearchController(
      ApiLocationSearchGateway(widget.controller.client),
    );
    _strengthPoiGateway = ApiStrengthPoiGateway(widget.controller.client);
    _networkStatus = NetworkStatusController(PlatformConnectivityMonitor());
    _networkStatus.addListener(_handleNetworkStatusChanged);
    unawaited(_networkStatus.initialize());
    _preloadOfflineData();
  }

  @override
  void dispose() {
    _propertyCatalog.dispose();
    _favorites.dispose();
    _routes.dispose();
    _networkStatus
      ..removeListener(_handleNetworkStatusChanged)
      ..dispose();
    _userLocation.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refreshPersonalizedHousing() {
    unawaited(_propertyCatalog.load(force: true));
    unawaited(_favorites.load(force: true));
  }

  void _preloadOfflineData({bool force = false}) {
    unawaited(_propertyCatalog.load(force: force));
    unawaited(_favorites.load(force: force));
    unawaited(_routes.loadRoutes(force: force));
  }

  void _handleNetworkStatusChanged() {
    final reconnected = _wasOffline && !_networkStatus.isOffline;
    _wasOffline = _networkStatus.isOffline;
    if (reconnected) _preloadOfflineData(force: true);
    if (_networkStatus.initialized &&
        !_networkStatus.isOffline &&
        widget.controller.profile == null) {
      unawaited(widget.controller.reloadAfterConnectivity());
    }
  }

  Future<void> _openAnchors() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AnchorManagerPage(controller: widget.controller),
      ),
    );
    if (mounted) _refreshPersonalizedHousing();
  }

  /// Rehberi yeniden başlatır: bayrağı temizleyip harita sekmesini taze
  /// bir anahtarla kurar ve o sekmeye geçer.
  Future<void> _replayTour() async {
    await resetMapTour();
    if (!mounted) return;
    setState(() {
      _mapKey = UniqueKey();
      _tab = _Tab.map;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _networkStatus]),
      builder: (context, _) {
        final anchors = widget.controller.profile?.anchors ?? const <Anchor>[];
        final isMap = _tab == _Tab.map;

        return Scaffold(
          // Harita sekmesinde başlık çubuğu YOK: harita ekranın tepesine
          // kadar uzanıyor ve arama kutusu doğrudan onun üstünde yüzüyor.
          // Diğer sekmeler liste olduğu için başlığa ihtiyaç duyuyor.
          //
          // ⚠️ Sayfa GÖVDELERİ başlığı TEKRAR ETMİYOR. Eskiden AppBar
          // "Favorilerim" yazıyor, gövde yine "Favorilerim" başlığı
          // basıyordu — aynı kelime iki kez, iki farklı boyutta.
          appBar: isMap ? null : AppBar(title: Text(_title)),
          // ⚠️ `extendBody` KULLANILMIYOR. Haritayı alt menünün arkasına
          // uzatmak görsel olarak hiçbir şey kazandırmıyor (menü opak) ama
          // harita üstündeki kontrollerin `bottom` hesabını bozuyordu:
          // analiz düğmesi ve "Rotayı kaydet" menünün arkasında kalıyordu.
          body: _OfflineAwareBody(
            offline: _networkStatus.isOffline,
            child: _buildTab(anchors),
          ),
          bottomNavigationBar: _BottomNav(
            current: _tab,
            favoriteCount: _favorites.items.length,
            routeCount: _routes.draft.length,
            onSelected: (tab) {
              // Aynı sekmeye tekrar dokunmak Konutlar'da segmenti
              // sıfırlıyor — alışılmış "sekmeye basınca başa dön" davranışı.
              if (tab == _tab && tab == _Tab.properties) {
                setState(() => _propertiesShowFavorites = false);
                return;
              }
              setState(() => _tab = tab);
            },
          ),
        );
      },
    );
  }

  String get _title => switch (_tab) {
    _Tab.map => 'Harita',
    _Tab.properties => 'Konutlar',
    _Tab.routes => 'Rotalarım',
    _Tab.profile => 'Profilim',
  };

  Widget _buildTab(List<Anchor> anchors) => switch (_tab) {
    _Tab.map => MapTab(
      key: _mapKey,
      controller: widget.controller,
      propertyGateway: _propertyGateway,
      propertyCatalog: _propertyCatalog,
      favorites: _favorites,
      routes: _routes,
      userLocation: _userLocation,
      searchController: _searchController,
      strengthPoiGateway: _strengthPoiGateway,
      onOpenAnchors: _openAnchors,
    ),
    _Tab.properties => PropertyListPage(
      controller: _propertyCatalog,
      gateway: _propertyGateway,
      favorites: _favorites,
      routes: _routes,
      strengthPoiGateway: _strengthPoiGateway,
      client: widget.controller.client,
      networkStatus: _networkStatus,
      showFavorites: _propertiesShowFavorites,
      onShowFavoritesChanged:
          (value) => setState(() => _propertiesShowFavorites = value),
    ),
    _Tab.routes => RoutesPage(
      controller: _routes,
      anchors: anchors,
      onShowOnMainMap: () => setState(() => _tab = _Tab.map),
      userLocation: _userLocation,
      searchController: _searchController,
      offline: _networkStatus.isOffline,
    ),
    _Tab.profile => ProfileTab(
      controller: widget.controller,
      onProfileChanged: _refreshPersonalizedHousing,
      onManageAnchors: _openAnchors,
      onReplayTour: _replayTour,
    ),
  };
}

/// Alt menü.
///
/// Rozetler sayı taşıyor: kullanıcı sekmeye girmeden kaç favorisi ve rota
/// taslağında kaç ev olduğunu görüyor. Rota taslağı özellikle önemli —
/// kullanıcı bir yerde 3 ev seçip unutabiliyordu.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.current,
    required this.onSelected,
    required this.favoriteCount,
    required this.routeCount,
  });

  final _Tab current;
  final ValueChanged<_Tab> onSelected;
  final int favoriteCount;
  final int routeCount;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      // Kalın bir ayraç yerine ince bir çizgi: çubuğu ekrandan
      // koparmadan içerikten ayırıyor.
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: NavigationBar(
      selectedIndex: current.index,
      onDestinationSelected: (index) => onSelected(_Tab.values[index]),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Harita',
        ),
        NavigationDestination(
          icon: _CountIcon(Icons.home_work_outlined, favoriteCount),
          selectedIcon: _CountIcon(Icons.home_work, favoriteCount),
          label: 'Konutlar',
        ),
        NavigationDestination(
          icon: _CountIcon(Icons.route_outlined, routeCount),
          selectedIcon: _CountIcon(Icons.route, routeCount),
          label: 'Rotalar',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    ),
  );
}

class _CountIcon extends StatelessWidget {
  const _CountIcon(this.icon, this.count);

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return Icon(icon);
    return Badge(
      backgroundColor: AppColors.accent,
      textColor: AppColors.accentInk,
      textStyle: AppType.micro.copyWith(
        color: AppColors.accentInk,
        letterSpacing: 0,
        fontSize: 10,
      ),
      label: Text('$count'),
      child: Icon(icon),
    );
  }
}

class _OfflineAwareBody extends StatelessWidget {
  const _OfflineAwareBody({required this.offline, required this.child});

  final bool offline;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // Şerit yerini AÇARAK geliyor: bir anda beliren bir çubuk altındaki
      // içeriği zıplatıyordu.
      AnimatedSize(
        duration: AppMotion.base,
        curve: AppMotion.easeOut,
        alignment: Alignment.topCenter,
        child:
            offline
                ? const _OfflineBanner()
                : const SizedBox(width: double.infinity),
      ),
      Expanded(
        // ⚠️ ŞERİT ÜST BOŞLUĞU TÜKETİYOR. Harita sekmesinin `AppBar`ı yok
        // ve kontrollerini `MediaQuery.padding.top` üzerinden konumlandırıyor.
        // Şerit `SafeArea` ile o boşluğu zaten yediği hâlde MediaQuery
        // değişmediği için arama çubuğu şeridin ÜSTÜNE biniyordu.
        child:
            offline
                ? MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: child,
                )
                : child,
      ),
    ],
  );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.warn.withValues(alpha: 0.12),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: 10,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 18,
              color: AppColors.warn,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Çevrimdışısın. Güncel veri, harita, rota ve navigasyon '
                'internet bağlantısı gerektirir.',
                style: AppType.xs.copyWith(color: AppColors.warn),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
