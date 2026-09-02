import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';

/// Harita üstünde yüzen yarı saydam malzeme — `--material-thin/thick`.
///
/// ⚠️ NEDEN OPAK BEYAZ KUTU DEĞİL
///
/// Harita canlı, renkli ve hareketli bir zemin. Mobildeki bütün harita
/// kontrolleri (`Material(color: AppColors.surface, elevation: 3)`) opak
/// beyaz kutulardı ve "ekrana yapıştırılmış" duruyorlardı — haritanın
/// üstünde yüzmüyor, haritayı kesiyorlardı. Web bunu `backdrop-filter` ile
/// çözdü; bu widget onun Flutter karşılığı.
///
/// Yarı saydam yüzey altındaki haritanın rengini taşır: aynı dünyanın
/// parçası gibi okunur.
///
/// ⚠️ MALZEME AĞIRLIĞI HİYERARŞİ TAŞIR
///
/// [thin] küçük kontroller içindir (ikon düğmesi) — daha saydam, daha hafif.
/// [thick] METİN TAŞIYAN büyük yüzeyler içindir (arama çubuğu, şerit, panel)
/// — okunabilirlik saydamlıktan önce gelir. Açık bir saydam yüzeyi başka bir
/// açık saydam yüzeyin üstüne KOYMAYIN; okunabilirlik çöker.
///
/// ⚠️ BULANIKLIK MALİYETLİ
///
/// Her [BackdropFilter] bir `saveLayer` demek. Aynı karede dörtten fazla
/// bulanık yüzey olmasın; harita zaten GPU'yu meşgul ediyor. Bu yüzden
/// bulanıklık yalnızca gerçekten haritanın ÜSTÜNDE duran yüzeylerde
/// kullanılıyor, liste ekranlarındaki kartlarda değil.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.thick = true,
    this.shadow,
    this.blur = true,
    super.key,
  });

  /// Küçük, ikon taşıyan kontroller için ince malzeme.
  const GlassSurface.thin({
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.shadow,
    this.blur = true,
    super.key,
  }) : thick = false;

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;

  /// `true` → `--material-thick` (metin taşıyan yüzeyler).
  final bool thick;

  final List<BoxShadow>? shadow;

  /// Kapatılırsa yüzey opaklaşır. Erişilebilirlik ("saydamlığı azalt")
  /// ve düşük güçlü cihaz için kaçış kapısı.
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.md);

    // Sistemde "hareketi azalt" açıkken bulanıklık da kapanıyor: ikisi de
    // aynı kullanıcı tercihinin parçası (görsel yükü azalt) ve bulanık bir
    // yüzey kaydırma sırasında sürekli yeniden hesaplandığı için titrer.
    final useBlur = blur && !MediaQuery.disableAnimationsOf(context);
    final fill = useBlur ? (thick ? AppMaterials.thick : AppMaterials.thin) : AppColors.surface;

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        // Üst kenardaki ışık — cam yüzeyin KALINLIĞINI belli eder. Bu ince
        // çizgi olmadan yarı saydam yüzey "soluk bir leke" gibi durur.
        border: Border(
          top: BorderSide(color: AppMaterials.edge, width: 1),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (useBlur) {
      surface = BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: thick ? AppMaterials.blurSigmaStrong : AppMaterials.blurSigma,
          sigmaY: thick ? AppMaterials.blurSigmaStrong : AppMaterials.blurSigma,
        ),
        child: surface,
      );
    }

    return DecoratedBox(
      // Gölge KIRPMANIN DIŞINDA olmak zorunda: `ClipRRect` içine konursa
      // kırpılır ve yüzey haritaya yapışık görünür.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow ?? (thick ? AppShadows.lg : AppShadows.md),
      ),
      child: ClipRRect(borderRadius: radius, child: surface),
    );
  }
}

/// Harita üstündeki yuvarlak eylem düğmesi.
///
/// Eskiden iki farklı düğme vardı: `_MapCircleButton` (48 px `Material`,
/// elevation 3) ve `MapLayerButton` (`IconButton` sarmalı, elevation 3) —
/// aynı sırada üst üste duruyorlardı ama farklı boyut ve farklı dokunma
/// hedefindeydiler. Tek bileşen.
class MapCircleButton extends StatefulWidget {
  const MapCircleButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.busy = false,
    this.badge = false,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool busy;

  /// Sağ üstte küçük bir uyarı noktası (ör. katman verisi yüklenemedi).
  final bool badge;

  /// Düğme bir kipi açıyorsa (ör. konum takibi açık) vurgulu çizilir.
  final bool active;

  @override
  State<MapCircleButton> createState() => _MapCircleButtonState();
}

class _MapCircleButtonState extends State<MapCircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;

    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.tooltip,
        child: GestureDetector(
          // Geri bildirim BASMA ANINDA, bırakmada değil. Dokunmatik ekranda
          // parmağın altındaki tepki gecikirse doğrudanlık hissi kayboluyor.
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1,
            duration: AppMotion.instant,
            curve: AppMotion.easeOut,
            child: GlassSurface.thin(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox.square(
                dimension: AppSpacing.mapControl,
                child: Center(
                  child:
                      widget.busy
                          ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                          : Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: AppMotion.fast,
                                child: Icon(
                                  widget.icon,
                                  key: ValueKey(widget.icon),
                                  size: 22,
                                  color:
                                      widget.active
                                          ? AppColors.accent
                                          : AppColors.ink,
                                ),
                              ),
                              if (widget.badge)
                                Positioned(
                                  top: -2,
                                  right: -4,
                                  child: Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      color: AppColors.bad,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.surface,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
