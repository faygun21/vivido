import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/storage/app_flags.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/brand_icon.dart';
import '../../../../shared/widgets/page_parts.dart';
import '../../../../shared/widgets/pressable.dart';
import '../../../../shared/widgets/budget_range_fields.dart';
import '../../../auth/application/session_controller.dart';
import '../../../preferences/domain/life_criteria.dart';
import '../../../preferences/presentation/widgets/life_criteria_order_list.dart';

/// Profil sekmesi.
///
/// ⚠️ Eskiden düz bir `Card` içinde dört `ListTile` vardı: Persona, Bütçe,
/// Kriterler, Konumlar. Hepsi aynı ağırlıkta görünüyordu ve hiçbiri
/// kullanıcının profilinin ne İŞE yaradığını anlatmıyordu.
///
/// Yeni düzen bilgiyi işlevine göre ayırıyor: üstte kimlik (persona
/// görseliyle), sonra skoru etkileyen üç ayar, en altta hesap işlemleri.
class ProfileTab extends StatelessWidget {
  const ProfileTab({
    required this.controller,
    required this.onManageAnchors,
    required this.onProfileChanged,
    required this.onReplayTour,
    super.key,
  });

  final SessionController controller;
  final VoidCallback onManageAnchors;
  final VoidCallback onProfileChanged;

  /// Rehber turunu yeniden açar — web'de maskota tıklayarak yapılan şey.
  final VoidCallback onReplayTour;

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
    final anchorCount = profile?.anchors.length ?? 0;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.xs,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          // ── Kimlik ───────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                PersonaAvatar(
                  personaCode: profile?.personaCode,
                  size: 76,
                  selected: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  profileName.isNotEmpty
                      ? profileName
                      : controller.user?.displayName ?? 'Vivido kullanıcısı',
                  textAlign: TextAlign.center,
                  style: AppType.h2,
                ),
                Text(
                  controller.user?.email ?? '',
                  textAlign: TextAlign.center,
                  style: AppType.muted(AppType.sm),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Skoru etkileyen ayarlar ──────────────────────────────────
          // Başlık bunun bir ayar listesi DEĞİL, skorun girdisi olduğunu
          // söylüyor: kullanıcı neden bu bilgileri verdiğini görmeli.
          const SectionHeader('SKORUNU BELİRLEYENLER'),
          _ProfileCard(
            children: [
              _ProfileRow(
                icon: BrandIcon(
                  personaVisual(profile?.personaCode).main,
                  size: 18,
                  color: AppColors.accent,
                ),
                title: 'Yaşam tarzı',
                value: persona?.displayNameTr ?? profile?.personaCode ?? '—',
              ),
              _ProfileRow(
                icon: const Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: AppColors.accent,
                ),
                title: 'Aylık kira aralığı',
                value: _formatBudgetRange(profile),
              ),
              _ProfileRow(
                icon: const Icon(
                  Icons.format_list_numbered,
                  size: 18,
                  color: AppColors.accent,
                ),
                title: 'Yaşam kriterleri',
                value: criteriaSummary,
              ),
              _ProfileRow(
                icon: const Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: AppColors.accent,
                ),
                title: 'Önemli konumların',
                value: '$anchorCount / 3 konum',
                // Konumu OLMAYAN kullanıcı skorun yarısını kaçırıyor;
                // satır bunu sessizce geçmiyor.
                warning: anchorCount == 0 ? 'Skor için gerekli' : null,
                onTap: onManageAnchors,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed:
                controller.busy
                    ? null
                    : () => _showProfileEditor(
                      context,
                      controller,
                      onSaved: onProfileChanged,
                    ),
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Profil ve tercihleri düzenle'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentSoft,
              foregroundColor: AppColors.accent,
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          // ── Uygulama ─────────────────────────────────────────────────
          const SectionHeader('UYGULAMA'),
          _ProfileCard(
            children: [
              _ProfileRow(
                icon: const Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: AppColors.accent,
                ),
                title: 'Rehberi tekrar göster',
                value: 'Haritayı adım adım anlatır',
                onTap: onReplayTour,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: controller.busy ? null : controller.logout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Çıkış yap'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.bad,
              side: BorderSide(color: AppColors.bad.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const Divider(height: 1, indent: 52),
          children[index],
        ],
      ],
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.value,
    this.warning,
    this.onTap,
  });

  final Widget icon;
  final String title;
  final String value;

  /// Eksik/dikkat gerektiren bir durum varsa değerin yanında uyarı çipi.
  final String? warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    enabled: onTap != null,
    scale: 0.99,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Center(child: icon)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.muted(AppType.xs)),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: AppType.sm.copyWith(fontWeight: AppType.medium),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (warning != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warn.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                warning!,
                style: AppType.micro.copyWith(
                  color: AppColors.warn,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.inkMuted,
              ),
            ),
        ],
      ),
    ),
  );
}

