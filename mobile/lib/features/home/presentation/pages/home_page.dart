import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../anchors/presentation/pages/anchor_manager_page.dart';
import '../../../auth/application/session_controller.dart';
import '../../../location_search/application/location_search_controller.dart';
import '../../../location_search/data/api_location_search_gateway.dart';
import '../../../location_search/domain/location_search_models.dart';
import '../../../location_search/presentation/widgets/location_search_panel.dart';
import '../../../location_analysis/domain/location_analysis.dart';
import '../../../location_analysis/presentation/widgets/location_analysis_controls.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';
import '../../../map_data/application/map_data_controller.dart';
import '../../../map_data/data/api_map_data_gateway.dart';
import '../../../map_data/presentation/widgets/map_item_details_sheet.dart';
import '../../../map_data/presentation/widgets/map_layer_button.dart';
import '../../../preferences/domain/life_criteria.dart';
import '../../../preferences/presentation/widgets/life_criteria_order_list.dart';
import '../../../../shared/widgets/budget_range_fields.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.controller, this.initialIndex = 0, super.key})
    : assert(initialIndex >= 0 && initialIndex < 3);

  final SessionController controller;
  final int initialIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final titles = ['Harita', 'Önemli konumlar', 'Profil'];
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _selectedIndex == 0 ? 'Vivido' : titles[_selectedIndex],
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          body: switch (_selectedIndex) {
            0 => _MapOverview(controller: widget.controller),
            1 => AnchorManagerPage(
              controller: widget.controller,
              embedded: true,
            ),
            _ => _ProfileView(controller: widget.controller),
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
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route),
                label: 'Konumlar',
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
}

class _MapOverview extends StatefulWidget {
  const _MapOverview({required this.controller});

  final SessionController controller;

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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final profile = controller.profile;
    final anchors = profile?.anchors ?? const <Anchor>[];
    final persona =
        controller.personas
            .where((item) => item.code == profile?.personaCode)
            .firstOrNull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      child: Icon(_personaIcon(profile?.personaCode)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Merhaba, ${controller.user?.displayName ?? controller.user?.email ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${persona?.displayNameTr ?? profile?.personaCode ?? 'Persona'} · ${anchors.length}/3 önemli konum',
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _mapDataController,
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
                            onPropertyTap:
                                (property) =>
                                    showPropertyDetailsSheet(context, property),
                            onMapTap: (latitude, longitude) {
                              setState(() {
                                _mapFocus = null;
                                _analysisCenter = AnalysisCoordinate(
                                  latitude: latitude,
                                  longitude: longitude,
                                );
                              });
                            },
                          ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: LocationSearchPanel(
                      controller: _searchController,
                      onSelected: (result) {
                        setState(() {
                          _mapFocus = result;
                          _analysisCenter = AnalysisCoordinate(
                            latitude: result.latitude,
                            longitude: result.longitude,
                          );
                        });
                      },
                      onCleared: () {
                        setState(() => _mapFocus = null);
                      },
                    ),
                  ),
                  Positioned(
                    top: 76,
                    right: 12,
                    child: MapLayerButton(controller: _mapDataController),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: LocationAnalysisControls(
                      hasSelectedLocation: _analysisCenter != null,
                      analysisRadiusKm: _analysisRadiusKm,
                      walkingMinutes: _walkingMinutes,
                      onAnalysisRadiusChanged: (value) {
                        setState(() => _analysisRadiusKm = value);
                      },
                      onWalkingMinutesChanged: (value) {
                        setState(() => _walkingMinutes = value);
                      },
                      onClear: () {
                        setState(() => _analysisCenter = null);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              anchors.isEmpty
                  ? 'Konumlar sekmesinden haritaya dokunarak ilk önemli konumunu ekle.'
                  : 'Numaralar öncelik sırasını gösterir. Sıralamayı Konumlar sekmesinden değiştirebilirsin.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.controller});

  final SessionController controller;

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
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed:
                controller.busy
                    ? null
                    : () => _showProfileEditor(context, controller),
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
  SessionController controller,
) async {
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
        ),
  );
}

class _ProfileEditorSheet extends StatefulWidget {
  const _ProfileEditorSheet({
    required this.controller,
    required this.initialProfile,
  });

  final SessionController controller;
  final UserProfile initialProfile;

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
