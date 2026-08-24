abstract final class AppConfig {
  static const String appName = 'Vivido';

  /// Varsayılan hedef ORTAK STAGING'dir, geliştiricinin makinesi değil.
  ///
  /// Eskiden `http://10.0.2.2:5000/api/v1` (Android emülatörünün host
  /// loopback'i) idi. Sonucu: uygulama yalnızca APK'yı derleyen kişinin
  /// bilgisayarındaki API'ye bağlanıyordu — başka bir cihazda "sunucuya
  /// ulaşılamadı", webde açılan hesapla giriş yapılamıyordu. Oysa M1'in
  /// tanımı "web ile AYNI hesap" (K-11: tek sunucu, tek veritabanı).
  ///
  /// Ayrıca Android 9+ düz HTTP'yi varsayılan olarak engeller; `http://<IP>`
  /// yalnızca debug build'de çalışır, release APK'da sessizce ölür. HTTPS
  /// staging adresi bu tuzağı da kapatıyor.
  ///
  /// Yerelde çalışmak için derlerken ez:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1 \
  ///               --dart-define=TILE_BASE_URL=http://10.0.2.2:8080
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://vividoapp.xyz/api/v1',
  );

  static const String tileBaseUrl = String.fromEnvironment(
    'TILE_BASE_URL',
    defaultValue: 'https://vividoapp.xyz/tiles',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