String _formatBudgetRange(UserProfile? profile) {
  final minimum = profile?.minMonthlyBudget;
  final maximum = profile?.maxMonthlyBudget;
  String money(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write('.');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }

  if (minimum != null && maximum != null) {
    return '${money(minimum)} ₺ – ${money(maximum)} ₺';
  }
  if (minimum != null) return '${money(minimum)} ₺ ve üzeri';
  if (maximum != null) return '${money(maximum)} ₺\'ye kadar';
  return 'Belirtilmedi';
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
    // Alt sayfa ekranın tamamını kaplamıyor: üstte kalan harita/liste
    // şeridi, kullanıcının nereden geldiğini hatırlatıyor ve kapatmanın
    // "aşağı çekmek" olduğunu ima ediyor.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
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
      showAppSnack(
        context,
        'Yaşam kriterleri yüklenemedi.',
        tone: SnackTone.error,
      );
      return;
    }

    setState(() => _saving = true);
    final saved = await widget.controller.saveProfile(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      personaCode: _selectedPersona,
      minMonthlyBudget: parseBudgetInput(_minBudgetController.text),
      maxMonthlyBudget: parseBudgetInput(_maxBudgetController.text),
      categoryOrder: _categoryOrder,
    );
    if (!mounted) return;

    if (saved) {
      widget.onSaved();
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = false);
    showAppSnack(
      context,
      widget.controller.errorMessage ?? 'Profil kaydedilemedi.',
      tone: SnackTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Profil tercihleri', style: AppType.h2),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              enabled: !_saving,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.givenName],
                              decoration: const InputDecoration(
                                labelText: 'Ad',
                              ),
                              validator: _requiredName,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              enabled: !_saving,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.familyName],
                              decoration: const InputDecoration(
                                labelText: 'Soyad',
                              ),
                              validator: _requiredName,
                            ),
                          ),
                        ],
                      ),
                      const SectionHeader('YAŞAM TARZI'),
                      // ⚠️ Açılır liste (`DropdownButtonFormField`) GİTTİ:
                      // dört seçenek var ve her birinin bir görseli — hepsi
                      // aynı anda görünmeli. Açılır liste seçenekleri
                      // saklıyordu ve onboarding'deki kartlarla hiç
                      // benzemiyordu (aynı seçim, iki farklı arayüz).
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final persona in widget.controller.personas)
                            _PersonaChip(
                              persona: persona,
                              selected: persona.code == _selectedPersona,
                              onTap:
                                  _saving
                                      ? null
                                      : () => _selectPersona(persona.code),
                            ),
                        ],
                      ),
                      const SectionHeader('ÖNEM SIRASI'),
                      LifeCriteriaOrderList(
                        categoryOrder: _categoryOrder,
                        enabled: !_saving,
                        onChanged:
                            (order) => setState(() => _categoryOrder = order),
                      ),
                      const SectionHeader('AYLIK KİRA ARALIĞI'),
                      BudgetRangeFields(
                        minController: _minBudgetController,
                        maxController: _maxBudgetController,
                        enabled: !_saving,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child:
                            _saving
                                ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('Kaydet'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Bu alan zorunludur.' : null;
}

/// Persona seçim çipi — görsel + ad.
class _PersonaChip extends StatelessWidget {
  const _PersonaChip({
    required this.persona,
    required this.selected,
    required this.onTap,
  });

  final Persona persona;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.96,
    child: AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      padding: const EdgeInsets.fromLTRB(6, 5, AppSpacing.sm, 5),
      decoration: BoxDecoration(
        color: selected ? AppColors.accentSoft : AppColors.inputBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: selected ? AppColors.accent : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PersonaAvatar(
            personaCode: persona.code,
            size: 26,
            selected: selected,
          ),
          const SizedBox(width: 6),
          Text(
            persona.displayNameTr,
            style: AppType.xs.copyWith(
              fontWeight: selected ? AppType.semibold : AppType.medium,
              color: selected ? AppColors.accent : AppColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Rehberi yeniden açmak için bayrağı temizler.
Future<void> resetMapTour() => AppFlags().clear(AppFlags.seenMapTour);
