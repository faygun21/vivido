import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_store.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/auth/presentation/pages/welcome_page.dart';
import '../features/home/presentation/pages/guest_home_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/onboarding/presentation/pages/onboarding_page.dart';

class VividoApp extends StatefulWidget {
  const VividoApp({this.controller, super.key});

  final SessionController? controller;

  @override
  State<VividoApp> createState() => _VividoAppState();
}

class _VividoAppState extends State<VividoApp> {
  late final SessionController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? _createController();
    unawaited(_controller.bootstrap());
  }

  SessionController _createController() {
    final client = ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      tokenStore: SecureTokenStore(),
    );
    return SessionController(
      client: client,
      repository: VividoRepository(client),
    );
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AnimatedBuilder(
        animation: _controller,
        builder:
            (context, _) => switch (_controller.phase) {
              SessionPhase.booting => const SplashPage(),
              SessionPhase.guest => WelcomePage(controller: _controller),
              // Misafir gezintisi (W0): harita açık, skor/persona/anchor kilitli.
              SessionPhase.browsing => GuestHomePage(controller: _controller),
              SessionPhase.onboarding => OnboardingPage(
                controller: _controller,
              ),
              SessionPhase.authenticated => HomePage(controller: _controller),
            },
      ),
    );
  }
}
