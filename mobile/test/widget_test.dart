import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vivido_mobile/core/network/api_client.dart';
import 'package:vivido_mobile/core/storage/token_store.dart';
import 'package:vivido_mobile/features/auth/application/session_controller.dart';
import 'package:vivido_mobile/features/auth/presentation/pages/welcome_page.dart';

void main() {
  testWidgets('oturum yoksa giriş ekranı açılır', (tester) async {
    final client = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStore: MemoryTokenStore(),
      httpClient: MockClient(
        (_) async => throw StateError('Beklenmeyen istek'),
      ),
    );
    final controller = SessionController(
      client: client,
      repository: VividoRepository(client),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: WelcomePage(controller: controller)),
    );

    await tester.pumpAndSettle();

    // Slogan artık elle satır kırılmıyor: sabit `\n`'ler dar ekranda
    // ortadaki satırı taşırıyordu, metin kendi sarmasını yapıyor.
    expect(
      find.text(
        'Yeni evini sadece konumuna göre değil, yaşamına göre seç.',
      ),
      findsOneWidget,
    );

    // R-2: üç seçenek de karşılama ekranında. Etiketler cümle
    // biçiminde ("Giriş yap"), Her Kelime Büyük değil — uygulamanın
    // geri kalanıyla aynı yazım.
    expect(find.text('Giriş yap'), findsOneWidget);
    expect(find.text('Hesap oluştur'), findsOneWidget);
    expect(find.text('Misafir olarak keşfet'), findsOneWidget);

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
