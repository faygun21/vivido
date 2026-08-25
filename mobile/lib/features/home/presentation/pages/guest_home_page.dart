import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../auth/application/session_controller.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../auth/presentation/pages/register_page.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';
import '../../../map_data/application/map_data_controller.dart';
import '../../../map_data/data/api_map_data_gateway.dart';
import '../../../map_data/presentation/widgets/map_item_details_sheet.dart';
import '../../../map_data/presentation/widgets/map_layer_button.dart';

/// Misafir ana ekranı — W0.
///
/// Kayıt olmadan girilebilen tek ekran: Çankaya haritası ve konutların
/// temel bilgileri. Skor, persona seçimi ve önemli konum ekleme kilitli;
/// bunlara dokunulduğunda giriş/kayıt ekranına yönlendirilir.
///
/// Kilitli özellikleri gizlemek yerine GÖSTERİP sebebini yazıyoruz —
/// "burada ne kaçırıyorum?" sorusunun cevabı kayıt olmanın tek gerekçesi.
class GuestHomePage extends StatefulWidget {
  const GuestHomePage({required this.controller, super.key});

  final SessionController controller;

  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage> {
  late final MapDataController _mapDataController;

  @override
  void initState() {
    super.initState();
    _mapDataController = MapDataController(
      gateway: ApiMapDataGateway(widget.controller.client),
      authenticated: false,
    );
    _mapDataController.initialize();
  }

  @override
  void dispose() {
    _mapDataController.dispose();
    super.dispose();
  }

  void _openAuth(BuildContext context, {required bool register}) {
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Vivido',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Chip(
                label: const Text('Misafir'),
                visualDensity: VisualDensity.compact,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Misafirde anchor yok — boş liste geçiyoruz, harita bileşeni
              // giriş yapmış kullanıcıdakiyle birebir aynı kalıyor.
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _mapDataController,
                        builder:
                            (context, _) => CankayaMap(
                              anchors: const <Anchor>[],
                              pois: _mapDataController.pois,
                              properties:
                                  _mapDataController.propertiesVisible
                                      ? _mapDataController.properties
                                      : const [],
                              onBoundsChanged:
                                  _mapDataController.updateViewport,
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
                                  (property) => showPropertyDetailsSheet(
                                    context,
                                    property,
                                  ),
                            ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: MapLayerButton(controller: _mapDataController),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _LockedFeaturesCard(
                onRegister: () => _openAuth(context, register: true),
                onLogin: () => _openAuth(context, register: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedFeaturesCard extends StatelessWidget {
  const _LockedFeaturesCard({required this.onRegister, required this.onLogin});

  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Misafir olarak geziyorsun',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Haritayı ve konutların temel bilgilerini serbestçe inceleyebilirsin. '
              'Şunlar için hesap gerekiyor:',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 10),
            const _LockedRow(
              icon: Icons.insights_outlined,
              text: 'Kişiselleştirilmiş 0–100 skor ve gerekçe tablosu',
            ),
            const _LockedRow(
              icon: Icons.auto_awesome_outlined,
              text: 'Persona seçimi ve aylık kira bütçesi',
            ),
            const _LockedRow(
              icon: Icons.place_outlined,
              text: 'Düzenli gittiğin yerleri ekleme ve sıralama',
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRegister,
              child: const Text('Ücretsiz hesap oluştur'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onLogin,
              child: const Text('Zaten hesabım var'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 4),
          Icon(Icons.lock_outline, size: 14, color: colors.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
