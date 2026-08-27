import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../anchors/presentation/pages/anchor_manager_page.dart';
import '../../../auth/application/session_controller.dart';
import '../../../favorites/application/favorites_controller.dart';
import '../../../favorites/data/api_favorites_gateway.dart';
import '../../../favorites/presentation/pages/favorites_page.dart';
import '../../../location_search/application/location_search_controller.dart';
import '../../../location_search/data/api_location_search_gateway.dart';
import '../../../location_search/domain/location_search_models.dart';
import '../../../location_search/presentation/widgets/location_search_panel.dart';
import '../../../location_analysis/domain/location_analysis.dart';
import '../../../location_analysis/presentation/widgets/location_analysis_controls.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';
import '../../../map_data/application/map_data_controller.dart';
import '../../../map_data/data/api_map_data_gateway.dart';
import '../../../map_data/domain/map_data_models.dart';
import '../../../map_data/presentation/widgets/map_item_details_sheet.dart';
import '../../../map_data/presentation/widgets/map_layer_button.dart';
import '../../../preferences/domain/life_criteria.dart';
import '../../../preferences/presentation/widgets/life_criteria_order_list.dart';
import '../../../properties/application/property_catalog_controller.dart';
import '../../../properties/data/api_property_gateway.dart';
import '../../../properties/domain/property_gateway.dart';
import '../../../properties/presentation/pages/property_detail_page.dart';
import '../../../properties/presentation/pages/property_list_page.dart';
import '../../../routes/application/routes_controller.dart';
import '../../../routes/data/api_routes_gateway.dart';
import '../../../routes/presentation/pages/routes_page.dart';
import '../../../../shared/widgets/budget_range_fields.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.controller, this.initialIndex = 0, super.key})
    : assert(initialIndex >= 0 && initialIndex < 5);

  final SessionController controller;
  final int initialIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex;
  late final PropertyGateway _propertyGateway;
  late final PropertyCatalogController _propertyCatalog;
  late final FavoritesController _favorites;
  late final RoutesController _routes;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _propertyGateway = ApiPropertyGateway(widget.controller.client);
    _propertyCatalog = PropertyCatalogController(_propertyGateway);
    _favorites = FavoritesController(
      ApiFavoritesGateway(widget.controller.client),
    );
    _routes = RoutesController(ApiRoutesGateway(widget.controller.client));
  }

  @override
  void dispose() {
    _propertyCatalog.dispose();
    _favorites.dispose();
    _routes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        const titles = [
          'Harita',
          'Konutlar',
          'Favorilerim',
          'Rotalarım',
          'Profil',
        ];
        final anchors = widget.controller.profile?.anchors ?? const <Anchor>[];
        final isMapTab = _selectedIndex == 0;
        return Scaffold(
          // Harita sekmesinde başlık çubuğu YOK: harita ekranın tepesine
          // kadar uzanıyor ve arama kutusu doğrudan onun üstünde yüzüyor
          // (webdeki Keşfet ekranıyla aynı fikir). Diğer sekmeler liste
          // olduğu için başlığa ihtiyaç duyuyor.
          appBar: isMapTab
              ? null
              : AppBar(title: Text(titles[_selectedIndex])),
          body: switch (_selectedIndex) {
            0 => _MapOverview(
              controller: widget.controller,
              propertyGateway: _propertyGateway,
              propertyCatalog: _propertyCatalog,
              favorites: _favorites,
              routes: _routes,
            ),
            1 => PropertyListPage(
              controller: _propertyCatalog,
              gateway: _propertyGateway,
              favorites: _favorites,
              routes: _routes,
            ),
            2 => FavoritesPage(
              controller: _favorites,
              propertyGateway: _propertyGateway,
              propertyCatalog: _propertyCatalog,
              routes: _routes,
            ),
            3 => RoutesPage(
              controller: _routes,
              anchors: anchors,
              onShowOnMainMap: () => setState(() => _selectedIndex = 0),
            ),
            _ => _ProfileView(
              controller: widget.controller,
              onProfileChanged: _refreshPersonalizedHousing,
              onManageAnchors: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder:
                        (_) => AnchorManagerPage(controller: widget.controller),
                  ),
                );
                if (mounted) _refreshPersonalizedHousing();
              },
            ),
          },
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Harita',
              ),
              NavigationDestination(
                icon: Icon(Icons.home_work_outlined),
                selectedIcon: Icon(Icons.home_work),
                label: 'Konutlar',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'Favoriler',
              ),
              NavigationDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route),
                label: 'Rotalar',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          ),
        );
      },
    );
  }

  void _refreshPersonalizedHousing() {
    unawaited(_propertyCatalog.load(force: true));
    unawaited(_favorites.load(force: true));
  }
}

