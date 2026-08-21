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
  'personaCode': 'student',
  'monthlyBudget': 25000,
  'anchors': <Object>[],
};
