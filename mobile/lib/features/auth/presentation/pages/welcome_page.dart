import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/session_controller.dart';
import '../widgets/auth_scaffold.dart';
import 'login_page.dart';
import 'register_page.dart';

/// Karşılama ekranı (R-2) — Giriş Yap · Kayıt Ol · Misafir olarak keşfet.
///
/// ⚠️ BİRİNCİL DÜĞME YANLIŞ RENKTEYDİ. "Giriş Yap" `#E27250`
/// (`--accent-secondary`) ile boyanıyordu; uygulamanın birincil eylem
/// rengi `#C0421D`. Kullanıcı uygulamaya bir turuncuyla giriyor, içeride
/// başka bir turuncu buluyordu.
///
/// ⚠️ MİSAFİR SEÇENEĞİ GÖRÜNMEZDİ. Soluk gri (`strokeColor`) bir
/// `TextButton`du ve altındaki açıklama ondan daha okunaklıydı. Misafir
/// akışı ürünün üç ana kapısından biri; bir dipnot gibi durmamalı.
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder:
              (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.xxl,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const BrandLockup(height: 58),
                        const Spacer(),

                        // İllüstrasyon ekranın YÜKSEKLİĞİNE oranlı: sabit
                        // 250 px, küçük telefonlarda düğmeleri ekran
                        // dışına itiyordu.
                        _FadeIn(
                          delay: Duration.zero,
                          child: Image.asset(
                            'assets/images/ev_resmi.png',
                            height: (constraints.maxHeight * 0.28).clamp(
                              150.0,
                              260.0,
                            ),
                            fit: BoxFit.contain,
                            semanticLabel: 'Ev ve yaşam alanı illüstrasyonu',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        _FadeIn(
                          delay: const Duration(milliseconds: 90),
                          child: Text(
                            'Yeni evini sadece konumuna göre değil, '
                            'yaşamına göre seç.',
                            textAlign: TextAlign.center,
                            style: AppType.display.copyWith(fontSize: 25),
                          ),
                        ),

                        if (controller.errorMessage case final error?) ...[
                          const SizedBox(height: AppSpacing.md),
                          AuthError(message: error),
                        ],

                        const Spacer(),
                        const SizedBox(height: AppSpacing.md),

                        _FadeIn(
                          delay: const Duration(milliseconds: 180),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton(
                                onPressed:
                                    () => _openAuth(context, register: false),
                                child: const Text('Giriş yap'),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              OutlinedButton(
                                onPressed:
                                    () => _openAuth(context, register: true),
                                child: const Text('Hesap oluştur'),
                              ),
                              const SizedBox(height: AppSpacing.md),

                              // Misafir kapısı: ayrı bir yüzey, kendi
                              // açıklamasıyla. Artık bir dipnot değil,
                              // üçüncü bir seçenek.
                              _GuestCard(onTap: controller.continueAsGuest),
                            ],
                          ),
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

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceSunken,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.explore_outlined,
                size: 18,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Misafir olarak keşfet',
                    style: AppType.sm.copyWith(fontWeight: AppType.semibold),
                  ),
                  Text(
                    'Haritayı ve konutların temel bilgilerini hesapsız gez.',
                    style: AppType.muted(AppType.micro).copyWith(
                      letterSpacing: 0,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Sırayla beliren giriş öğeleri.
///
/// Karşılama ekranı uygulamanın ilk yüzü; her şeyin aynı anda belirmesi
/// "sayfa yüklendi" der, sırayla belirmesi "hoş geldin" der.
class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.page,
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.easeOut,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
