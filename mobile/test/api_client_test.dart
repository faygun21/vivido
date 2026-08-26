import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivido_mobile/core/models/models.dart';
import 'package:vivido_mobile/core/network/api_client.dart';
import 'package:vivido_mobile/core/storage/token_store.dart';

void main() {
  group('ApiClient', () {
    test('giriş tokenlarını saklar ve Bearer başlığını gönderir', () async {
      final store = MemoryTokenStore();
      final mock = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'email': 'test@vivido.app',
            'password': 'secret123',
          });
          return _jsonResponse(_authJson(accessToken: 'access-1'));
        }
        if (request.url.path == '/api/v1/profile') {
          expect(request.headers['authorization'], 'Bearer access-1');
          return _jsonResponse(_profileJson);
        }
        return http.Response('Not found', 404);
      });
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: store,
        httpClient: mock,
      );
      addTearDown(client.close);

      await client.login(email: 'test@vivido.app', password: 'secret123');
      final profile = await VividoRepository(client).getProfile();

      expect(store.session?.accessToken, 'access-1');
      expect(profile.personaCode, 'student');
    });

    test('401 sonrasında tokenı yenileyip isteği bir kez tekrarlar', () async {
      final store = MemoryTokenStore(_session(accessToken: 'expired'));
      var profileRequests = 0;
      final mock = MockClient((request) async {
        if (request.url.path == '/api/v1/profile') {
          profileRequests += 1;
          if (profileRequests == 1) {
            expect(request.headers['authorization'], 'Bearer expired');
            return _jsonResponse({
              'title': 'Unauthorized',
              'code': 'TOKEN_EXPIRED',
            }, statusCode: 401);
          }
          expect(request.headers['authorization'], 'Bearer renewed');
          return _jsonResponse(_profileJson);
        }
        if (request.url.path == '/api/v1/auth/refresh') {
          expect(jsonDecode(request.body), {'refreshToken': 'refresh-1'});
          return _jsonResponse(
            _authJson(accessToken: 'renewed', refreshToken: 'refresh-2'),
          );
        }
        return http.Response('Not found', 404);
      });
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: store,
        httpClient: mock,
      );
      addTearDown(client.close);

      await client.restoreSession();
      final profile = await VividoRepository(client).getProfile();

      expect(profile.personaCode, 'student');
      expect(profileRequests, 2);
      expect(store.session?.accessToken, 'renewed');
      expect(store.session?.refreshToken, 'refresh-2');
    });

    test(
      'eş zamanlı 401 yanıtlarında refresh isteğini tekilleştirir',
      () async {
        final store = MemoryTokenStore(_session(accessToken: 'expired'));
        var refreshRequests = 0;
        final mock = MockClient((request) async {
          if (request.url.path == '/api/v1/auth/refresh') {
            refreshRequests++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return _jsonResponse(
              _authJson(accessToken: 'renewed', refreshToken: 'refresh-2'),
            );
          }
          if (request.headers['authorization'] == 'Bearer expired') {
            return _jsonResponse({
              'title': 'Unauthorized',
              'code': 'TOKEN_EXPIRED',
            }, statusCode: 401);
          }
          expect(request.headers['authorization'], 'Bearer renewed');
          return _jsonResponse({'ok': true});
        });
        final client = ApiClient(
          baseUrl: 'http://localhost/api/v1',
          tokenStore: store,
          httpClient: mock,
        );
        addTearDown(client.close);
        await client.restoreSession();

        await Future.wait([
          client.get('/properties/top'),
          client.get('/profile/favorites'),
          client.get('/routes'),
        ]);

        expect(refreshRequests, 1);
        expect(store.session?.accessToken, 'renewed');
      },
    );

    // K-09: kayıt artık iki farklı BAŞARILI yanıt verebiliyor. 202 gelince
    // token saklanmamalı — saklanırsa doğrulanmamış hesap oturum açmış olur.
    test('kayıt 202 dönerse oturum açılmaz, doğrulama beklenir', () async {
      final store = MemoryTokenStore();
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/register');
        return _jsonResponse({
          'status': 'verification_required',
          'email': 'yeni@vivido.app',
          'expiresInMinutes': 15,
          'message': 'Kod gönderildi.',
        }, statusCode: 202);
      });
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: store,
        httpClient: mock,
      );
      addTearDown(client.close);

      final outcome = await client.register(
        email: 'yeni@vivido.app',
        password: 'secret123',
      );

      expect(outcome, isA<RegisterVerificationRequired>());
      expect(
        (outcome as RegisterVerificationRequired).email,
        'yeni@vivido.app',
      );
      expect(store.session, isNull);
      expect(client.session, isNull);
    });

    test('alan bazlı doğrulama hatasının açıklamasını korur', () async {
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: MemoryTokenStore(),
        httpClient: MockClient(
          (_) async => _jsonResponse({
            'title': 'Gönderilen bilgiler geçersiz',
            'code': 'VALIDATION_ERROR',
            'errors': {
              'password': [
                'Parola büyük harf, rakam ve özel karakter içermeli.',
              ],
            },
          }, statusCode: 400),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.register(email: 'test@vivido.app', password: 'weak'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.code, 'code', 'VALIDATION_ERROR')
              .having(
                (error) => error.detail,
                'detail',
                'Parola büyük harf, rakam ve özel karakter içermeli.',
              ),
        ),
      );
    });

    test('doğrulama kodu kabul edilirse oturum açılır', () async {
      final store = MemoryTokenStore();
      final mock = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/verify-email');
        expect(jsonDecode(request.body), {
          'email': 'yeni@vivido.app',
          'code': '123456',
        });
        return _jsonResponse(_authJson(accessToken: 'access-2'));
      });
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: store,
        httpClient: mock,
      );
      addTearDown(client.close);

      await client.verifyEmail(email: 'yeni@vivido.app', code: '123456');

      expect(store.session?.accessToken, 'access-2');
    });

    test('profil güncellemesi ad, soyad ve kriter sırasını gönderir', () async {
      final categoryOrder = <String>[
        'school',
        'transit',
        'market',
        'pharmacy',
        'food',
        'park',
        'gym',
        'health',
      ];
      final store = MemoryTokenStore(_session(accessToken: 'access-1'));
      final mock = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/profile');
        expect(request.headers['authorization'], 'Bearer access-1');
        expect(jsonDecode(request.body), {
          'firstName': 'Mert',
          'lastName': 'Dulgar',
          'personaCode': 'student',
          'minMonthlyBudget': 15000,
          'maxMonthlyBudget': 27500,
          'categoryOrder': categoryOrder,
        });
        return _jsonResponse({
          ..._profileJson,
          'minMonthlyBudget': 15000,
          'maxMonthlyBudget': 27500,
          'categoryOrder': categoryOrder,
        });
      });
      final client = ApiClient(
        baseUrl: 'http://localhost/api/v1',
        tokenStore: store,
        httpClient: mock,
      );
      addTearDown(client.close);
      await client.restoreSession();

      final profile = await VividoRepository(client).saveProfile(
        firstName: ' Mert ',
        lastName: ' Dulgar ',
        personaCode: 'student',
        minMonthlyBudget: 15000,
        maxMonthlyBudget: 27500,
        categoryOrder: categoryOrder,
      );

      expect(profile.firstName, 'Mert');
      expect(profile.lastName, 'Dulgar');
      expect(profile.categoryOrder, categoryOrder);
    });
  });
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, Object> _authJson({
  required String accessToken,
  String refreshToken = 'refresh-1',
}) => {
  'user': {'id': 'user-1', 'email': 'test@vivido.app', 'displayName': 'Test'},
  'tokens': {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresIn': 900,
  },
};

AuthSession _session({required String accessToken}) => AuthSession(
  user: const AuthUser(
    id: 'user-1',
    email: 'test@vivido.app',
    displayName: 'Test',
  ),
  accessToken: accessToken,
  refreshToken: 'refresh-1',
  expiresIn: 900,
);

const _profileJson = <String, Object>{
  'id': 'profile-1',
  'firstName': 'Mert',
  'lastName': 'Dulgar',
  'personaCode': 'student',
  'minMonthlyBudget': 15000,
  'maxMonthlyBudget': 25000,
  'categoryOrder': <String>[],
  'anchors': <Object>[],
};
