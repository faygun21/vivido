import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/brand_icon.dart';
import '../../../../shared/widgets/page_parts.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../../../shared/widgets/budget_range_fields.dart';
import '../../../anchors/presentation/pages/anchor_manager_page.dart';
import '../../../auth/application/session_controller.dart';
import '../../../preferences/domain/life_criteria.dart';
import '../../../preferences/presentation/widgets/life_criteria_order_list.dart';

/// Profil kurulum sihirbazı — iki adım: profil, sonra önemli konumlar.
///
/// ⚠️ PERSONA KARTLARI MARKA İKONLARINI KULLANMIYORDU
///
/// Web'in dört persona görseli var (`kep.svg`, `pc.svg`, `family.svg`,
/// `glasses.svg`) ve her birinin altında o personanın önemsediği üç
/// kategoriyi anlatan küçük ikonlar. Mobil bunların yerine Material'ın
/// jenerik glyph'lerini (`Icons.school_outlined`, `Icons.laptop_mac_outlined`)
/// kullanıyordu: aynı persona iki üründe iki farklı simgeyle görünüyordu.
///
/// Alt ikonlar da eklendi — kart artık "bu persona neyi önemser"i
/// açıklama metnini okumadan gösteriyor.
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
        profile?.personaCode == code ? profile!.categoryOrder : const <String>[];
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
      showAppSnack(
        context,
        'Yaşam kriterleri yüklenemedi.',
        tone: SnackTone.error,
      );
      return;
    }

    final success = await widget.controller.saveProfile(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      personaCode: persona,
      minMonthlyBudget: parseBudgetInput(_minBudgetController.text),
      maxMonthlyBudget: parseBudgetInput(_maxBudgetController.text),
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
              title: Text(_step == 0 ? 'Profilini hazırla' : 'Önemli konumlar'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Center(
                    child: Text(
                      '${_step + 1}/2',
                      style: AppType.muted(AppType.sm).copyWith(
                        fontFeatures: AppType.tabularFigures,
                      ),
                    ),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(3),
                // İlerleme çubuğu KAYARAK doluyor: adım atlandığında bir
                // anda yarıya sıçrayan bir çubuk, ilerlemeyi anlatmıyor.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (_step + 1) / 2),
                  duration: AppMotion.slow,
                  curve: AppMotion.easeOut,
                  builder:
                      (context, value, _) =>
                          LinearProgressIndicator(value: value, minHeight: 3),
                ),
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            Text('Önce seni tanıyalım', style: AppType.h1),
            const SizedBox(height: 4),
            Text(
              'Bu bilgiler her evin sana uygunluk skorunu hesaplamak için '
              'kullanılıyor.',
              style: AppType.muted(AppType.sm),
            ),

            const SectionHeader('ADIN'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    decoration: const InputDecoration(labelText: 'Ad'),
                    validator: _requiredName,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    decoration: const InputDecoration(labelText: 'Soyad'),
                    validator: _requiredName,
                  ),
                ),
              ],
            ),

            const SectionHeader('SANA EN YAKIN YAŞAM TARZI'),
            Text(
              'Seçimin, çevredeki hizmetlerin senin için ne kadar önemli '
              'olduğunu belirliyor.',
              style: AppType.muted(AppType.xs),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (personas.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              for (final (index, persona) in personas.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: StaggeredEntrance(
                    index: index,
                    child: _PersonaCard(
                      persona: persona,
                      selected: persona.code == _selectedPersona,
                      onTap: () => _selectPersona(persona.code),
                    ),
                  ),
                ),

            // Kriter sıralaması ve bütçe YALNIZCA persona seçildikten
            // sonra: boş bir sıralama listesi göstermek, kullanıcıya
            // henüz anlamı olmayan bir iş veriyordu.
            AnimatedSize(
              duration: AppMotion.base,
              curve: AppMotion.easeOut,
              alignment: Alignment.topCenter,
              child:
                  _selectedPersona == null
                      ? const SizedBox(width: double.infinity)
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader('ÖNEM SIRASI'),
                          Text(
                            'Sürükleyerek sırala — en üsttekinin skora '
                            'katkısı en yüksek.',
                            style: AppType.muted(AppType.xs),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          LifeCriteriaOrderList(
                            categoryOrder: _categoryOrder,
                            enabled: !widget.controller.busy,
                            onChanged:
                                (order) =>
                                    setState(() => _categoryOrder = order),
                          ),
                        ],
                      ),
            ),

            const SectionHeader('AYLIK KİRA ARALIĞI'),
            BudgetRangeFields(
              minController: _minBudgetController,
              maxController: _maxBudgetController,
              enabled: !widget.controller.busy,
            ),

            if (widget.controller.errorMessage case final error?) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.bad.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  error,
                  style: AppType.sm.copyWith(color: AppColors.bad),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.arrow_forward, size: 18),
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

/// Persona kartı — marka görseli + ad + açıklama + önemsediği kategoriler.
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
    final visual = personaVisual(persona.code);

    return Pressable(
      onTap: onTap,
      scale: 0.985,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? AppShadows.sm : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PersonaAvatar(
              personaCode: persona.code,
              size: 46,
              selected: selected,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(persona.displayNameTr, style: AppType.h3),
                  Text(
                    persona.descriptionTr,
                    style: AppType.muted(AppType.xs).copyWith(height: 1.4),
                  ),
                  if (visual.sub.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    // Alt ikonlar personanın önceliklerini SÖZ OLMADAN
                    // anlatıyor — web'deki `subIcons` ile aynı.
                    Row(
                      children: [
                        for (final icon in visual.sub)
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color:
                                    selected
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : AppColors.inputBg,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xs,
                                ),
                              ),
                              child: BrandIcon(
                                icon,
                                size: 14,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: AppMotion.fast,
              child: const Icon(
                Icons.check_circle,
                size: 22,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
