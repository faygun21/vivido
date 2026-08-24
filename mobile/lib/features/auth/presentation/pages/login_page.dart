import 'package:flutter/material.dart';

import '../../application/session_controller.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import 'verify_email_page.dart';

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
          (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Giriş yap')),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.lock_open,
                        color: Theme.of(context).colorScheme.primary,
                        size: 52,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Tekrar hoş geldin',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Profiline ve önemli konumlarına devam et.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Parola',
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                            onPressed:
                                () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
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
                              widget.controller.busy
                                  ? null
                                  : _openForgotPassword,
                          child: const Text('Şifremi unuttum'),
                        ),
                      ),
                      if (widget.controller.errorMessage case final error?) ...[
                        const SizedBox(height: 8),
                        _ErrorBox(message: error),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: widget.controller.busy ? null : _submit,
                        child:
                            widget.controller.busy
                                ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Giriş yap'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed:
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
                        child: const Text('Hesabın yok mu? Kayıt ol'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.onErrorContainer),
      ),
    );
  }
}