class _MapOverview extends StatefulWidget {
  const _MapOverview({
    required this.controller,
    required this.propertyGateway,
    required this.propertyCatalog,
    required this.favorites,
    required this.routes,
  });

  final SessionController controller;
  final PropertyGateway propertyGateway;
  final PropertyCatalogController propertyCatalog;
  final FavoritesController favorites;
  final RoutesController routes;

  @override
  State<_MapOverview> createState() => _MapOverviewState();
}

class _MapOverviewState extends State<_MapOverview> {
  late final LocationSearchController _searchController;
  late final MapDataController _mapDataController;
  LocationSearchResult? _mapFocus;
  AnalysisCoordinate? _analysisCenter;
  double _analysisRadiusKm = defaultAnalysisRadiusKm;
  int _walkingMinutes = defaultWalkingMinutes;

  @override
  void initState() {
    super.initState();
    _searchController = LocationSearchController(
      ApiLocationSearchGateway(widget.controller.client),
    );
    _mapDataController = MapDataController(
      gateway: ApiMapDataGateway(widget.controller.client),
      authenticated: true,
    );
    _mapDataController.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapDataController.dispose();
    super.dispose();
  }

  Future<void> _openProperty(PropertyMapItem property) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => PropertyDetailPage(
              propertyId: property.id,
              gateway: widget.propertyGateway,
              favorites: widget.favorites,
              routes: widget.routes,
              onFavoriteChanged: widget.propertyCatalog.updateFavorite,
            ),
      ),
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
      // ya da bir pin'e denk gelmeyen boş bir yere bastığında istemediği
      // hâlde sarı daire çıkıyordu. Artık analiz açıkça istenen bir eylem.
      _pickingAnalysisPoint = true;
    });
  }

  /// Analiz merkezi seçme kipi. Yalnızca "Uygula" sonrası açılır ve İLK
  /// dokunuşta kapanır — kipin açık kaldığını unutup haritayı kirletmesin.
  bool _pickingAnalysisPoint = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final profile = controller.profile;
    final anchors = profile?.anchors ?? const <Anchor>[];

    // ⚠️ TAM EKRAN HARİTA — eskiden harita bir Column'un içindeydi ve
    // üstünde persona kartı (~90 px), altında yardım metni (~40 px), her
    // yanında 16 px boşluk, tepesinde de AppBar vardı. Telefonun dar
    // ekranında haritaya kalan alan yarıdan azdı ve uygulama "harita
    // gösteren bir sayfa" gibi duruyordu. Webdeki Keşfet ekranı gibi artık
    // harita EKRANIN KENDİSİ; kontroller üstünde yüzüyor.
    //
    // Persona kartı kaldırıldı: taşıdığı bilgi (persona adı + anchor sayısı)
    // Profil sekmesinde zaten var, harita ekranında her açılışta yer kaplamak
    // için bir gerekçesi yoktu.
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _mapDataController,
                        widget.routes,
                      ]),
                      builder:
                          (context, _) => CankayaMap(
                            anchors: anchors,
                            focus: _mapFocus,
                            analysisCenter: _analysisCenter,
                            analysisRadiusKm: _analysisRadiusKm,
                            walkingMinutes: _walkingMinutes,
                            pois: _mapDataController.pois,
                            properties:
                                _mapDataController.propertiesVisible
                                    ? _mapDataController.properties
                                    : const [],
                            route: widget.routes.activeRoute,
                            onBoundsChanged: _mapDataController.updateViewport,
                            onPoiTap: (poi) {
                              showPoiDetailsSheet(
                                context,
                                poi: poi,
                                category: _mapDataController.categoryFor(
                                  poi.categoryCode,
                                ),
                              );
                            },
                            onPropertyTap: _openProperty,
                            onMapTap: (latitude, longitude) {
                              // Analiz alanı YALNIZCA seçim kipindeyken
                              // kurulur. Kip dışındaki dokunuşlar haritayı
                              // olduğu gibi bırakır.
                              if (!_pickingAnalysisPoint) return;
                              setState(() {
                                _mapFocus = null;
                                _analysisCenter = AnalysisCoordinate(
                                  latitude: latitude,
                                  longitude: longitude,
                                );
                                _pickingAnalysisPoint = false;
                              });
                            },
                          ),
                    ),
                  ),
        // Arama kutusu durum çubuğunun altına iniyor: AppBar kalktığı için
        // artık onu aşağı iten bir şey yok.
        Positioned(
          top: topInset + 10,
          left: 12,
          right: 12,
          child: LocationSearchPanel(
            controller: _searchController,
            onSelected: (result) {
              // Arama yalnızca haritayı o noktaya taşır; analiz alanı
              // ÇİZMEZ. Adres aramak "burayı analiz et" demek değil,
              // "buraya bak" demek.
              setState(() => _mapFocus = result);
            },
            onCleared: () {
              setState(() => _mapFocus = null);
            },
          ),
        ),
        Positioned(
          top: topInset + 74,
          right: 12,
          child: MapLayerButton(controller: _mapDataController),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: LocationAnalysisLauncher(
            hasSelectedLocation: _analysisCenter != null,
            analysisRadiusKm: _analysisRadiusKm,
            walkingMinutes: _walkingMinutes,
            onOpen: _openLocationAnalysisSettings,
            onClear: () {
              setState(() => _analysisCenter = null);
            },
          ),
        ),

        // Analiz noktası seçme kipi göstergesi. Kip sessiz olsaydı
        // kullanıcı "Uygula"ya bastıktan sonra hiçbir şey olmadığını
        // sanırdı; şerit hem ne beklendiğini söylüyor hem de vazgeçme
        // yolu veriyor.
        if (_pickingAnalysisPoint)
          Positioned(
            top: topInset + 74,
            left: 12,
            right: 68,
            child: _PickPointBanner(
              onCancel: () =>
                  setState(() => _pickingAnalysisPoint = false),
            ),
          ),

        // Boş durum ipucu — YALNIZCA hiç önemli konum yokken.
        //
        // Eski sabit yardım metni her zaman görünüyordu ve kalıcı olarak yer
        // kaplıyordu. Oysa "numaralar öncelik sırasını gösterir" bilgisi,
        // haritada zaten numaralı pin gören birine bir şey katmıyor. Asıl
        // gerekli olan, HİÇ konumu olmayan kullanıcıya nereye gideceğini
        // söylemek; o yüzden ipucu yalnızca o durumda ve yüzen bir şerit
        // olarak çıkıyor.
        if (anchors.isEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 74,
            child: _MapHintBanner(
              icon: Icons.place_outlined,
              text:
                  'Sana uygun evleri sıralayabilmemiz için Profil sekmesinden '
                  'önemli konumlarını ekle.',
            ),
          ),
      ],
    );
  }
}

