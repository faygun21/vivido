import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../widgets/auth_scaffold.dart';

/// Oturum geri yüklenirken gösterilen açılış ekranı (R-1).
///
/// Yönlendirme yapmaz; hangi sayfanın açılacağına [SessionController]
/// kullanan uygulama kabuğu karar verir. Böylece kayıtlı oturum ve misafir
/// akışı splash ekranı tarafından atlanmaz.
///
/// ⚠️ Marka kilidi artık ORTAK bileşen ([BrandLockup]) — logo yüksekliği
/// (150 px) ve ayraç genişliği (60 px kenar) burada elle yazılıydı ve
/// giriş ekranındakiyle (70 px logo, 24 px kenar) tutmuyordu: uygulama
/// açılışta bir marka, giriş ekranında başka bir marka gösteriyordu.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Marka BELİREREK geliyor. Anlık görünen bir logo, uygulamanın
              // "donmuş" mu yoksa "yükleniyor" mu olduğunu söylemiyor.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AppMotion.page,
                curve: AppMotion.easeOut,
                builder:
                    (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: 0.94 + 0.06 * value,
                        child: child,
                      ),
                    ),
                child: const BrandLockup(height: 84),
              ),
              const SizedBox(height: AppSpacing.xxl),
              // İnce, sonsuz bir çubuk: ortadaki dönen çark ekranın
              // dengesini bozuyor ve markanın dikkatini çalıyordu.
              SizedBox(
                width: 96,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: const LinearProgressIndicator(minHeight: 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
