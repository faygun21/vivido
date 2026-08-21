import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
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

    expect(find.text('Vivido'), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget);
    expect(find.text('Yeni hesap oluştur'), findsOneWidget);
  });
}
