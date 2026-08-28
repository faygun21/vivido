import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/models/models.dart';
import '../domain/offline_credential_store.dart';

class SecureOfflineCredentialStore implements OfflineCredentialStore {
  SecureOfflineCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'vivido.auth.offline-credential.v1';
  static const _iterations = 60000;
  final FlutterSecureStorage _storage;

  @override
  Future<void> enroll({
    required String email,
    required String password,
    required AuthSession session,
  }) async {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final digest = await Isolate.run(
      () => _derivePasswordKey(password, salt, _iterations),
    );
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'email': _normalizeEmail(email),
        'salt': base64Encode(salt),
        'digest': base64Encode(digest),
        'iterations': _iterations,
        'session': session.toJson(),
      }),
    );
  }

  @override
  Future<bool> hasEnrollment(String email) async {
    final record = await _readRecord();
    return record != null && record.email == _normalizeEmail(email);
  }

  @override
  Future<AuthSession?> unlock({
    required String email,
    required String password,
  }) async {
    final record = await _readRecord();
    if (record == null || record.email != _normalizeEmail(email)) return null;
    final actual = await Isolate.run(
      () => _derivePasswordKey(password, record.salt, record.iterations),
    );
    return _constantTimeEquals(actual, record.digest) ? record.session : null;
  }

  Future<_OfflineCredentialRecord?> _readRecord() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _OfflineCredentialRecord(
        email: json['email'] as String,
        salt: base64Decode(json['salt'] as String),
        digest: base64Decode(json['digest'] as String),
        iterations: (json['iterations'] as num).toInt(),
        session: AuthSession.fromJson(json['session'] as Map<String, dynamic>),
      );
    } on Object {
      await _storage.delete(key: _key);
      return null;
    }
  }
}

class _OfflineCredentialRecord {
  const _OfflineCredentialRecord({
    required this.email,
    required this.salt,
    required this.digest,
    required this.iterations,
    required this.session,
  });

  final String email;
  final List<int> salt;
  final List<int> digest;
  final int iterations;
  final AuthSession session;
}

String _normalizeEmail(String value) => value.trim().toLowerCase();

List<int> _derivePasswordKey(String password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, utf8.encode(password));
  var current = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final result = List<int>.of(current);
  for (var round = 1; round < iterations; round++) {
    current = hmac.convert(current).bytes;
    for (var index = 0; index < result.length; index++) {
      result[index] ^= current[index];
    }
  }
  return result;
}

bool _constantTimeEquals(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
