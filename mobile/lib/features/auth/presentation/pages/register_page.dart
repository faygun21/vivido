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
  final _surnameController = TextEditingController();
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
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    widget.controller.clearError();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final fullName =
        '${_nameController.text.trim()} ${_surnameController.text.trim()}'
            .trim();

    final outcome = await widget.controller.register(
      email: _emailController.text,
      password: _passwordController.text,
      displayName: fullName,
    );
    if (!mounted || outcome == null) return;

    switch (outcome) {
      case RegisterVerificationRequired(:final email, :final message):
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder:
                (_) => VerifyEmailPage(
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
                      // Başlık
                      const Text(
                        'Aramıza Katılın',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Alt Slogan
                      const Text(
                        'Yaşamanıza en uygun evi bulmak\niçin kayıt oluşturun.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF555555),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Divider(
                          color: strokeColor,
                          thickness: 0.8,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Ad Alanı
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.givenName],
                        decoration: InputDecoration(
                          hintText: 'Ad',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          filled: true,
                          fillColor: inputFillColor,
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
                                (value ?? '').trim().isEmpty
                                    ? 'Ad alanı boş bırakılamaz.'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      // Soyad Alanı
                      TextFormField(
                        controller: _surnameController,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.familyName],
                        decoration: InputDecoration(
                          hintText: 'Soyad',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          filled: true,
                          fillColor: inputFillColor,
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
                                (value ?? '').trim().isEmpty
                                    ? 'Soyad alanı boş bırakılamaz.'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      // E-posta Alanı
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
                          suffixIcon: Icon(
                            Icons.email_outlined,
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

                      // Şifre Alanı
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'Şifre',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          filled: true,
                          fillColor: inputFillColor,
                          suffixIcon: IconButton(
                            onPressed:
                                () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.lock_outline
                                  : Icons.lock_open_outlined,
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

                      if (widget.controller.errorMessage case final error?) ...[
                        const SizedBox(height: 12),
                        _ErrorBox(message: error),
                      ],

                      const SizedBox(height: 24),

                      // Kayıt Ol Butonu
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentOrange,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                                    'Kayıt Ol',
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

                      // Tıklanabilir Sözleşme Metni
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            const Text(
                              'Kayıt olarak ',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Color(0xFF555555),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const TermsAndPrivacyPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Kullanım Koşulları ve Gizlilik Sözleşmesi\'ni',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: primaryKiremit,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const Text(
                              ' kabul etmiş olursunuz.',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Color(0xFF555555),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Giriş Yap Yönlendirmesi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Zaten bir hesabınız var mı? ',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
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
                                              (_) => LoginPage(
                                                controller: widget.controller,
                                              ),
                                        ),
                                      );
                                    },
                            child: const Text(
                              'Giriş Yap',
                              style: TextStyle(
                                color: primaryKiremit,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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

// Sözleşme Detay Sayfası
class TermsAndPrivacyPage extends StatelessWidget {
  const TermsAndPrivacyPage({super.key});

  static const Color backgroundColor = Color(0xFFF9F4ED);
  static const Color primaryKiremit = Color(0xFFC0421D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryKiremit),
        title: const Text(
          'Kullanım Koşulları ve Gizlilik',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.black,
            fontSize: 18,
          ),
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kullanım Koşulları',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryKiremit,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bu uygulama (Vivido) üzerinden sunulan hizmetleri kullanarak aşağıdaki koşulları kabul etmiş sayılırsınız. Uygulama içerisindeki harita verileri ve konut bilgileri bilgilendirme amaçlıdır.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Gizlilik Sözleşmesi',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryKiremit,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Kişisel verileriniz (e-posta, ad, soyad vb.) güvenli bir şekilde saklanır ve üçüncü şahıslarla paylaşılmaz. Kayıt olarak veri güvenliği politikamızı onaylamış olursunuz.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
