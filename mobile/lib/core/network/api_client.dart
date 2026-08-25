import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/models.dart';
import '../storage/token_store.dart';

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.title,
    this.code,
    this.detail,
  });

  final int statusCode;
  final String title;
  final String? code;
  final String? detail;

  @override
  String toString() => detail ?? title;
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.tokenStore,
    http.Client? httpClient,
  }) : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final TokenStore tokenStore;
  final http.Client _httpClient;

  AuthSession? _session;

  AuthSession? get session => _session;

  Future<AuthSession?> restoreSession() async {
    _session = await tokenStore.read();
    return _session;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) => _authenticate('/auth/login', {'email': email, 'password': password});

  /// Kayıt olur.
  ///
  /// İki başarılı sonuç var (K-09): 202 → doğrulama kodu bekleniyor,
  /// 201 → doğrulama kapalı, oturum açıldı. Durum kodunu görmek zorunda
  /// olduğumuz için `_authenticate` yerine ham istek kullanılıyor.
  Future<RegisterOutcome> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final result = await _requestRaw(
      'POST',
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName.trim(),
      },
      authenticated: false,
      retryOnUnauthorized: false,
    );

    if (result.status == 202) {
      return RegisterVerificationRequired.fromJson(
        result.body as Map<String, dynamic>,
      );
    }

    final session = AuthSession.fromJson(result.body as Map<String, dynamic>);
    await _saveSession(session);
    return RegisterAuthenticated(session);
  }

  /// E-postaya gelen 6 haneli kodu doğrular; başarılıysa oturum açar.
  Future<AuthSession> verifyEmail({
    required String email,
    required String code,
  }) => _authenticate('/auth/verify-email', {'email': email, 'code': code});

  /// Doğrulama kodunu yeniden gönderir. Yanıttaki bilgilendirme metnini döner.
  Future<String> resendVerification(String email) =>
      _message('/auth/resend-verification', {'email': email});

  /// "Şifremi unuttum" — sıfırlama kodu gönderir.
  ///
  /// Hesap yoksa bile başarılı görünür; sunucu bilerek öyle davranıyor.
  Future<String> forgotPassword(String email) =>
      _message('/auth/forgot-password', {'email': email});

  /// Kod + yeni şifre ile sıfırlamayı tamamlar.
  ///
  /// Sunucu tüm refresh token'ları iptal ettiği için sonrasında yeniden
  /// giriş yapmak gerekir — bu yüzden oturum DÖNMEZ.
  Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _message('/auth/reset-password', {
    'email': email,
    'code': code,
    'newPassword': newPassword,
  });

  Future<dynamic> get(String path) => _request('GET', path);

  Future<dynamic> post(String path, [Object? body]) =>
      _request('POST', path, body: body);

  Future<dynamic> put(String path, [Object? body]) =>
      _request('PUT', path, body: body);

  Future<void> delete(String path) async {
    await _request('DELETE', path);
  }

  Future<void> logout() async {
    _session = null;
    await tokenStore.clear();
  }

  void close() => _httpClient.close();

  Future<AuthSession> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    final json = await _request(
      'POST',
      path,
      body: body,
      authenticated: false,
      retryOnUnauthorized: false,
    );
    final session = AuthSession.fromJson(json as Map<String, dynamic>);
    await _saveSession(session);
    return session;
  }

  Future<void> _saveSession(AuthSession session) async {
    _session = session;
    await tokenStore.write(session);
  }

  /// Yalnızca `{ status, message }` dönen uç noktalar için ortak sarmalayıcı.
  Future<String> _message(String path, Map<String, dynamic> body) async {
    final json = await _request(
      'POST',
      path,
      body: body,
      authenticated: false,
      retryOnUnauthorized: false,
    );
    if (json is Map<String, dynamic>) {
      return json['message'] as String? ?? 'İşlem tamamlandı.';
    }
    return 'İşlem tamamlandı.';
  }

  Future<void> _refresh() async {
    final refreshToken = _session?.refreshToken;
    if (refreshToken == null) {
      throw const ApiException(
        statusCode: 401,
        title: 'Oturum bulunamadı',
        code: 'SESSION_MISSING',
      );
    }

    try {
      final json = await _request(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
        authenticated: false,
        retryOnUnauthorized: false,
      );
      await _saveSession(AuthSession.fromJson(json as Map<String, dynamic>));
    } on ApiException {
      await logout();
      rethrow;
    }
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
    bool retryOnUnauthorized = true,
  }) async =>
      (await _requestRaw(
        method,
        path,
        body: body,
        authenticated: authenticated,
        retryOnUnauthorized: retryOnUnauthorized,
      )).body;

  /// Gövdeyle birlikte HTTP durum kodunu da döner.
  ///
  /// Ayrı bir metot olmasının tek sebebi `POST /auth/register`: aynı uç
  /// nokta hem 201 (oturum) hem 202 (doğrulama bekleniyor) dönebiliyor ve
  /// ikisi farklı gövdeler taşıyor (K-09). Diğer her yerde `_request` yeterli.
  Future<({int status, dynamic body})> _requestRaw(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
    bool retryOnUnauthorized = true,
  }) async {
    final request = http.Request(method, _resolve(path));
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    if (authenticated && _session != null) {
      request.headers['Authorization'] = 'Bearer ${_session!.accessToken}';
    }

    late final http.Response response;
    try {
      final streamed = await _httpClient
          .send(request)
          .timeout(AppConfig.receiveTimeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException(
        statusCode: 408,
        title: 'Sunucu yanıt vermedi',
        code: 'REQUEST_TIMEOUT',
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        statusCode: 0,
        title: 'Sunucuya bağlanılamadı',
        detail: error.message,
        code: 'NETWORK_ERROR',
      );
    }

    if (response.statusCode == 401 &&
        authenticated &&
        retryOnUnauthorized &&
        _session?.refreshToken != null) {
      await _refresh();
      return _requestRaw(
        method,
        path,
        body: body,
        authenticated: authenticated,
        retryOnUnauthorized: false,
      );
    }

    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final problem =
          decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      throw ApiException(
        statusCode: response.statusCode,
        title: problem['title'] as String? ?? 'İstek tamamlanamadı',
        detail: _problemDetail(problem),
        code: problem['code'] as String?,
      );
    }
    return (status: response.statusCode, body: decoded);
  }

  String? _problemDetail(Map<String, dynamic> problem) {
    final detail = problem['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail;

    final errors = problem['errors'];
    if (errors is! Map<String, dynamic>) return null;
    for (final messages in errors.values) {
      if (messages is! List<dynamic>) continue;
      for (final message in messages) {
        if (message is String && message.trim().isNotEmpty) return message;
      }
    }
    return null;
  }

  Uri _resolve(String path) =>
      _baseUri.resolve(path.startsWith('/') ? path.substring(1) : path);

  dynamic _decode(http.Response response) {
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) return null;
    final text = utf8.decode(response.bodyBytes);
    if (text.trim().isEmpty) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }
}

