import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';

/// Vivido marka ikonu — `web/public/*.svg`'nin mobil kopyaları.
///
/// ⚠️ NEDEN MATERIAL İKONU DEĞİL
///
/// Persona seçimi, POI kategorileri ve favori işareti mobilde jenerik
/// Material glyph'leriyle çiziliyordu (`Icons.school_outlined`,
/// `Icons.place_outlined`, `Icons.laptop_mac_outlined`), web ise kendi
/// çizilmiş ikonlarını kullanıyordu. Aynı persona iki üründe iki farklı
/// simge alıyordu ve mobil tarafı "hazır şablon" gibi duruyordu.
///
/// SVG'ler siyah dolgulu; renk `colorFilter` ile veriliyor.
class BrandIcon extends StatelessWidget {
  const BrandIcon(
    this.asset, {
    this.size = 20,
    this.color,
    this.semanticLabel,
    super.key,
  });

  /// `assets/icons/` altındaki dosya adı — uzantısız değil, tam ad
  /// (`'kep.svg'`). Yol burada tamamlanıyor ki çağıran her yerde
  /// `assets/icons/` tekrar yazılmasın.
  final String asset;

  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$asset',
    width: size,
    height: size,
    semanticsLabel: semanticLabel,
    colorFilter:
        color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
  );
}

/// Persona → marka görseli. `web/src/shared/persona/personaVisuals.ts`
/// ile birebir aynı eşleme.
///
/// Bilinmeyen bir persona kodu için jenerik bir ikon döner — `null` DEĞİL.
/// Veritabanına yeni bir persona eklenirse arayüz kırık bir görsel yerine
/// nötr bir ikon gösterir; ekran çalışmaya devam eder.
({String main, List<String> sub}) personaVisual(String? code) =>
    switch (code) {
      'student' => (
        main: 'kep.svg',
        sub: ['bus.svg', 'school.svg', 'cafe.svg'],
      ),
      'remote_worker' => (
        main: 'pc.svg',
        sub: ['cafe.svg', 'sport_kahve.svg', 'park.svg'],
      ),
      'family_kids' => (
        main: 'family.svg',
        sub: ['school.svg', 'avm.svg', 'park.svg'],
      ),
      'elderly' => (
        main: 'glasses.svg',
        sub: ['hastane.svg', 'avm.svg', 'park.svg'],
      ),
      _ => (main: 'poi_generic_white.svg', sub: <String>[]),
    };

/// Persona ikonunu yuvarlak bir zeminde gösterir — onboarding kartı,
/// profil başlığı ve profil editörü aynı görseli paylaşır.
class PersonaAvatar extends StatelessWidget {
  const PersonaAvatar({
    required this.personaCode,
    this.size = 48,
    this.selected = false,
    super.key,
  });

  final String? personaCode;
  final double size;

  /// Seçiliyken zemin doluyor ve ikon beyaza dönüyor.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final visual = personaVisual(personaCode);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : AppColors.accentSoft,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: BrandIcon(
          visual.main,
          size: size * 0.5,
          color: selected ? AppColors.accentInk : AppColors.accent,
        ),
      ),
    );
  }
}
