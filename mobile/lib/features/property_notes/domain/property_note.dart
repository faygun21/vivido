/// Kullanıcının bir konut için tuttuğu özel not.
///
/// ⚠️ WEBDE VARDI, MOBİLDE YOKTU. `PropertyNotesController` aylardır
/// yayında ve web `PropertyDetailPanel`'de "Kişisel Notum" bölümünü
/// gösteriyor; mobil detay sayfasında bu bölüm hiç çizilmemişti. Backend'e
/// yeni bir şey eklenmedi — yalnızca mobil istemci yazıldı.
class PropertyNote {
  const PropertyNote({
    required this.propertyId,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String propertyId;

  /// Not metni; kullanıcı henüz not yazmadıysa `null`.
  final String? note;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isEmpty => note == null || note!.trim().isEmpty;

  factory PropertyNote.fromJson(Map<String, dynamic> json) => PropertyNote(
    propertyId: json['propertyId'].toString(),
    note: json['note'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
}

class PropertyNoteFailure implements Exception {
  const PropertyNoteFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class PropertyNoteGateway {
  Future<PropertyNote> getNote(String propertyId);

  Future<PropertyNote> saveNote(String propertyId, String note);

  Future<void> deleteNote(String propertyId);
}

/// Sunucudaki sınır — form da aynı sınırı uyguluyor ki kullanıcı 1000
/// karakteri geçtiğini istek göndermeden önce görsün.
const int maxPropertyNoteLength = 1000;
