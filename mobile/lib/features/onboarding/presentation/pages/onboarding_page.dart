import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../anchors/presentation/pages/anchor_manager_page.dart';
import '../../../auth/application/session_controller.dart';
import '../../../preferences/domain/life_criteria.dart';
import '../../../preferences/presentation/widgets/life_criteria_order_list.dart';
import '../../../../shared/widgets/budget_range_fields.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.controller, super.key});

  final SessionController controller;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _minBudgetController = TextEditingController();
  final _maxBudgetController = TextEditingController();
  String? _selectedPersona;
  List<String> _categoryOrder = const [];
  int _step = 0;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile;
    if (profile != null) {
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
      _selectedPersona = profile.personaCode;
      _categoryOrder = profile.categoryOrder;
      _minBudgetController.text =
          profile.minMonthlyBudget?.toStringAsFixed(0) ?? '';
      _maxBudgetController.text =
          profile.maxMonthlyBudget?.toStringAsFixed(0) ?? '';
      _step = 1;
    } else {
      _prefillName(widget.controller.user?.displayName);
    }
    _loadPersonas();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _minBudgetController.dispose();
    _maxBudgetController.dispose();
    super.dispose();
  }

  void _prefillName(String? displayName) {
    final parts =
        (displayName ?? '')
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList();
    if (parts.isEmpty) return;
    _firstNameController.text = parts.first;
    if (parts.length > 1) {
      _lastNameController.text = parts.skip(1).join(' ');
    }
  }

  Future<void> _loadPersonas() async {
    await widget.controller.ensurePersonas();
    if (!mounted || _selectedPersona == null) return;
    final persona = _findPersona(_selectedPersona!);
    if (persona == null) return;
    setState(() {
      _categoryOrder = resolveLifeCriteriaOrder(
        persona: persona,
        savedOrder: _categoryOrder,
      );
    });
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
    final profile = widget.controller.profile;
    final savedOrder =
        profile?.personaCode == code
            ? profile!.categoryOrder
            : const <String>[];
    setState(() {
      _selectedPersona = code;
      _categoryOrder = resolveLifeCriteriaOrder(
        persona: persona,
        savedOrder: savedOrder,
      );
    });
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final persona = _selectedPersona;
    if (persona == null) return;
    if (_categoryOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yaşam kriterleri yüklenemedi.')),
      );
      return;
    }
    final minBudget = parseBudgetInput(_minBudgetController.text);
    final maxBudget = parseBudgetInput(_maxBudgetController.text);

    final success = await widget.controller.saveProfile(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      personaCode: persona,
      minMonthlyBudget: minBudget,
      maxMonthlyBudget: maxBudget,
      categoryOrder: _categoryOrder,
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
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          children: [
            Text(
              'Önce seni tanıyalım',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Profil bilgilerin ve yaşam önceliklerin sana uygun sonuçları hazırlamak için kullanılır.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _firstNameController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.givenName],
              decoration: const InputDecoration(
                labelText: 'Ad',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: _requiredName,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _lastNameController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.familyName],
              decoration: const InputDecoration(
                labelText: 'Soyad',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: _requiredName,
            ),
            const SizedBox(height: 28),
            Text(
              'Sana en yakın yaşam tarzı hangisi?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                  onTap: () => _selectPersona(persona.code),
                ),
                const SizedBox(height: 10),
              ],
            if (_selectedPersona != null) ...[
              const SizedBox(height: 18),
              LifeCriteriaOrderList(
                categoryOrder: _categoryOrder,
                enabled: !widget.controller.busy,
                onChanged: (order) => setState(() => _categoryOrder = order),
              ),
            ],
            const SizedBox(height: 18),
            BudgetRangeFields(
              minController: _minBudgetController,
              maxController: _maxBudgetController,
              enabled: !widget.controller.busy,
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
                  _selectedPersona == null ||
                          _categoryOrder.isEmpty ||
                          widget.controller.busy
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
      ),
    );
  }

  String? _requiredName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Bu alan zorunludur.' : null;
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
