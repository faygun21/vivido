import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/mascot.dart';
import '../../../../shared/widgets/page_parts.dart';
import '../../../auth/application/session_controller.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/presentation/pages/register_page.dart';
import '../../../location_search/application/location_search_controller.dart';
import '../../../location_search/data/api_location_search_gateway.dart';
import '../../../location_search/domain/location_search_models.dart';
import '../../../location_search/presentation/widgets/location_search_panel.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';
import '../../../map_data/application/map_data_controller.dart';
import '../../../map_data/data/api_map_data_gateway.dart';
import '../../../map_data/presentation/widgets/map_item_details_sheet.dart';
import '../../../map_data/presentation/widgets/map_layer_button.dart';

/// Misafir ana ekranı — W0 / R-10 / R-11.
///
/// ⚠️ MİSAFİR EKRANI BAŞKA BİR UYGULAMA GİBİ DURUYORDU
///
/// Giriş yapan kullanıcı TAM EKRAN bir harita görüyordu; misafir ise
/// `Padding(16)` içinde, köşeleri yuvarlatılmış, altında büyük bir kartla
/// sıkıştırılmış küçük bir harita. Ne arama kutusu, ne konum düğmesi, ne
/// alt menü. Kayıt olan kullanıcı, o ana kadar kullandığı ekranın tamamen
/// değiştiğini görüyordu.
///
/// Artık kabuk AYNI: tam ekran harita, aynı ızgara, aynı kontroller.
/// Fark yalnızca KİLİTLİ olanlar — ve onlar gizlenmiyor, gösterilip
/// sebebi yazılıyor. "Burada ne kaçırıyorum?" sorusunun cevabı, kayıt
/// olmanın tek gerekçesi.
class GuestHomePage extends StatefulWidget {
  const GuestHomePage({required this.controller, super.key});

  final SessionController controller;

  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage> {
  late final MapDataController _mapData;
  late final LocationSearchController _search;
  LocationSearchResult? _focus;

  @override
  void initState() {
    super.initState();
    _mapData = MapDataController(
      gateway: ApiMapDataGateway(widget.controller.client),
      authenticated: false,
    );
    _mapData.initialize();
    _search = LocationSearchController(
      ApiLocationSearchGateway(widget.controller.client),
    );
  }

  @override
  void dispose() {
    _mapData.dispose();
    _search.dispose();
    super.dispose();
  }

  void _openAuth({required bool register}) {
    widget.controller.clearError();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) =>
                register
                    ? RegisterPage(controller: widget.controller)
                    : LoginPage(controller: widget.controller),
      ),
    );
  }

  Future<void> _showLockedSheet() => showAppSheet<void>(
    context,
    builder:
        (_) => _LockedFeaturesSheet(
          onRegister: () {
            Navigator.of(context).pop();
            _openAuth(register: true);
          },
          onLogin: () {
            Navigator.of(context).pop();
            _openAuth(register: false);
          },
        ),
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const gutter = AppSpacing.mapGutter;
    final topRow = media.padding.top + gutter;
    final secondRow = topRow + AppSpacing.mapSearchHeight + AppSpacing.mapStack;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _mapData,
        builder:
            (context, _) => Stack(
              children: [
                Positioned.fill(
                  child: CankayaMap(
                    anchors: const <Anchor>[],
                    focus: _focus,
                    pois: _mapData.pois,
                    properties:
                        _mapData.propertiesVisible
                            ? _mapData.properties
                            : const [],
                    onBoundsChanged: _mapData.updateViewport,
                    onPoiTap:
                        (poi) => showPoiDetailsSheet(
                          context,
                          poi: poi,
                          category: _mapData.categoryFor(poi.categoryCode),
                        ),
                    // Misafirin skoru yok; alt sayfa temel bilgileri
                    // gösteriyor ve skorun kilitli olduğunu söylüyor.
                    onPropertyTap:
                        (property) => showPropertyDetailsSheet(
                          context,
                          property,
                          onUnlock: () => _openAuth(register: true),
                        ),
                  ),
                ),

                Positioned(
                  top: topRow,
                  left: gutter,
                  right: gutter,
                  child: LocationSearchPanel(
                    controller: _search,
                    onSelected: (result) => setState(() => _focus = result),
                    onCleared: () => setState(() => _focus = null),
                  ),
                ),

                Positioned(
                  top: secondRow,
                  right: gutter,
                  child: MapLayerButton(controller: _mapData),
                ),

                // Kilitli özellikler ŞERİDİ — eskiden ekranın üçte birini
                // kaplayan bir karttı ve haritayı eziyordu. Artık altta
                // ince bir şerit; ayrıntı için açılıyor.
                Positioned(
                  left: gutter,
                  right: gutter,
                  bottom: media.padding.bottom + gutter,
                  child: _GuestBar(
                    onExpand: _showLockedSheet,
                    onRegister: () => _openAuth(register: true),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

/// Alttaki misafir şeridi.
class _GuestBar extends StatelessWidget {
  const _GuestBar({required this.onExpand, required this.onRegister});

  final VoidCallback onExpand;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) => GlassSurface(
    borderRadius: BorderRadius.circular(AppRadius.lg),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 10, 10, 10),
      child: Row(
        children: [
          const MascotFigure(height: 44),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: GestureDetector(
              onTap: onExpand,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Misafir olarak geziyorsun',
                    style: AppType.sm.copyWith(fontWeight: AppType.semibold),
                  ),
                  Row(
                    children: [
                      Text(
                        'Neler kilitli?',
                        style: AppType.micro.copyWith(
                          color: AppColors.accent,
                          letterSpacing: 0,
                        ),
                      ),
                      const Icon(
                        Icons.expand_less,
                        size: 14,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          FilledButton(
            onPressed: onRegister,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              textStyle: AppType.sm.copyWith(fontWeight: AppType.semibold),
            ),
            child: const Text('Kayıt ol'),
          ),
        ],
      ),
    ),
  );
}

class _LockedFeaturesSheet extends StatelessWidget {
  const _LockedFeaturesSheet({
    required this.onRegister,
    required this.onLogin,
  });

  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => SafeArea(
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
          const SheetHeader(
            title: 'Hesapla neler açılıyor?',
            subtitle:
                'Haritayı ve temel konut bilgilerini zaten serbestçe '
                'inceleyebilirsin.',
            icon: MascotFigure(height: 56),
          ),
          const _LockedRow(
            icon: Icons.insights_outlined,
            title: 'Kişiselleştirilmiş 0–100 skor',
            subtitle: 'Her ev için satır satır gerekçe tablosu',
          ),
          const _LockedRow(
            icon: Icons.auto_awesome_outlined,
            title: 'Yaşam tarzı ve bütçe',
            subtitle: 'Evler senin önceliklerine göre sıralanır',
          ),
          const _LockedRow(
            icon: Icons.place_outlined,
            title: 'Önemli konumların',
            subtitle: 'İş, okul, spor salonu — skor bunlara göre hesaplanır',
          ),
          const _LockedRow(
            icon: Icons.route_outlined,
            title: 'Ziyaret rotası ve navigasyon',
            subtitle: 'Seçtiğin evleri en kısa sırayla gez',
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onRegister,
            child: const Text('Ücretsiz hesap oluştur'),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: onLogin,
            child: const Text('Zaten hesabım var'),
          ),
        ],
      ),
    ),
  );
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: AppColors.accent),
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
              Text(
                subtitle,
                style: AppType.muted(AppType.micro).copyWith(
                  letterSpacing: 0,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
