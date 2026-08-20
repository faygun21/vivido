import 'package:flutter_test/flutter_test.dart';
import 'package:vivido_mobile/app/app.dart';

void main() {
  testWidgets('Vivido başlangıç ekranı açılır', (tester) async {
    await tester.pumpWidget(const VividoApp());

    expect(find.text('Vivido'), findsOneWidget);
    expect(find.text("Vivido'ya Hoş Geldin"), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
    expect(find.text('Rotalarım'), findsOneWidget);
  });
}
