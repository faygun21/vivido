import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../application/session_controller.dart';
import 'forgot_password_page.dart';
import 'verify_email_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.controller,
    this.initialRegister = false,
    super.key,
  });

  final SessionController controller;
  final bool initialRegister;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordAgainController = TextEditingController();
  bool _register = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _register = widget.initialRegister;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordAgainController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    widget.controller.clearError();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_register) {
      await _submitRegister();
      return;
    }

    final success = await widget.controller.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      return;
    }

    // Şifre doğru, sadece doğrulama eksik (403). Kullanıcıyı hata mesajıyla
    // baş başa bırakmak yerine akışın devamına taşıyoruz (K-09).
    if (widget.controller.lastErrorCode == 'EMAIL_NOT_VERIFIED') {
      widget.controller.clearError();
      await _openVerification(email: _emailController.text.trim());
    }
  }

  Future<void> _submitRegister() async {
    final outcome = await widget.controller.register(
      email: _emailController.text,
      password: _passwordController.text,
      displayName: _nameController.text,
    );

    if (!mounted || outcome == null) return;

    switch (outcome) {
      case RegisterVerificationRequired(:final email, :final message):
        await _openVerification(email: email, message: message);
      case RegisterAuthenticated():
        // Doğrulama kapalı (Auth:RequireEmailVerification=false) —
        // oturum açıldı, kabuk faza göre ana ekrana geçiyor.
        Navigator.of(context).pop();
    }
  }

  Future<void> _openVerification({required String email, String? message}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VerifyEmailPage(
          controller: widget.controller,
          email: email,
          initialMessage: message,
        ),
      ),
    );
  }

  void _openForgotPassword() {
    widget.controller.clearError();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordPage(
          controller: widget.controller,
          // Yazdığı e-postayı taşıyoruz — ikinci kez yazdırmak,
          // şifresini unutmuş birine yapılacak son şey.
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
  }

  void _toggleMode() {
    widget.controller.clearError();
    setState(() => _register = !_register);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _register ? Icons.person_add_alt_1 : Icons.lock_open,
                    color: Theme.of(context).colorScheme.primary,
                    size: 52,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _register ? 'Hesabını oluştur' : 'Tekrar hoş geldin',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _register
                        ? 'Kısa profilini hazırlayıp haritaya geçeceğiz.'
                        : 'Profiline ve önemli konumlarına devam et.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_register) ...[
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Ad (isteğe bağlı)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (!email.contains('@') || !email.contains('.')) {
                        return 'Geçerli bir e-posta gir.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    // Kayıtta altta bir alan daha var; "bitti" yerine
                    // "sonraki" göstermek klavyeyi kapatmadan devam ettirir.
                    textInputAction: _register
                        ? TextInputAction.next
                        : TextInputAction.done,
                    autofillHints: [
                      _register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    onFieldSubmitted: (_) {
                      if (!_register) _submit();
                    },
                    decoration: InputDecoration(
                      labelText: 'Parola',
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').length < 8) {
                        return 'Parola en az 8 karakter olmalı.';
                      }
                      return null;
                    },
                  ),
                  if (_register) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordAgainController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Parola (tekrar)',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Parolalar birbiriyle uyuşmuyor.';
                        }
                        return null;
                      },
                    ),
                  ] else
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: widget.controller.busy
                            ? null
                            : _openForgotPassword,
                        child: const Text('Şifremi unuttum'),
                      ),
                    ),
                  if (widget.controller.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      widget.controller.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: widget.controller.busy ? null : _submit,
                    child: widget.controller.busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_register ? 'Kayıt ol' : 'Giriş yap'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: widget.controller.busy ? null : _toggleMode,
                    child: Text(
                      _register
                          ? 'Zaten hesabın var mı? Giriş yap'
                          : 'Hesabın yok mu? Kayıt ol',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
