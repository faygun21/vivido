import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Canlı konumun durumu.
///
/// Web'deki `UserLocationStatus` ile aynı fikir (bkz.
/// `web/src/shared/map/useUserLocation.ts`) ama mobile özgü iki ayrım var:
/// izin *kalıcı* olarak reddedilebiliyor ve cihazın konum servisi tamamen
/// kapalı olabiliyor. İkisi de kullanıcıya farklı şey söylemeyi gerektiriyor:
/// birinde ayarlara gitmesi gerekir, diğerinde konumu açması.
enum UserLocationStatus {
  /// Henüz istenmedi.
  idle,

  /// İzin/konum bekleniyor.
  locating,

  /// Koordinat elde.
  ready,

  /// Kullanıcı bu sefer reddetti — tekrar sorulabilir.
  denied,

  /// Kullanıcı "bir daha sorma" dedi. Sistem diyaloğu ARTIK AÇILMAZ;
  /// tek yol uygulama ayarları.
  deniedForever,

  /// Cihazın konum servisi kapalı.
  serviceDisabled,

  /// İzin var ama konum okunamadı (sinyal yok, zaman aşımı).
  unavailable,
}

class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
  });

  final double latitude;
  final double longitude;

  /// Yatay doğruluk (metre). Cihaz vermezse null.
  final double? accuracyM;
}

/// Canlı konumu ister ve durumunu tutar.
///
/// ⚠️ KONUM KENDİLİĞİNDEN İSTENMEZ. Uygulama açılır açılmaz izin diyaloğu
/// göstermek, kullanıcının neden sorulduğunu anlamadan reddetmesine yol
/// açıyor — ve bir kez "bir daha sorma" denince sistem diyaloğu bir daha
/// hiç açılmıyor. Bu yüzden konum yalnızca kullanıcı açıkça istediğinde
/// (rota başlangıcı olarak "Canlı konumum"u seçince ya da haritadaki konum
/// düğmesine basınca) isteniyor.
class UserLocationController extends ChangeNotifier {
  UserLocationStatus status = UserLocationStatus.idle;
  UserLocation? location;

  bool _disposed = false;
  bool _busy = false;

  /// Kullanıcıya gösterilecek açıklama. Durum sorunsuzsa null.
  String? get message => switch (status) {
    UserLocationStatus.denied =>
      'Konum izni verilmedi. Başlangıç noktası olarak bir adres seçebilir '
          'ya da tekrar deneyebilirsin.',
    UserLocationStatus.deniedForever =>
      'Konum izni kapalı. Telefon ayarlarından Vivido için konum iznini '
          'açman gerekiyor.',
    UserLocationStatus.serviceDisabled =>
      'Telefonun konum servisi kapalı. Açıp tekrar deneyebilirsin.',
    UserLocationStatus.unavailable =>
      'Konumun şu anda alınamadı. Sinyal zayıf olabilir; tekrar dene ya da '
          'başlangıç adresini seç.',
    _ => null,
  };

  /// İzin kalıcı olarak reddedildiyse ayarları açmaktan başka yol yok.
  bool get needsAppSettings => status == UserLocationStatus.deniedForever;

  /// Konumu ister. Zaten sürüyorsa yeni istek başlatmaz.
  Future<UserLocation?> request() async {
    if (_busy) return location;
    _busy = true;
    _set(UserLocationStatus.locating);

    try {
      // Servis kapalıyken izin istemek anlamsız: sistem diyaloğu açılır,
      // kullanıcı kabul eder ve konum yine gelmez.
      if (!await Geolocator.isLocationServiceEnabled()) {
        _set(UserLocationStatus.serviceDisabled);
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _set(UserLocationStatus.deniedForever);
        return null;
      }
      if (permission == LocationPermission.denied) {
        _set(UserLocationStatus.denied);
        return null;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            // Rota başlangıcı için sokak hassasiyeti yeterli. `best` istemek
            // GPS'i uzun süre çalıştırıp pili yiyor ve kapalı alanda hiç
            // dönmeyebiliyor.
            accuracy: LocationAccuracy.medium,
          ),
        ).timeout(const Duration(seconds: 15));
      } on Object {
        // Özellikle emülatör ve kapalı alanlarda fused provider ilk konumu
        // geç üretebilir. Kullanıcıyı gereksiz yere bloke etmemek için yalnızca
        // yakın zamanda alınmış son konumu kabul ediyoruz; eski bir koordinat
        // rota başlangıcı olarak kullanılmamalı.
        final cached = await Geolocator.getLastKnownPosition();
        final age =
            cached == null ? null : DateTime.now().difference(cached.timestamp);
        if (cached != null &&
            age != null &&
            age <= const Duration(minutes: 5)) {
          position = cached;
        } else {
          rethrow;
        }
      }

      location = UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
      );
      _set(UserLocationStatus.ready);
      return location;
    } on Object {
      // Zaman aşımı, sinyal yok, platform hatası… Kullanıcı açısından hepsi
      // aynı: konum gelmedi, adresle devam edebilir.
      _set(UserLocationStatus.unavailable);
      return null;
    } finally {
      _busy = false;
    }
  }

  /// Kalıcı reddedilmiş izin için uygulama ayarlarını açar.
  Future<void> openSettings() => Geolocator.openAppSettings();

  void _set(UserLocationStatus value) {
    status = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