/// Analiz noktası seçilmesini bekleyen şerit.
class _PickPointBanner extends StatelessWidget {
  const _PickPointBanner({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: AppShadows.md,
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          const Icon(Icons.touch_app_outlined, size: 18, color: Colors.white),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Analiz için haritada bir nokta seç',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 18, color: Colors.white),
            tooltip: 'Vazgeç',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    ),
  );
}

/// Harita üstünde yüzen ince bilgi şeridi.
class _MapHintBanner extends StatelessWidget {
  const _MapHintBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: AppShadows.md,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.controller,
    required this.onManageAnchors,
    required this.onProfileChanged,
  });

  final SessionController controller;
  final VoidCallback onManageAnchors;
  final VoidCallback onProfileChanged;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final persona =
        controller.personas
            .where((item) => item.code == profile?.personaCode)
            .firstOrNull;
    final profileName = [profile?.firstName, profile?.lastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    final criteriaSummary =
        profile == null || profile.categoryOrder.isEmpty
            ? 'Henüz sıralanmadı'
            : profile.categoryOrder.take(3).map(lifeCriterionLabel).join(' · ');

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          CircleAvatar(
            radius: 38,
            child: Icon(_personaIcon(profile?.personaCode), size: 38),
          ),
          const SizedBox(height: 14),
          Text(
            profileName.isNotEmpty
                ? profileName
                : controller.user?.displayName ?? 'Vivido kullanıcısı',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            controller.user?.email ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Persona'),
                  subtitle: Text(
                    persona?.displayNameTr ?? profile?.personaCode ?? '-',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Aylık kira aralığı'),
                  subtitle: Text(_formatBudgetRange(profile)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.format_list_numbered),
                  title: const Text('Yaşam kriterleri'),
                  subtitle: Text(criteriaSummary),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: const Text('Önemli konum'),
                  subtitle: Text('${profile?.anchors.length ?? 0}/3 konum'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onManageAnchors,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed:
                controller.busy
                    ? null
                    : () => _showProfileEditor(
                      context,
                      controller,
                      onSaved: onProfileChanged,
                    ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Profil ve tercihleri düzenle'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: controller.busy ? null : controller.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış yap'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showProfileEditor(
  BuildContext context,
  SessionController controller, {
  required VoidCallback onSaved,
}) async {
  final profile = controller.profile;
  if (profile == null) return;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (_) => _ProfileEditorSheet(
          controller: controller,
          initialProfile: profile,
          onSaved: onSaved,
        ),
  );
}

class _ProfileEditorSheet extends StatefulWidget {
  const _ProfileEditorSheet({
    required this.controller,
    required this.initialProfile,
    required this.onSaved,
  });

  final SessionController controller;
  final UserProfile initialProfile;
  final VoidCallback onSaved;

  @override
  State<_ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<_ProfileEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _minBudgetController;
  late final TextEditingController _maxBudgetController;
  late String _selectedPersona;
  late List<String> _categoryOrder;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.initialProfile.firstName,
    );
    _lastNameController = TextEditingController(
      text: widget.initialProfile.lastName,
    );
    _minBudgetController = TextEditingController(
      text: widget.initialProfile.minMonthlyBudget?.toStringAsFixed(0) ?? '',
    );
    _maxBudgetController = TextEditingController(
      text: widget.initialProfile.maxMonthlyBudget?.toStringAsFixed(0) ?? '',
    );
    _selectedPersona = widget.initialProfile.personaCode;
    final persona = _findPersona(_selectedPersona);
    _categoryOrder =
        persona == null
            ? List<String>.of(widget.initialProfile.categoryOrder)
            : resolveLifeCriteriaOrder(
              persona: persona,
              savedOrder: widget.initialProfile.categoryOrder,
            );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    super.dispose();
  }

  Persona? _findPersona(String code) {
    for (final persona in widget.controller.personas) {
      if (persona.code == code) return persona;
    }
    return null;
  }

  void _selectPersona(String code) {
    final persona = _findPersona(code);
    if (persona == null) return;
    final savedOrder =
        widget.initialProfile.personaCode == code
            ? widget.initialProfile.categoryOrder
            : const <String>[];
    setState(() {
      _selectedPersona = code;
      _categoryOrder = resolveLifeCriteriaOrder(
        persona: persona,
        savedOrder: savedOrder,
      );
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yaşam kriterleri yüklenemedi.')),
      );
      return;
    }

    final minBudget = parseBudgetInput(_minBudgetController.text);
    final maxBudget = parseBudgetInput(_maxBudgetController.text);

    setState(() => _saving = true);
    final saved = await widget.controller.saveProfile(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      personaCode: _selectedPersona,
      minMonthlyBudget: minBudget,
      maxMonthlyBudget: maxBudget,
      categoryOrder: _categoryOrder,
    );
    if (!mounted) return;

    if (saved) {
      widget.onSaved();
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.controller.errorMessage ?? 'Profil kaydedilemedi.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Profil tercihleri',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstNameController,
                  enabled: !_saving,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: const InputDecoration(labelText: 'Ad'),
                  validator: _requiredName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _lastNameController,
                  enabled: !_saving,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.familyName],
                  decoration: const InputDecoration(labelText: 'Soyad'),
                  validator: _requiredName,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPersona,
                  decoration: const InputDecoration(labelText: 'Persona'),
                  items: [
                    for (final persona in widget.controller.personas)
                      DropdownMenuItem(
                        value: persona.code,
                        child: Text(persona.displayNameTr),
                      ),
                  ],
                  onChanged:
                      _saving
                          ? null
                          : (value) {
                            if (value != null) _selectPersona(value);
                          },
                ),
                const SizedBox(height: 18),
                LifeCriteriaOrderList(
                  categoryOrder: _categoryOrder,
                  enabled: !_saving,
                  onChanged: (order) {
                    setState(() => _categoryOrder = order);
                  },
                ),
                const SizedBox(height: 14),
                BudgetRangeFields(
                  minController: _minBudgetController,
                  maxController: _maxBudgetController,
                  enabled: !_saving,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child:
                      _saving
                          ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Bu alan zorunludur.' : null;
}

String _formatBudgetRange(UserProfile? profile) {
  final minimum = profile?.minMonthlyBudget;
  final maximum = profile?.maxMonthlyBudget;
  if (minimum != null && maximum != null) {
    return '${minimum.toStringAsFixed(0)} ₺ - ${maximum.toStringAsFixed(0)} ₺';
  }
  if (minimum != null) return '${minimum.toStringAsFixed(0)} ₺ ve üzeri';
  if (maximum != null) return '${maximum.toStringAsFixed(0)} ₺\'ye kadar';
  return 'Belirtilmedi';
}

IconData _personaIcon(String? code) => switch (code) {
  'student' => Icons.school_outlined,
  'family_kids' => Icons.family_restroom,
  'remote_worker' => Icons.laptop_mac_outlined,
  'elderly' => Icons.accessible_forward_outlined,
  _ => Icons.person_outline,
};
