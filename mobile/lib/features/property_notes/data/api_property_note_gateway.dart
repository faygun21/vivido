import '../../../core/network/api_client.dart';
import '../domain/property_note.dart';

/// `GET/PUT/DELETE /properties/{id}/note` — web ile AYNI uçlar.
class ApiPropertyNoteGateway implements PropertyNoteGateway {
  const ApiPropertyNoteGateway(this._client);

  final ApiClient _client;

  @override
  Future<PropertyNote> getNote(String propertyId) async {
    try {
      final json =
          await _client.get('/properties/$propertyId/note')
              as Map<String, dynamic>;
      return PropertyNote.fromJson(json);
    } on ApiException catch (error) {
      throw PropertyNoteFailure(error.detail ?? error.title);
    } on Object {
      throw const PropertyNoteFailure('Not yüklenemedi.');
    }
  }

  @override
  Future<PropertyNote> saveNote(String propertyId, String note) async {
    try {
      final json =
          await _client.put('/properties/$propertyId/note', {'note': note})
              as Map<String, dynamic>;
      return PropertyNote.fromJson(json);
    } on ApiException catch (error) {
      throw PropertyNoteFailure(error.detail ?? error.title);
    } on Object {
      throw const PropertyNoteFailure('Not kaydedilemedi.');
    }
  }

  @override
  Future<void> deleteNote(String propertyId) async {
    try {
      await _client.delete('/properties/$propertyId/note');
    } on ApiException catch (error) {
      throw PropertyNoteFailure(error.detail ?? error.title);
    } on Object {
      throw const PropertyNoteFailure('Not silinemedi.');
    }
  }
}
