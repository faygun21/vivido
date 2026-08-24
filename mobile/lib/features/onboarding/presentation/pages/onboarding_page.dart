import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../anchors/presentation/pages/anchor_manager_page.dart';
import '../../../auth/application/session_controller.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.controller, super.key});

  final SessionController controller;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _budgetController = TextEditingController();
  String? _selectedPersona;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile;
    if (profile != null) {
      _selectedPersona = profile.personaCode;
      _budgetController.text = profile.monthlyBudget?.toStringAsFixed(0) ?? '';
      _step = 1;
    }
    widget.controller.ensurePersonas();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final persona = _selectedPersona;
    if (persona == null) return;
    final rawBudget = _budgetController.text.trim();
    final budget =
        rawBudget.isEmpty
            ? null
            : double.tryParse(rawBudget.replaceAll(',', '.'));
    if (rawBudget.isNotEmpty && budget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bütçe için geçerli bir sayı gir.')),
      );
      return;
    }

    final success = await widget.controller.saveProfile(
      personaCode: persona,
      monthlyBudget: budget,
    );
    if (success && mounted) setState(() => _step = 1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder:
          (context, _) => Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Profilini hazırla'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(child: Text('${_step + 1}/2')),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: (_step + 1) / 2),
              ),
            ),
            body:
                _step == 0
                    ? _buildProfileStep(context)
                    : AnchorManagerPage(
                      controller: widget.controller,
                      embedded: true,
                      onFinished: widget.controller.completeOnboarding,
                    ),
          ),
    );
  }

  Widget _buildProfileStep(BuildContext context) {
    final personas = widget.controller.personas;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
        children: [
          Text(
            'Sana en yakın yaşam tarzı hangisi?',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Seçimin, çevredeki hizmetlerin sana göre ağırlıklandırılmasını sağlar.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          if (personas.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else
            for (final persona in personas) ...[
              _PersonaCard(
                persona: persona,
                selected: persona.code == _selectedPersona,
                onTap: () => setState(() => _selectedPersona = persona.code),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 16),
          TextField(
            controller: _budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Aylık kira bütçesi (isteğe bağlı)',
              prefixIcon: Icon(Icons.payments_outlined),
              suffixText: '₺',
              helperText: 'Boş bırakırsan bütçe skoru devre dışı kalır.',
            ),
          ),
          if (widget.controller.errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              widget.controller.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed:
                _selectedPersona == null || widget.controller.busy
                    ? null
                    : _saveProfile,
            icon:
                widget.controller.busy
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.arrow_forward),
            label: const Text('Kaydet ve konumlara geç'),
          ),
        ],
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.persona,
    required this.selected,
    required this.onTap,
  });

  final Persona persona;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor:
                    selected ? colors.primary : colors.surfaceContainerHighest,
                foregroundColor: selected ? colors.onPrimary : colors.primary,
                child: Icon(_personaIcon(persona.code)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      persona.displayNameTr,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      persona.descriptionTr,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _personaIcon(String code) => switch (code) {
  'student' => Icons.school_outlined,
  'family_kids' => Icons.family_restroom,
  'remote_worker' => Icons.laptop_mac_outlined,
  'elderly' => Icons.accessible_forward_outlined,
  _ => Icons.person_outline,
};
