import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivido_mobile/core/theme/app_colors.dart';
import 'package:vivido_mobile/shared/widgets/glass_surface.dart';

/// Harita üstündeki cam malzemenin çizilebildiğini doğrular.
///
/// ⚠️ NEDEN BU TEST VAR
///
/// [GlassSurface] yüzeyin üst kenarına bir ışık çizgisi koyuyor
/// (`--material-edge`) ve bunu `Border(top: ...)` ile yapıyor — yani
/// TEK KENARLI bir çerçeve, üstelik `borderRadius` ile birlikte.
///
/// Flutter genelde bunu reddediyor: `Border.paint`,
/// *"A borderRadius can only be given on borders with uniform colors"*
/// diye assert atıyor. Burada çalışmasının sebebi, diğer üç kenarın
/// `BorderStyle.none` olması: GÖRÜNEN renk sayısı bir olduğunda
/// `paintNonUniformBorder` devreye giriyor.
///
/// Bu ince bir ayrıntı. Biri kenar çizgisini "düzeltmek" için ikinci bir
/// kenara renk verirse (ör. alt kenara da bir gölge çizgisi) her cam yüzey
/// debug modda çökerdi ve bu, harita ekranının tamamı demek. Test o
/// sınırın üstünde duruyor.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
    await tester.pump();
  }

  testWidgets('kalın cam yüzey assert atmadan çiziliyor', (tester) async {
    await pump(
      tester,
      const GlassSurface(child: SizedBox(width: 160, height: 60)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ince cam yüzey assert atmadan çiziliyor', (tester) async {
    await pump(
      tester,
      const GlassSurface.thin(child: SizedBox(width: 48, height: 48)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('yuvarlak harita düğmesi çiziliyor ve dokunuşu iletiyor', (
    tester,
  ) async {
    var tapped = 0;
    await pump(
      tester,
      MapCircleButton(
        icon: Icons.layers_outlined,
        tooltip: 'Harita katmanları',
        onPressed: () => tapped++,
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(MapCircleButton));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('meşgulken dokunuş yutuluyor', (tester) async {
    var tapped = 0;
    await pump(
      tester,
      MapCircleButton(
        icon: Icons.layers_outlined,
        tooltip: 'Harita katmanları',
        busy: true,
        onPressed: () => tapped++,
      ),
    );

    await tester.tap(find.byType(MapCircleButton));
    // `pumpAndSettle` DEĞİL: meşgul düğmede sonsuz dönen bir
    // `CircularProgressIndicator` var, yerleşme hiç bitmez.
    await tester.pump();
    expect(tapped, 0, reason: 'yükleniyorken ikinci istek atılmamalı');
  });

  testWidgets('"hareketi azalt" açıkken yüzey opaklaşıyor', (tester) async {
    // Bulanıklık kaydırma sırasında sürekli yeniden hesaplandığı için
    // titriyor; erişilebilirlik tercihi açıkken kapanıyor ve yüzey
    // tamamen opak oluyor — metin her koşulda okunur kalmalı.
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlassSurface(child: SizedBox(width: 160, height: 60)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(BackdropFilter), findsNothing);

    final decorated = tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    );
    final fills = decorated
        .map((box) => (box.decoration as BoxDecoration).color)
        .whereType<Color>();
    expect(
      fills,
      contains(AppColors.surface),
      reason: 'bulanıklık kapalıyken yüzey tamamen opak olmalı',
    );
  });
}
