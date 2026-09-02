import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivido_mobile/shared/widgets/mascot.dart';

/// Rehber turu.
///
/// ⚠️ TUR AÇILIR AÇILMAZ PATLIYORDU
///
/// `AnimatedSpotlight`, karartma deliğini `TweenAnimationBuilder` ile
/// canlandırıyordu ve hedef dikdörtgeni `null` olduğunda
/// `RectTween(end: null)` kuruluyordu:
///
///   *Failed assertion: 'widget.tween.end != null': Tween provided to
///   TweenAnimationBuilder must have non-null Tween.end value.*
///
/// Null iki yerde geçerli bir durum: hedefi olmayan adımlar (giriş ve
/// kapanış) ve her adımın ölçüm öncesi ilk karesi. Yani tur her açılışta
/// kırmızı hata ekranı basıyordu.
void main() {
  Future<void> pumpTour(
    WidgetTester tester, {
    required List<TourStep> steps,
    VoidCallback? onFinished,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Positioned(
                top: 40,
                left: 20,
                child: SizedBox(width: 100, height: 40),
              ),
              Positioned.fill(
                child: GuideTour(
                  steps: steps,
                  onFinished: onFinished ?? () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hedefi olmayan adım hata vermeden çiziliyor', (tester) async {
    await pumpTour(
      tester,
      steps: const [TourStep(title: 'Hoş geldin', text: 'Başlayalım.')],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Hoş geldin'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('hedefli adımın ölçümü beklenirken hata vermiyor', (
    tester,
  ) async {
    final targetKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 60,
                left: 30,
                child: SizedBox(
                  key: targetKey,
                  width: 120,
                  height: 48,
                  child: const ColoredBox(color: Color(0xFF000000)),
                ),
              ),
              Positioned.fill(
                child: GuideTour(
                  onFinished: () {},
                  steps: [
                    TourStep(text: 'Buraya bak', targetKey: targetKey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // İlk kare: ölçüm henüz yapılmadı, dikdörtgen null.
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Ölçüm gecikmesinden sonra: dikdörtgen var, delik canlanıyor.
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adımlar arasında ileri geri gidiliyor', (tester) async {
    await pumpTour(
      tester,
      steps: const [
        TourStep(title: 'Bir', text: 'İlk adım.'),
        TourStep(title: 'İki', text: 'İkinci adım.'),
      ],
    );

    expect(find.text('1 / 2'), findsOneWidget);
    // İlk adımda "Geri" yok, "Geç" var.
    expect(find.text('Geç'), findsOneWidget);
    expect(find.text('Geri'), findsNothing);

    await tester.tap(find.text('İleri'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Geri'), findsOneWidget);
    expect(find.text('Tamamla'), findsOneWidget);

    await tester.tap(find.text('Geri'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('Tamamla ve Geç bayrağı yazan geri çağrımı tetikliyor', (
    tester,
  ) async {
    var finished = 0;

    await pumpTour(
      tester,
      steps: const [TourStep(text: 'Tek adım.')],
      onFinished: () => finished++,
    );
    await tester.tap(find.text('Tamamla'));
    await tester.pump();
    expect(finished, 1);

    await pumpTour(
      tester,
      steps: const [
        TourStep(text: 'Bir.'),
        TourStep(text: 'İki.'),
      ],
      onFinished: () => finished++,
    );
    await tester.tap(find.text('Geç'));
    await tester.pump();
    expect(finished, 2);
  });

  testWidgets('son adım sekme değiştirmiyor', (tester) async {
    // ⚠️ Son adım bir zamanlar `onEnter` ile başka bir sekmeye geçiyordu;
    // o geçiş turu barındıran widget'ı ağaçtan söküyor, `onFinished` hiç
    // çalışmıyor ve bayrak yazılmadığı için tur her açılışta yeniden
    // başlıyordu.
    var finished = 0;
    await pumpTour(
      tester,
      steps: const [
        TourStep(text: 'Bir.'),
        TourStep(title: 'Hazırsın', text: 'Bitti.'),
      ],
      onFinished: () => finished++,
    );

    await tester.tap(find.text('İleri'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Hazırsın'), findsOneWidget);

    await tester.tap(find.text('Tamamla'));
    await tester.pump();
    expect(finished, 1, reason: 'son adım onFinished çağırmalı');
  });
}
