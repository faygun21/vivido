import 'package:flutter/material.dart';

import '../../application/session_controller.dart';
import '../../domain/password_policy.dart';
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
          (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Şifremi unuttum')),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child:
                    _codeStep
                        ? _buildResetStep(context)
                        : _buildEmailStep(context),
              ),
            ),
          ),
    );
  }

  Widget _buildEmailStep(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_reset_outlined, size: 52, color: colors.primary),
          const SizedBox(height: 20),
          Text(
            'Sıfırlama kodu gönderelim',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Hesabının e-posta adresini gir; 6 haneli bir kod gönderelim.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            validator: _emailValidator,
          ),
          ..._banners(context),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.controller.busy ? null : _requestCode,
            child:
                widget.controller.busy
                    ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Sıfırlama kodu gönder'),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Yeni şifreni belirle',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${_emailController.text.trim()} adresine gelen kodu gir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 24),
          CodeField(controller: _codeController, label: 'Sıfırlama kodu'),
          const SizedBox(height: 14),
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
              prefixIcon: const Icon(Icons.key_outlined),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: validateStrongPassword,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordAgainController,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Yeni parola (tekrar)',
              prefixIcon: Icon(Icons.key_outlined),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Parolalar birbiriyle uyuşmuyor.';
              }
              return null;
            },
          ),
          ..._banners(context),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.controller.busy ? null : _submitNewPassword,
            child:
                widget.controller.busy
                    ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Şifreyi güncelle'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: widget.controller.busy ? null : _requestCode,
            child: const Text('Kodu tekrar gönder'),
          ),
        ],
      ),
    );
  }

  List<Widget> _banners(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final error = widget.controller.errorMessage;

    return [
      if (_info != null) ...[
        const SizedBox(height: 16),
        _box(_info!, colors.surfaceContainerHighest, colors.onSurfaceVariant),
      ],
      if (error != null) ...[
        const SizedBox(height: 16),
        _box(error, colors.errorContainer, colors.onErrorContainer),
      ],
    ];
  }

  Widget _box(String message, Color background, Color foreground) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: foreground, height: 1.35),
    ),
  );

  static String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Geçerli bir e-posta gir.';
    }
    return null;
  }
}
