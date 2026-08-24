import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Oturum geri yüklenirken gösterilen açılış ekranı.
///
/// Yönlendirme yapmaz; hangi sayfanın açılacağına [SessionController] kullanan
/// uygulama kabuğu karar verir. Böylece kayıtlı oturum ve misafir akışı
/// splash ekranı tarafından atlanmaz.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  static const Color backgroundColor = Color(0xFFF9F4ED);
  static const Color textPrimaryColor = Color(0xFF333333);
  static const Color strokeColor = Color(0xFFA79D93);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/images/vivido_logo.svg', width: 150),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 60),
              child: const Divider(color: strokeColor, thickness: 0.8),
            ),
            const SizedBox(height: 16),
            const Text(
              'hayalinizdeki eve giden yol',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textPrimaryColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
