import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/config/app_config.dart';
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

  static const Color primaryKiremit = Color(0xFFC0421D);
  static const Color backgroundColor = Color(0xFFF9F4ED);
  static const Color accentOrange = Color(0xFFE27250);
  static const Color inputFillColor = Color(0xFFECEAE6);
  static const Color strokeColor = Color(0xFFA79D93);

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
            backgroundColor: backgroundColor,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      // Logo
                      Center(
                        child: SvgPicture.asset(
                          'assets/images/vivido_logo.svg',
                          height: 70,
                          semanticsLabel: AppConfig.appName,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'hayalindeki eve giden yol',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF333333),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        child: const Divider(
                          color: strokeColor,
                          thickness: 0.8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Giriş Yap',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          hintText: 'E-posta adresi',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          filled: true,
                          fillColor: inputFillColor,
                          prefixIcon: Icon(
                            Icons.alternate_email,
                            color: strokeColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: strokeColor,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: strokeColor,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: accentOrange,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Şifre',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          filled: true,
                          fillColor: inputFillColor,
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: strokeColor,
                          ),
                          suffixIcon: IconButton(
                            onPressed:
                                () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: strokeColor,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: strokeColor,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: strokeColor,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: accentOrange,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator:
                            (value) =>
                                (value ?? '').length < 8
                                    ? 'Parola en az 8 karakter olmalı.'
                                    : null,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              widget.controller.busy
                                  ? null
                                  : _openForgotPassword,
                          child: const Text(
                            'Şifremi unuttum',
                            style: TextStyle(
                              color: primaryKiremit,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (widget.controller.errorMessage case final error?) ...[
                        const SizedBox(height: 8),
                        _ErrorBox(message: error),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentOrange,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: strokeColor,
                                width: 0.8,
                              ),
                            ),
                          ),
                          onPressed: widget.controller.busy ? null : _submit,
                          child:
                              widget.controller.busy
                                  ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text(
                                    'Giriş Yap',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Hesabın yok mu? ',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          GestureDetector(
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
                            child: const Text(
                              'Kayıt ol',
                              style: TextStyle(
                                color: primaryKiremit,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.red.shade900),
      ),
    );
  }
}
