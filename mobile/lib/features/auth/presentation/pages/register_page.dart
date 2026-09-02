import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/session_controller.dart';
import '../../domain/password_policy.dart';
import '../widgets/auth_scaffold.dart';
import 'login_page.dart';
import 'terms_and_privacy_page.dart';
import 'verify_email_page.dart';

/// Kayıt ekranı (R-3, R-4, R-5, R-59).
///
/// ⚠️ `TermsAndPrivacyPage` BURADA TANIMLIYDI ve `terms_and_privacy_page.dart`
/// içinde ikinci bir kopyası vardı; ikinci dosya hiç kullanılmıyordu ama
/// ikisi de derleniyordu. Sayfa artık tek yerde.
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
          (context, _) => AuthScaffold(
            title: 'Aramıza katıl',
            subtitle: 'Sana en uygun evi bulabilmemiz için önce bir hesap.',
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ad ve soyad YAN YANA: alt alta iki kısa alan,
                    // formu gereksiz uzatıyor ve kaydırma gerektiriyordu.
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.givenName],
                            decoration: const InputDecoration(labelText: 'Ad'),
                            validator:
                                (value) =>
                                    (value ?? '').trim().isEmpty
                                        ? 'Zorunlu'
                                        : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: TextFormField(
                            controller: _surnameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.familyName],
                            decoration: const InputDecoration(
                              labelText: 'Soyad',
                            ),
                            validator:
                                (value) =>
                                    (value ?? '').trim().isEmpty
                                        ? 'Zorunlu'
                                        : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
                      key: const ValueKey('register-password'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        errorMaxLines: 3,
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
                      validator: validateStrongPassword,
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // ⚠️ Kural listesi CANLI. Eskiden tek satırlık bir
                    // `helperText`ti (`strongPasswordRequirements`) ve
                    // kullanıcı hangi kuralı sağladığını ancak formu
                    // gönderip hata alınca öğreniyordu.
                    _PasswordChecklist(value: _passwordController.text),

                    if (widget.controller.errorMessage case final error?) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AuthError(message: error),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AuthSubmitButton(
                      label: 'Hesap oluştur',
                      busy: widget.controller.busy,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _TermsNotice(
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TermsAndPrivacyPage(),
                      ),
                    ),
              ),
              AuthSwitchLink(
                question: 'Zaten hesabın var mı?',
                action: 'Giriş yap',
                onTap:
                    widget.controller.busy
                        ? null
                        : () {
                          widget.controller.clearError();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) =>
                                      LoginPage(controller: widget.controller),
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

/// Parola kurallarının canlı kontrol listesi.
///
/// Kurallar `password_policy.dart` ile aynı — orası doğrulamayı, burası
/// göstermeyi yapıyor. İkisi ayrışırsa kullanıcı yeşil tik görüp yine de
/// hata alır; bu yüzden kural metinleri tek bir yerden geliyor.
class _PasswordChecklist extends StatelessWidget {
  const _PasswordChecklist({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final rules = <(String, bool)>[
      ('8+ karakter', value.length >= 8),
      ('Büyük harf', value.contains(RegExp('[A-ZÇĞİÖŞÜ]'))),
      ('Küçük harf', value.contains(RegExp('[a-zçğıöşü]'))),
      ('Rakam', value.contains(RegExp('[0-9]'))),
      ('Özel karakter', value.contains(RegExp('[^A-Za-zÇĞİÖŞÜçğıöşü0-9]'))),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 5,
      children: [
        for (final (label, met) in rules)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:
                  met
                      ? AppColors.ok.withValues(alpha: 0.10)
                      : AppColors.inputBg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  met ? Icons.check_rounded : Icons.circle_outlined,
                  size: 12,
                  color: met ? AppColors.ok : AppColors.inkMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppType.micro.copyWith(
                    letterSpacing: 0,
                    color: met ? AppColors.ok : AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TermsNotice extends StatelessWidget {
  const _TermsNotice({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: AppType.muted(AppType.micro).copyWith(letterSpacing: 0, height: 1.5),
      children: [
        const TextSpan(text: 'Kayıt olarak '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: onTap,
            child: Text(
              'Kullanım Koşulları ve Gizlilik Sözleşmesi\'ni',
              style: AppType.micro.copyWith(
                letterSpacing: 0,
                color: AppColors.accent,
                fontWeight: AppType.semibold,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.accent,
              ),
            ),
          ),
        ),
        const TextSpan(text: ' kabul etmiş olursun.'),
      ],
    ),
    textAlign: TextAlign.center,
  );
}
