import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/session_controller.dart';
import '../widgets/auth_scaffold.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'verify_email_page.dart';

/// Giriş ekranı (R-6, R-7).
///
/// Görsel kararların tamamı temadan ve [AuthScaffold]'dan geliyor; bu
/// dosya yalnızca akışı taşıyor. Eskiden 358 satırın ~240'ı elle yazılmış
/// `InputDecoration` ve renk sabitiydi.
class LoginPage extends StatefulWidget {
  const LoginPage({required this.controller, super.key});

  final SessionController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    widget.controller.clearError();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await widget.controller.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;

    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (widget.controller.lastErrorCode == 'EMAIL_NOT_VERIFIED') {
      widget.controller.clearError();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => VerifyEmailPage(
                controller: widget.controller,
                email: _emailController.text.trim(),
              ),
        ),
      );
    }
  }

  void _openForgotPassword() {
    widget.controller.clearError();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ForgotPasswordPage(
              controller: widget.controller,
              initialEmail: _emailController.text.trim(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder:
          (context, _) => AuthScaffold(
            title: 'Tekrar hoş geldin',
            subtitle: 'Hesabına giriş yap ve kaldığın yerden devam et.',
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'E-posta adresi',
                        prefixIcon: Icon(Icons.alternate_email, size: 20),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          onPressed:
                              () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                          tooltip:
                              _obscurePassword
                                  ? 'Şifreyi göster'
                                  : 'Şifreyi gizle',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                      validator:
                          (value) =>
                              (value ?? '').length < 8
                                  ? 'Parola en az 8 karakter olmalı.'
                                  : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            widget.controller.busy ? null : _openForgotPassword,
                        child: const Text('Şifremi unuttum'),
                      ),
                    ),
                    if (widget.controller.errorMessage case final error?) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AuthError(message: error),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AuthSubmitButton(
                      label: 'Giriş yap',
                      busy: widget.controller.busy,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              AuthSwitchLink(
                question: 'Hesabın yok mu?',
                action: 'Kayıt ol',
                onTap:
                    widget.controller.busy
                        ? null
                        : () {
                          widget.controller.clearError();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => RegisterPage(
                                    controller: widget.controller,
                                  ),
                            ),
                          );
                        },
              ),
            ],
          ),
    );
  }

  static String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    return email.contains('@') && email.contains('.')
        ? null
        : 'Geçerli bir e-posta gir.';
  }
}