class VividoRepository {
  const VividoRepository(this.client);

  final ApiClient client;

  Future<List<Persona>> getPersonas() async {
    final json = await client.get('/personas') as List<dynamic>;
    return json
        .map((item) => Persona.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserProfile> getProfile() async => UserProfile.fromJson(
    await client.get('/profile') as Map<String, dynamic>,
  );

  Future<UserProfile> saveProfile({
    required String firstName,
    required String lastName,
    required String personaCode,
    double? minMonthlyBudget,
    double? maxMonthlyBudget,
    List<String>? categoryOrder,
  }) async => UserProfile.fromJson(
    await client.put('/profile', {
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'personaCode': personaCode,
          'minMonthlyBudget': minMonthlyBudget,
          'maxMonthlyBudget': maxMonthlyBudget,
          if (categoryOrder != null) 'categoryOrder': categoryOrder,
        })
        as Map<String, dynamic>,
  );

  Future<List<Anchor>> getAnchors() async {
    final json = await client.get('/profile/anchors') as List<dynamic>;
    return json
        .map((item) => Anchor.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  Future<Anchor> createAnchor({
    required String label,
    required double lat,
    required double lon,
    required String mode,
  }) async => Anchor.fromJson(
    await client.post('/profile/anchors', {
          'label': label,
          'lat': lat,
          'lon': lon,
          'mode': mode,
        })
        as Map<String, dynamic>,
  );

  Future<void> deleteAnchor(String id) => client.delete('/profile/anchors/$id');

  Future<List<Anchor>> reorderAnchors(List<String> order) async {
    final json =
        await client.put('/profile/anchors/order', {'order': order})
            as List<dynamic>;
    return json
        .map((item) => Anchor.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }
}
