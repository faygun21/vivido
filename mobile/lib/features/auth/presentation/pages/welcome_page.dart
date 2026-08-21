import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../application/session_controller.dart';
import 'auth_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.controller, super.key});

  final SessionController controller;

  void _openAuth(BuildContext context, {required bool register}) {
    controller.clearError();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AuthPage(controller: controller, initialRegister: register),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.home_work,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppConfig.appName,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary, const Color(0xFF0F766E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        size: 116,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Hayatına uyan evi bul.',
                      style: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.w800, height: 1.05),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Personanı seç, düzenli gittiğin yerleri haritada işaretle; '
                      'Vivido sana uygun yaşam alanlarını hazırlasın.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    if (controller.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _InlineError(message: controller.errorMessage!),
                    ],
                    const Spacer(),
                    FilledButton(
                      onPressed: () => _openAuth(context, register: false),
                      child: const Text('Giriş yap'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _openAuth(context, register: true),
                      child: const Text('Yeni hesap oluştur'),
                    ),
                    const SizedBox(height: 6),
                    // W0: kayıt olmadan haritayı gezme. Skor, persona ve
                    // anchor kilitli kalır; kullanıcı o işlemlere
                    // dokunduğunda giriş/kayıt ekranına yönlendirilir.
                    TextButton(
                      onPressed: controller.continueAsGuest,
                      child: const Text('Misafir olarak devam et'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Misafirken haritayı ve konutların temel bilgilerini '
                      'görebilirsin; kişiselleştirilmiş skor için hesap gerekir.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Geliştirme API’si: ${AppConfig.apiBaseUrl}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: colors.outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
    ),
  );
}
