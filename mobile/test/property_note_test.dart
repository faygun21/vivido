import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:vivido_mobile/core/models/models.dart';
import 'package:vivido_mobile/core/network/api_client.dart';
import 'package:vivido_mobile/core/storage/token_store.dart';
import 'package:vivido_mobile/features/property_notes/data/api_property_note_gateway.dart';
import 'package:vivido_mobile/features/property_notes/domain/property_note.dart';

/// Kişisel not (webde vardı, mobilde yoktu).
///
/// `PropertyNotesController` aylardır yayında ve web `PropertyDetailPanel`
/// bölümü gösteriyordu; mobil detay sayfasında bu bölüm hiç çizilmemişti.
/// Backend'e yeni bir şey EKLENMEDİ — yalnızca mobil istemci yazıldı, o
/// yüzden bu testler uç sözleşmesinin web ile aynı okunduğunu doğruluyor.
void main() {
  ApiClient clientWith(MockClient mock) => ApiClient(
    baseUrl: 'http://localhost/api/v1',
    // Not uçları `[Authorize]` — oturumsuz istemci 401 alırdı.
    tokenStore: MemoryTokenStore(
      const AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresIn: 3600,
        user: AuthUser(id: 'u1', email: 'a@b.c'),
      ),
    ),
    httpClient: mock,
  );

  test('not okuma web ile aynı uca gidiyor', () async {
    late Uri requested;
    late String method;
    final gateway = ApiPropertyNoteGateway(
      clientWith(
        MockClient((request) async {
          requested = request.url;
          method = request.method;
          return http.Response(
            jsonEncode({
              'propertyId': 42,
              'note': 'Balkon güneş alıyor.',
              'createdAt': '2026-08-01T10:00:00Z',
              'updatedAt': '2026-08-02T10:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );

    final note = await gateway.getNote('42');

    expect(method, 'GET');
    expect(requested.path, '/api/v1/properties/42/note');
    expect(note.note, 'Balkon güneş alıyor.');
    expect(note.isEmpty, isFalse);
  });

  test('notu olmayan konut boş kayıt döner, hata değil', () async {
    // Sunucu 404 DEĞİL, `note: null` dönüyor. İstemci bunu bir hata gibi
    // ele alsaydı, hiç not yazmamış her kullanıcı detay sayfasında kırmızı
    // bir uyarı görürdü.
    final gateway = ApiPropertyNoteGateway(
      clientWith(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'propertyId': 7,
              'note': null,
              'createdAt': null,
              'updatedAt': null,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
    );

    final note = await gateway.getNote('7');
    expect(note.isEmpty, isTrue);
    expect(note.createdAt, isNull);
  });

  test('not kaydetme PUT ile gövdede note alanı gönderiyor', () async {
    late Map<String, dynamic> body;
    final gateway = ApiPropertyNoteGateway(
      clientWith(
        MockClient((request) async {
          expect(request.method, 'PUT');
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'propertyId': 42, 'note': body['note']}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );

    final saved = await gateway.saveNote('42', 'Otoparkı yok.');
    expect(body['note'], 'Otoparkı yok.');
    expect(saved.note, 'Otoparkı yok.');
  });

  test('not silme DELETE atıyor', () async {
    late String method;
    final gateway = ApiPropertyNoteGateway(
      clientWith(
        MockClient((request) async {
          method = request.method;
          return http.Response('', 204);
        }),
      ),
    );

    await gateway.deleteNote('42');
    expect(method, 'DELETE');
  });

  test('sunucu hatası kullanıcıya gösterilebilir bir mesaja çevriliyor', () {
    final gateway = ApiPropertyNoteGateway(
      clientWith(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'title': 'Konut bulunamadı',
              'detail': 'Bu konut artık listede değil.',
              'code': 'PROPERTY_NOT_FOUND',
            }),
            404,
            // ⚠️ `charset=utf-8` GEREKLİ. `http.Response` gövdeyi
            // content-type'taki karakter kümesine göre kodluyor; charset
            // yoksa latin1'e düşüyor ve Türkçe karakterler bozuluyor.
            // ASP.NET Core gerçekte charset'i gönderiyor.
            headers: {
              'content-type': 'application/problem+json; charset=utf-8',
            },
          ),
        ),
      ),
    );

    expect(
      () => gateway.getNote('999'),
      throwsA(
        isA<PropertyNoteFailure>().having(
          (failure) => failure.message,
          'message',
          'Bu konut artık listede değil.',
        ),
      ),
    );
  });

  test('sunucu sınırı ile form sınırı aynı', () {
    // `PropertyNotesController.MaxNoteLength` 1000. Form daha yüksek bir
    // sınıra izin verseydi kullanıcı yazdığı notu kaydedemediğini ancak
    // istek başarısız olunca öğrenirdi.
    expect(maxPropertyNoteLength, 1000);
  });
}
