import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';

/// Giriş akışının ortak kabuğu — logo, başlık, gövde.
///
/// ⚠️ DÖRT EKRAN, DÖRT AYRI PALET
///
/// `welcome_page`, `login_page`, `register_page`, `splash_page`,
/// `verify_email_page` ve `forgot_password_page`'in HER BİRİ kendi renk
/// sabitlerini tanımlıyordu:
///
/// ```dart
/// static const Color backgroundColor = Color(0xFFF9F4ED);
/// static const Color accentOrange   = Color(0xFFE27250);
/// static const Color strokeColor    = Color(0xFFA79D93);
/// ```
///
/// Renkler tema ile aynıydı ama tema onları YÖNETMİYORDU — palet
/// değiştiğinde altı dosya elle güncellenecekti. Daha kötüsü: birincil
/// düğme `accentOrange` (`--accent-secondary`) ile boyanıyordu, oysa
/// uygulamanın birincil eylem rengi `--accent` (`#C0421D`). Giriş akışı,
/// uygulamanın geri kalanından FARKLI bir turuncu kullanıyordu.
///
/// Ayrıca her ekran kendi `TextFormField` süslemesini (16 px yarıçap,
/// üç ayrı `OutlineInputBorder`) elle yazıyordu; tema
/// `inputDecorationTheme` zaten aynı işi yapıyor.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.children,
    this.title,
    this.subtitle,
    this.showLogo = true,
    this.showBack = true,
    super.key,
  });

  final List<Widget> children;
  final String? title;
  final String? subtitle;
  final bool showLogo;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar:
          canPop
              ? AppBar(
                backgroundColor: Colors.transparent,
                leading: const BackButton(),
                toolbarHeight: 48,
              )
              : null,
      body: Stack(
        children: [
          // ⚠️ EKRAN DÜMDÜZ BİR KREM YÜZEYDİ. Web'de giriş ekranının sol
          // yarısı marka videosu; mobilde öyle bir alan yok ama ekranın
          // tamamen boş kalması da gerekmiyor. Logodaki güneş motifinden
          // gelen çok yumuşak bir ışık, formu bir ZEMİNE oturtuyor.
          const Positioned.fill(child: _BrandWash()),

          SafeArea(
            top: !canPop,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showLogo) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const BrandLockup(),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Form BEYAZ BİR KARTIN üstünde: krem zeminde yüzen
                  // alanlar ile arka plan arasındaki kontrast düşüktü ve
                  // ekran "yarım bitmiş" duruyordu. Kart, formun nerede
                  // başlayıp bittiğini de söylüyor.
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (title != null) ...[
                          Text(
                            title!,
                            textAlign: TextAlign.center,
                            style: AppType.h1,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              textAlign: TextAlign.center,
                              style: AppType.muted(AppType.sm),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        ...children,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sağ üstten inen çok yumuşak sıcak ışık.
///
/// Opaklık bilinçli olarak düşük — fark edilmesi değil, yüzeyin ÖLÜ
/// görünmemesi amaç. Web'de aynı fikir `.login-left` gradyanında var.
class _BrandWash extends StatelessWidget {
  const _BrandWash();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        // Logodaki güneşin durduğu yer.
        center: const Alignment(0.75, -0.9),
        radius: 1.1,
        colors: [
          AppColors.accentSecondary.withValues(alpha: 0.16),
          AppColors.accentSecondary.withValues(alpha: 0.04),
          AppColors.bg.withValues(alpha: 0),
        ],
        stops: const [0, 0.45, 1],
      ),
    ),
  );
}

/// Marka kilidi: **işaret → ad → slogan → ayraç**.
///
/// ⚠️ MARKA ADI HİÇBİR YERDE YAZMIYORDU
///
/// Mobil yalnızca İŞARETİ gösteriyordu — uygulamanın ilk yüzeyinde
/// "Vivido" kelimesi hiç geçmiyordu. Web bunu `.login-wordmark` ile
/// çözmüş durumda (`LoginPage.tsx`): işaretin altında `--fs-display`
/// boyutunda marka adı.
///
/// Ölçek bilinçli: marka adı `display`, sayfa başlığı (`Giriş yap`) `h1`.
/// İkisi aynı boyda olsaydı hangisinin KİMLİK hangisinin GÖREV olduğu
/// kaybolurdu.
///
/// Logonun kendisi `semanticsLabel` TAŞIMIYOR: markayı bitişiğindeki
/// görünür metin adlandırıyor, ikisi de taşısaydı ekran okuyucu
/// "Vivido logosu, Vivido" diye iki kez okurdu.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    this.height = 64,
    this.tagline = 'hayalindeki eve giden yol',
    this.showWordmark = true,
    super.key,
  });

  final double height;

  /// Slogan. `null` ise yazılmaz.
  final String? tagline;

  /// Marka adı. Yalnızca logo istendiğinde kapatılır.
  final bool showWordmark;

  @override
  Widget build(BuildContext context) => Semantics(
    label: showWordmark ? null : AppConfig.appName,
    child: Column(
      children: [
        SvgPicture.asset(
          'assets/images/vivido_logo.svg',
          height: height,
          excludeFromSemantics: true,
        ),
        if (showWordmark) ...[
          const SizedBox(height: 2),
          Text(
            AppConfig.appName,
            textAlign: TextAlign.center,
            style: AppType.display.copyWith(
              fontSize: height * 0.52,
              height: 1.05,
            ),
          ),
        ],
        if (tagline != null) ...[
          const SizedBox(height: 2),
          Text(
            tagline!,
            textAlign: TextAlign.center,
            style: AppType.sm.copyWith(
              color: AppColors.inkMuted,
              fontWeight: AppType.medium,
              letterSpacing: 0.3,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        // Ayraç logonun genişliğine oranlı: sabit bir kenar boşluğu dar
        // telefonda logoyu aşıyor, geniş telefonda kısa kalıyordu.
        FractionallySizedBox(
          widthFactor: 0.5,
          child: Divider(color: AppColors.lineSoft, thickness: 1, height: 1),
        ),
      ],
    ),
  );
}

/// Form hatası şeridi.
///
/// Altı ekranda `Colors.red.shade100` + `Colors.red.shade900` ile
/// yazılıydı — Material'ın ham kırmızısı, paletin dışında ve krem zeminde
/// çiğ duruyordu. Artık `--bad`.
class AuthError extends StatelessWidget {
  const AuthError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.base,
    curve: AppMotion.easeOut,
    builder:
        (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -6 * (1 - value)),
            child: child,
          ),
        ),
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bad.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.bad.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.bad),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppType.sm.copyWith(color: AppColors.bad, height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Yükleniyor durumundaki birincil düğme.
///
/// Her ekranda `SizedBox(height: 54, child: ElevatedButton(...))` +
/// koşullu `CircularProgressIndicator` tekrar ediyordu; boyları da 50/54
/// arasında oynuyordu.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.onPressed,
    required this.busy,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: AnimatedSwitcher(
      duration: AppMotion.fast,
      child:
          busy
              ? const SizedBox.square(
                key: ValueKey('busy'),
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : Text(label, key: const ValueKey('label')),
    ),
  );
}

/// "Hesabın yok mu? Kayıt ol" gibi alt bağlantı satırı.
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    required this.question,
    required this.action,
    required this.onTap,
    super.key,
  });

  final String question;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(question, style: AppType.muted(AppType.sm)),
      TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size(0, 40),
        ),
        child: Text(action),
      ),
    ],
  );
}
