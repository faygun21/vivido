import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/config/app_config.dart';
import '../../application/session_controller.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.controller, super.key});

  final SessionController controller;

  static const Color backgroundColor = Color(0xFFF9F4ED);
  static const Color accentOrange = Color(0xFFE27250);
  static const Color strokeColor = Color(0xFFA79D93);
  static const Color textPrimaryColor = Color(0xFF333333);

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

                        const SizedBox(height: 12),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          child: const Divider(
                            color: strokeColor,
                            thickness: 0.8,
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
                            color: textPrimaryColor,
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
                            onPressed:
                                () => _openAuth(context, register: false),
                            child: const Text(
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

                        const SizedBox(height: 12),

                        // 5. Kayıt Ol Butonu
                        SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: strokeColor,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _openAuth(context, register: true),
                            child: const Text(
                              'Kayıt Ol',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                color: textPrimaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: controller.continueAsGuest,
                          child: const Text(
                            'Misafir olarak devam et',
                            style: TextStyle(color: strokeColor),
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
      color: Colors.red.shade100,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.red.shade900),
    ),
  );
}
