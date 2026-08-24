import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/config/app_config.dart';
import '../../application/session_controller.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.controller, super.key});

  final SessionController controller;

  void _openAuth(BuildContext context, {required bool register}) {
    controller.clearError();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) =>
                register
                    ? RegisterPage(controller: controller)
                    : LoginPage(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    // Tasarımdaki renkler
    const Color primaryColor = Color(0xFFC06B3E);
    const Color backgroundColor = Color(0xFFF9F5F0);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder:
              (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),

                        // 1. SVG Logo
                        Center(
                          child: SvgPicture.asset(
                            'assets/images/vivido_logo.svg',
                            height: 70,
                            semanticsLabel: AppConfig.appName,
                          ),
                        ),

                        const Spacer(),

                        // 2. İllüstrasyon Resmi
                        Image.asset(
                          'assets/images/ev_resmi.png',
                          height: 250,
                          fit: BoxFit.contain,
                          semanticLabel: 'Ev ve yaşam alanı illüstrasyonu',
                        ),

                        const SizedBox(height: 32),

                        // 3. Slogan Metni
                        const Text(
                          'Yeni evini sadece\nkonumuna göre değil,\nyaşamına göre seç.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                            height: 1.3,
                          ),
                        ),

                        const SizedBox(height: 24),

                        if (controller.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          _InlineError(message: controller.errorMessage!),
                        ],

                        const Spacer(),

                        // 4. Giriş Yap Butonu
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed:
                                () => _openAuth(context, register: false),
                            child: const Text(
                              'Giriş Yap',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 5. Kayıt Ol Butonu
                        SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFE5E5E5),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _openAuth(context, register: true),
                            child: const Text(
                              'Kayıt Ol',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                color: Color(0xFF555555),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: controller.continueAsGuest,
                          child: const Text(
                            'Misafir olarak devam et',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        Text(
                          'Misafirken haritayı ve konutların temel bilgilerini görebilirsin.',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),

                        //Api'yi gösterme kısmı geliştriciler için eklendi, yorum satırını kaldırarak aktif hale getirebilirsiniz.
                        //Text(
                        //  'API: ${AppConfig.apiBaseUrl}',
                        //  textAlign: TextAlign.center,
                        //  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.outline),
                        //),
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
