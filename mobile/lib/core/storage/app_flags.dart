import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cihaza yazılan küçük kullanıcı tercihleri — "rehberi gördüm", "ipucunu
/// kapattım" gibi tek bayraklar.
///
/// Web bunları `localStorage`'da tutuyor (bkz. `POI_HINT_STORAGE_KEY`).
/// Mobilde ayrı bir tercih paketi (`shared_preferences`) eklemek yerine
/// zaten bağımlılıkta olan güvenli depoyu kullanıyoruz: bayraklar gizli
/// değil ama bir paket daha eklemenin bedeli, güvenli depoya bir anahtar
/// daha yazmanın bedelinden büyük.
///
/// ⚠️ Bayraklar OTURUMDAN bağımsız: çıkış yapmak rehberi sıfırlamıyor.
/// Aynı telefonu kullanan aynı kişiye turu ikinci kez göstermek gerekmiyor.
class AppFlags {
  AppFlags({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Harita rehber turu tamamlandı/atlandı mı.
  static const seenMapTour = 'vivido.flag.map-tour';

  /// POI'ye dokunma ipucu kapatıldı mı.
  static const seenPoiHint = 'vivido.flag.poi-hint';

  Future<bool> isSet(String key) async {
    try {
      return await _storage.read(key: key) == '1';
    } on Object {
      // Güvenli depo bazı cihazlarda (Android yedekten geri yükleme sonrası)
      // çözülemeyen bir değer bulup fırlatıyor. Bayrak okunamazsa "görülmedi"
      // saymak, kullanıcıya turu bir kez fazla göstermek demek — çökmekten
      // iyi.
      return false;
    }
  }

  Future<void> set(String key) async {
    try {
      await _storage.write(key: key, value: '1');
    } on Object {
      // Yazamazsak tur bir sonraki açılışta yine çıkar. Kullanıcıyı bir
      // hata mesajıyla rahatsız etmeye değmez.
    }
  }

  Future<void> clear(String key) async {
    try {
      await _storage.delete(key: key);
    } on Object {
      // Yukarıdaki gerekçe.
    }
  }
}
