import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../application/session_controller.dart';
import 'login_page.dart';
import 'verify_email_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({required this.controller, super.key});

  final SessionController controller;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordAgainController = TextEditingController();
  bool _obscurePassword = true;

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

    final outcome = await widget.controller.register(
      email: _emailController.text,
      password: _passwordController.text,
      displayName: _nameController.text,
    );
    if (!mounted || outcome == null) return;

    switch (outcome) {
      case RegisterVerificationRequired(:final email, :final message):
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VerifyEmailPage(
              controller: widget.controller,
              email: email,
              initialMessage: message,
            ),
          ),
        );
      case RegisterAuthenticated():
        Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Kayıt ol')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.person_add_alt_1,
                    color: Theme.of(context).colorScheme.primary,
                    size: 52,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Hesabını oluştur',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kısa profilini hazırlayıp haritaya geçeceğiz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
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
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
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
                    validator: (value) => (value ?? '').length < 8
                        ? 'Parola en az 8 karakter olmalı.'
                        : null,
                  ),
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
                    validator: (value) => value == _passwordController.text
                        ? null
                        : 'Parolalar birbiriyle uyuşmuyor.',
                  ),
                  if (widget.controller.errorMessage case final error?) ...[
                    const SizedBox(height: 16),
                    _ErrorBox(message: error),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: widget.controller.busy ? null : _submit,
                    child: widget.controller.busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kayıt ol ve ilerle'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: widget.controller.busy
                        ? null
                        : () {
                            widget.controller.clearError();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    LoginPage(controller: widget.controller),
                              ),
                            );
                          },
                    child: const Text('Zaten hesabın var mı? Giriş yap'),
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
