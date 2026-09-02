import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/session_controller.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/code_field.dart';

/// E-posta doğrulama ekranı — K-09.
///
/// Buraya iki yoldan gelinir:
///   · kayıt 202 döndüğünde (RegisterPage yönlendirir)
///   · doğrulanmamış hesapla giriş denendiğinde (403 EMAIL_NOT_VERIFIED)
///
/// Kod doğrulanınca sunucu token DÖNER — kullanıcı ayrıca giriş yapmaz.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({
    required this.controller,
    required this.email,
    this.initialMessage,
    super.key,
  });

  final SessionController controller;
  final String email;
  final String? initialMessage;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  static const _cooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  String? _info;
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _info = widget.initialMessage;
    // Kod kayıt sırasında zaten gönderildi; sayaç oradan başlıyor ki
    // kullanıcı hemen "tekrar gönder"e basıp 429 yemesin.
    _startCooldown();
  }

  @override
  void dispose() {
    // Sayaç bırakılmazsa ölü bir ekrana setState denenir.
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft -= 1;
        if (_secondsLeft <= 0) timer.cancel();
      });
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    widget.controller.clearError();
    setState(() => _info = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await widget.controller.verifyEmail(
      email: widget.email,
      code: _codeController.text,
    );

    if (!mounted) return;
    if (success) {
      // Oturum açıldı; app.dart faza göre ana ekranı çiziyor. Bu sayfayı ve
      // altındaki kayıt sayfasını yığından atıyoruz.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _codeController.clear();
    }
  }

  Future<void> _resend() async {
    widget.controller.clearError();
    final message = await widget.controller.resendVerification(widget.email);
    if (!mounted) return;
    if (message != null) {
      setState(() => _info = message);
      _startCooldown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder:
          (context, _) => AuthScaffold(
            showLogo: false,
            title: 'E-postanı doğrula',
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
                    Icons.mark_email_read_outlined,
                    size: 30,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text.rich(
                TextSpan(
                  style: AppType.muted(AppType.sm).copyWith(height: 1.5),
                  children: [
                    // Adres KALIN: kullanıcının kontrol etmesi gereken tek
                    // bilgi bu — yanlış yazılmış bir adres, kodun neden
                    // gelmediğinin en sık sebebi.
                    const TextSpan(text: 'Kodu '),
                    TextSpan(
                      text: widget.email,
                      style: AppType.sm.copyWith(fontWeight: AppType.semibold),
                    ),
                    const TextSpan(
                      text:
                          ' adresine gönderdik. Gelmediyse spam klasörüne de bak.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Form(
                key: _formKey,
                child: CodeField(
                  controller: _codeController,
                  label: 'Doğrulama kodu',
                  onSubmitted: (_) => _submit(),
                ),
              ),
              if (_info case final info?) ...[
                const SizedBox(height: AppSpacing.sm),
                _InfoBanner(message: info),
              ],
              if (widget.controller.errorMessage case final error?) ...[
                const SizedBox(height: AppSpacing.sm),
                AuthError(message: error),
              ],
              const SizedBox(height: AppSpacing.md),
              AuthSubmitButton(
                label: 'Doğrula ve devam et',
                busy: widget.controller.busy,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton(
                onPressed:
                    widget.controller.busy || _secondsLeft > 0 ? null : _resend,
                child: Text(
                  _secondsLeft > 0
                      ? 'Kodu tekrar gönder ($_secondsLeft sn)'
                      : 'Kodu tekrar gönder',
                ),
              ),
            ],
          ),
    );
  }
}

/// Nötr bilgi şeridi — "kod gönderildi" gibi başarı bildirimleri.
///
/// Hata şeridinden AYRI bir renk ailesinde: ikisi aynı yerde çıkıyor ve
/// aynı gri kutuda gösterilirse kullanıcı "kod gönderildi" ile "kod
/// yanlış"ı ayırt edemiyordu.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.ok.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.ok.withValues(alpha: 0.22)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, size: 18, color: AppColors.ok),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: AppType.sm.copyWith(color: AppColors.ok, height: 1.4),
          ),
        ),
      ],
    ),
  );
}
