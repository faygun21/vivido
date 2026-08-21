import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Oturum geri yüklenirken gösterilen açılış ekranı.
///
/// Yönlendirme yapmaz; hangi sayfanın açılacağına [SessionController] kullanan
/// uygulama kabuğu karar verir. Böylece kayıtlı oturum ve misafir akışı
/// splash ekranı tarafından atlanmaz.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/images/vivido_logo.svg', width: 150),
            const SizedBox(height: 24),
            const Text(
              'hayalinizdeki eve giden yol',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
