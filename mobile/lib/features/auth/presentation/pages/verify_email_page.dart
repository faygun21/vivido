import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/session_controller.dart';
import '../widgets/code_field.dart';

/// E-posta doğrulama ekranı — K-09.
///
/// Buraya iki yoldan gelinir:
///   · kayıt 202 döndüğünde (AuthPage yönlendirir)
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
    // Sayaç bırakılmazsa React'teki gibi ölü bir ekrana setState denenir.
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
      // Oturum açıldı; app.dart faza göre ana ekranı çiziyor.
      // Bu sayfayı ve altındaki kayıt sayfasını yığından atıyoruz.
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
    final colors = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('E-postanı doğrula')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 52,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Kodu gir',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.email} adresine 6 haneli bir kod gönderdik. '
                    'Gelmediyse spam klasörüne de bak.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                  CodeField(
                    controller: _codeController,
                    label: 'Doğrulama kodu',
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_info != null) ...[
                    const SizedBox(height: 16),
                    _Banner(message: _info!, tone: _BannerTone.info),
                  ],
                  if (widget.controller.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _Banner(
                      message: widget.controller.errorMessage!,
                      tone: _BannerTone.error,
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
                        : const Text('Doğrula ve devam et'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: widget.controller.busy || _secondsLeft > 0
                        ? null
                        : _resend,
                    child: Text(
                      _secondsLeft > 0
                          ? 'Kodu tekrar gönder ($_secondsLeft sn)'
                          : 'Kodu tekrar gönder',
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

enum _BannerTone { info, error }

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.tone});

  final String message;
  final _BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isError = tone == _BannerTone.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? colors.errorContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isError ? colors.onErrorContainer : colors.onSurfaceVariant,
          fontWeight: isError ? FontWeight.w600 : FontWeight.w500,
          height: 1.35,
        ),
      ),
    );
  }
}
