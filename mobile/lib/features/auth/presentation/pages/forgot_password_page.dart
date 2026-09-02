import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/session_controller.dart';
import '../../domain/password_policy.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/code_field.dart';

/// Şifre sıfırlama — K-09.
///
/// Tek sayfa, iki adım:
///   1. e-posta gir  →  POST /auth/forgot-password  →  koda geç
///   2. kod + yeni şifre  →  POST /auth/reset-password  →  girişe dön
///
/// ⚠️ 1. adım hesap var olmasa bile başarılı görünür. Sunucu bilerek öyle
/// davranıyor — farklı yanıt vermek, bu formu "hangi e-postalar kayıtlı?"
/// sorusunu cevaplayan bir araca çevirirdi.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    required this.controller,
    this.initialEmail = '',
    super.key,
  });

  final SessionController controller;
  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordAgainController = TextEditingController();

  bool _codeStep = false;
  bool _obscure = true;
  String? _info;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _passwordAgainController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    FocusScope.of(context).unfocus();
    widget.controller.clearError();
    setState(() => _info = null);
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    final message = await widget.controller.forgotPassword(
      _emailController.text,
    );
    if (!mounted || message == null) return;

    setState(() {
      _info = message;
      _codeStep = true;
    });
  }

  Future<void> _submitNewPassword() async {
    FocusScope.of(context).unfocus();
    widget.controller.clearError();
    setState(() => _info = null);
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;

    final message = await widget.controller.resetPassword(
      email: _emailController.text,
      code: _codeController.text,
      newPassword: _passwordController.text,
    );
    if (!mounted) return;

    if (message == null) {
      _codeController.clear();
      return;
    }

    // ⚠️ Messenger'ı pop'tan ÖNCE al: pop sonrası bu sayfa ağaçtan
    // düşüyor ve `ScaffoldMessenger.of(context)` "deactivated widget"
    // hatası veriyor.
    final messenger = ScaffoldMessenger.of(context);

    // Sunucu sıfırlamada TÜM refresh token'ları iptal ediyor; otomatik
    // oturum açmak yerine giriş ekranına dönmek bu davranışla tutarlı.
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder:
          (context, _) => AuthScaffold(
            showLogo: false,
            title: _codeStep ? 'Yeni şifreni belirle' : 'Şifreni sıfırla',
            subtitle:
                _codeStep
                    ? '${_emailController.text.trim()} adresine gelen kodu gir.'
                    : 'Hesabının e-posta adresini gir; 6 haneli bir kod '
                        'gönderelim.',
            children: [
              // İki adım aynı yeri paylaşıyor. Adımın hangisi olduğu
              // BAŞLIKTAN okunuyor; içerik çapraz geçiyor.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: _codeStep ? _buildResetStep() : _buildEmailStep(),
              ),
            ],
          ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_reset_outlined,
                size: 30,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.alternate_email, size: 20),
            ),
            validator: _emailValidator,
          ),
          ..._banners(),
          const SizedBox(height: AppSpacing.md),
          AuthSubmitButton(
            label: 'Sıfırlama kodu gönder',
            busy: widget.controller.busy,
            onPressed: _requestCode,
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CodeField(controller: _codeController, label: 'Sıfırlama kodu'),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: const ValueKey('reset-password'),
            controller: _passwordController,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Yeni parola',
              helperText: strongPasswordRequirements,
              helperMaxLines: 2,
              errorMaxLines: 3,
              prefixIcon: const Icon(Icons.key_outlined, size: 20),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              ),
            ),
            validator: validateStrongPassword,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _passwordAgainController,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Yeni parola (tekrar)',
              prefixIcon: Icon(Icons.key_outlined, size: 20),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Parolalar birbiriyle uyuşmuyor.';
              }
              return null;
            },
          ),
          ..._banners(),
          const SizedBox(height: AppSpacing.md),
          AuthSubmitButton(
            label: 'Şifreyi güncelle',
            busy: widget.controller.busy,
            onPressed: _submitNewPassword,
          ),
          TextButton(
            onPressed: widget.controller.busy ? null : _requestCode,
            child: const Text('Kodu tekrar gönder'),
          ),
        ],
      ),
    );
  }

  /// Bilgi ve hata şeritleri.
  ///
  /// Eskiden ikisi de ham `ColorScheme` kutularıydı (gri / kırmızı) ve
  /// "kod gönderildi" ile "kod yanlış" aynı yerde, birbirine çok benzer
  /// görünüyordu. Bilgi artık başarı yeşili, hata `--bad`.
  List<Widget> _banners() {
    return [
      if (_info case final info?) ...[
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.ok.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.ok.withValues(alpha: 0.22)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 18,
                color: AppColors.ok,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  info,
                  style: AppType.sm.copyWith(
                    color: AppColors.ok,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      if (widget.controller.errorMessage case final message?) ...[
        const SizedBox(height: AppSpacing.sm),
        AuthError(message: message),
      ],
    ];
  }

  static String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Geçerli bir e-posta gir.';
    }
    return null;
  }
}
