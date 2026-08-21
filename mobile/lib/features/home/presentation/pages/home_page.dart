import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../anchors/presentation/pages/anchor_manager_page.dart';
import '../../../auth/application/session_controller.dart';
import '../../../map/presentation/widgets/cankaya_map.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.controller, super.key});

  final SessionController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

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

class _MapOverview extends StatelessWidget {
  const _MapOverview({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final anchors = profile?.anchors ?? const <Anchor>[];
    final persona = controller.personas
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
            Expanded(child: CankayaMap(anchors: anchors)),
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
    final persona = controller.personas
        .where((item) => item.code == profile?.personaCode)
        .firstOrNull;
    final budget = profile?.monthlyBudget;

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
            controller.user?.displayName ?? 'Vivido kullanıcısı',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
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
                  title: const Text('Aylık kira bütçesi'),
                  subtitle: Text(
                    budget == null
                        ? 'Belirtilmedi'
                        : '${budget.toStringAsFixed(0)} ₺',
                  ),
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
            onPressed: controller.busy
                ? null
                : () => _showProfileEditor(context, controller),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Persona ve bütçeyi düzenle'),
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
  final budgetController = TextEditingController(
    text: profile.monthlyBudget?.toStringAsFixed(0) ?? '',
  );
  var selectedPersona = profile.personaCode;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Profil tercihleri',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedPersona,
              decoration: const InputDecoration(labelText: 'Persona'),
              items: [
                for (final persona in controller.personas)
                  DropdownMenuItem(
                    value: persona.code,
                    child: Text(persona.displayNameTr),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setSheetState(() => selectedPersona = value);
                }
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: budgetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Aylık kira bütçesi',
                suffixText: '₺',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                final rawBudget = budgetController.text.trim();
                final budget = rawBudget.isEmpty
                    ? null
                    : double.tryParse(rawBudget.replaceAll(',', '.'));
                if (rawBudget.isNotEmpty && budget == null) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir bütçe gir.')),
                  );
                  return;
                }
                final saved = await controller.saveProfile(
                  personaCode: selectedPersona,
                  monthlyBudget: budget,
                );
                if (saved && sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    ),
  );
  budgetController.dispose();
}

IconData _personaIcon(String? code) => switch (code) {
  'student' => Icons.school_outlined,
  'family_kids' => Icons.family_restroom,
  'remote_worker' => Icons.laptop_mac_outlined,
  'elderly' => Icons.accessible_forward_outlined,
  _ => Icons.person_outline,
};
