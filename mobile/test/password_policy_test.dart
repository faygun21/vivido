import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivido_mobile/core/network/api_client.dart';
import 'package:vivido_mobile/core/storage/token_store.dart';
import 'package:vivido_mobile/features/auth/application/session_controller.dart';
import 'package:vivido_mobile/features/auth/domain/password_policy.dart';
import 'package:vivido_mobile/features/auth/presentation/pages/register_page.dart';

void main() {
  group('güçlü parola politikası', () {
    test('backend ve web ile aynı beş koşulu zorunlu tutar', () {
      expect(isStrongPassword('Ab1!'), isFalse, reason: 'en az 8 karakter');
      expect(isStrongPassword('guclu123!'), isFalse, reason: 'büyük harf');
      expect(isStrongPassword('GUCLU123!'), isFalse, reason: 'küçük harf');
      expect(isStrongPassword('GucluParola!'), isFalse, reason: 'rakam');
      expect(isStrongPassword('Guclu123'), isFalse, reason: 'özel karakter');
      expect(isStrongPassword('Guclu123!'), isTrue);
    });

    test('eksik koşulları kullanıcıya ayrı ayrı açıklar', () {
      expect(
        validateStrongPassword('Mertdulgar1'),
        'Parolada özel karakter (!, @, # gibi) eksik.',
      );
      expect(
        validateStrongPassword('abc'),
        contains('en az 8 karakter, büyük harf, rakam, özel karakter'),
      );
      expect(validateStrongPassword('Guclu123!'), isNull);
    });
  });

  testWidgets('kayıt formu zayıf parolayı API isteğinden önce reddeder', (
    tester,
  ) async {
    var requestSent = false;
    final client = ApiClient(
      baseUrl: 'http://localhost/api/v1',
      tokenStore: MemoryTokenStore(),
      httpClient: MockClient((_) async {
        requestSent = true;
        return http.Response('{}', 500);
      }),
    );
    final controller = SessionController(
      client: client,
      repository: VividoRepository(client),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: RegisterPage(controller: controller)),
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Ad'), 'Mert');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Soyad'),
      'Dulgar',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-posta adresi'),
      'mert@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-password')),
      'secret123',
    );
    await tester.ensureVisible(find.text('Hesap oluştur'));
    await tester.tap(find.text('Hesap oluştur'));
    await tester.pump();

    expect(
      find.text(
        'Parolada şunlar eksik: büyük harf, özel karakter (!, @, # gibi).',
      ),
      findsOneWidget,
    );
    expect(requestSent, isFalse);
  });
}
