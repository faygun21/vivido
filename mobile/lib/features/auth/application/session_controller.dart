import 'package:flutter/foundation.dart';

import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';

/// Uygulamanın hangi ekranı gösterdiğini belirler.
///
/// `guest` ile `browsing` farkı önemli (W0):
///   · `guest`    → karşılama ekranı, henüz bir seçim yapılmadı
///   · `browsing` → "misafir olarak devam et" dendi; harita açık ama
///                  skor, persona ve anchor kilitli
enum SessionPhase { booting, guest, browsing, onboarding, authenticated }

class SessionController extends ChangeNotifier {
  SessionController({required this.client, required this.repository});

  final ApiClient client;
  final VividoRepository repository;

  SessionPhase phase = SessionPhase.booting;
  UserProfile? profile;
  List<Persona> personas = const [];
  bool busy = false;
  String? errorMessage;

  /// Son hatanın sözleşme kodu — arayüz `errorMessage` metnine göre DEĞİL
  /// buna göre dallanır (K-D). Örneğin `EMAIL_NOT_VERIFIED` gelince giriş
  /// ekranı kullanıcıyı doğrudan kod ekranına taşıyor.
  String? lastErrorCode;

  AuthUser? get user => client.session?.user;
  bool get isAuthenticated => client.session != null;

  Future<void> bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (phase != SessionPhase.booting) return;
    try {
      final restored = await client.restoreSession();
      if (restored == null) {
        phase = SessionPhase.guest;
      } else {
        await _loadAfterAuthentication();
      }
    } on Object {
      await client.logout();
      phase = SessionPhase.guest;
      lastErrorCode = null;
      errorMessage = 'Kayıtlı oturum açılamadı. Lütfen yeniden giriş yap.';
    }
    notifyListeners();
  }

  /// "Misafir olarak devam et" — kayıt olmadan haritayı gezmek (W0).
  void continueAsGuest() {
    if (isAuthenticated) return;
    _clearError();
    phase = SessionPhase.browsing;
    notifyListeners();
  }

  /// Misafir gezintisinden karşılama ekranına dön (giriş/kayıt için).
  void exitGuestBrowsing() {
    if (isAuthenticated) return;
    _clearError();
    phase = SessionPhase.guest;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) =>
      _runAuthentication(
        () => client.login(email: email.trim(), password: password),
      );

  /// Doğrulama bekleyen kayıt varsa e-posta adresi burada tutulur;
  /// kod ekranı adresi kullanıcıya ikinci kez yazdırmasın diye.
  String? pendingVerificationEmail;

  /// Kayıt olur.
  ///
  /// Dönen değer doğrulama ekranına geçilip geçilmeyeceğini söyler:
  /// `RegisterVerificationRequired` → kod ekranı, `RegisterAuthenticated`
  /// → doğrudan içeri (doğrulama kapalı), `null` → hata (bkz. [errorMessage]).
  Future<RegisterOutcome?> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _setBusy(true);
    try {
      final outcome = await client.register(
        email: email.trim(),
        password: password,
        displayName: displayName,
      );
      _clearError();

      switch (outcome) {
        case RegisterVerificationRequired(email: final pendingEmail):
          pendingVerificationEmail = pendingEmail;
        case RegisterAuthenticated():
          await _loadAfterAuthentication();
      }
      return outcome;
    } on Object catch (error) {
      _fail(error);
      return null;
    } finally {
      _setBusy(false);
    }
  }

  /// E-postaya gelen kodu doğrular; başarılıysa oturum açar (K-09).
  Future<bool> verifyEmail({required String email, required String code}) =>
      _runAuthentication(
        () => client.verifyEmail(email: email.trim(), code: code.trim()),
      );

  Future<String?> resendVerification(String email) =>
      _runMessage(() => client.resendVerification(email.trim()));

  Future<String?> forgotPassword(String email) =>
      _runMessage(() => client.forgotPassword(email.trim()));

  Future<String?> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _runMessage(
    () => client.resetPassword(
      email: email.trim(),
      code: code.trim(),
      newPassword: newPassword,
    ),
  );

  /// Bilgilendirme metni dönen uç noktalar için ortak sarmalayıcı.
  /// Başarılıysa mesajı, hata olursa `null` döner ([errorMessage] dolar).
  Future<String?> _runMessage(Future<String> Function() operation) async {
    _setBusy(true);
    try {
      final message = await operation();
      _clearError();
      return message;
    } on Object catch (error) {
      _fail(error);
      return null;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> _runAuthentication(
    Future<AuthSession> Function() operation,
  ) async {
    _setBusy(true);
    try {
      await operation();
      await _loadAfterAuthentication();
      _clearError();
      return true;
    } on Object catch (error) {
      _fail(error);
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _loadAfterAuthentication() async {
    try {
      profile = await repository.getProfile();
      phase = SessionPhase.authenticated;
      await ensurePersonas();
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.code == 'PROFILE_NOT_FOUND') {
        profile = null;
        phase = SessionPhase.onboarding;
        await ensurePersonas();
        return;
      }
      rethrow;
    }
  }

  Future<void> ensurePersonas() async {
    if (personas.isNotEmpty) return;
    personas = await repository.getPersonas();
    notifyListeners();
  }

  Future<bool> saveProfile({
    required String personaCode,
    double? monthlyBudget,
  }) async {
    _setBusy(true);
    try {
      profile = await repository.saveProfile(
        personaCode: personaCode,
        monthlyBudget: monthlyBudget,
      );
      _clearError();
      notifyListeners();
      return true;
    } on Object catch (error) {
      _fail(error);
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  void completeOnboarding() {
    if (profile == null) return;
    phase = SessionPhase.authenticated;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    profile = await repository.getProfile();
    notifyListeners();
  }

  Future<Anchor> createAnchor({
    required String label,
    required double lat,
    required double lon,
    required String mode,
  }) async {
    final anchor = await repository.createAnchor(
      label: label,
      lat: lat,
      lon: lon,
      mode: mode,
    );
    await refreshProfile();
    return anchor;
  }

  Future<void> deleteAnchor(String id) async {
    await repository.deleteAnchor(id);
    await refreshProfile();
  }

  Future<List<Anchor>> reorderAnchors(List<String> order) async {
    final anchors = await repository.reorderAnchors(order);
    final current = profile;
    if (current != null) profile = current.copyWith(anchors: anchors);
    notifyListeners();
    return anchors;
  }

  Future<void> logout() async {
    await client.logout();
    profile = null;
    personas = const [];
    _clearError();
    phase = SessionPhase.guest;
    notifyListeners();
  }

  String describeError(Object error) {
    if (error is ApiException) {
      switch (error.code) {
        case 'INVALID_CREDENTIALS':
          return 'E-posta veya parola hatalı.';
        case 'EMAIL_ALREADY_EXISTS':
          return 'Bu e-posta adresiyle bir hesap zaten var.';
        case 'EMAIL_NOT_VERIFIED':
          return 'E-posta adresin doğrulanmamış. Sana gönderdiğimiz kodu gir.';
        case 'INVALID_CODE':
          return 'Kod hatalı. E-postadaki 6 haneli kodu kontrol et.';
        case 'CODE_EXPIRED':
          return 'Kodun süresi doldu. Yeni bir kod iste.';
        case 'TOO_MANY_ATTEMPTS':
          return 'Çok fazla hatalı deneme yapıldı. Yeni bir kod iste.';
        case 'RESEND_TOO_SOON':
          return 'Çok sık kod istiyorsun. Bir dakika bekleyip tekrar dene.';
        case 'EMAIL_SEND_FAILED':
          return 'Doğrulama e-postası gönderilemedi. Birazdan tekrar dene.';
        case 'VALIDATION_ERROR':
          return error.detail ?? 'Gönderilen bilgiler geçersiz.';
        case 'ANCHOR_LIMIT_EXCEEDED':
          return 'En fazla 3 önemli konum ekleyebilirsin.';
        case 'PROFILE_NOT_FOUND':
          return 'Önce persona seçip profilini kaydet.';
        case 'REQUEST_TIMEOUT':
        case 'NETWORK_ERROR':
          return 'Sunucuya ulaşılamadı. API adresini ve bağlantını kontrol et.';
        default:
          return error.detail ?? error.title;
      }
    }
    return 'Beklenmeyen bir hata oluştu.';
  }

  /// Hata durumunu tek yerden yazar: mesaj + sözleşme kodu (K-D).
  void _fail(Object error) {
    lastErrorCode = error is ApiException ? error.code : null;
    errorMessage = describeError(error);
  }

  void _clearError() {
    errorMessage = null;
    lastErrorCode = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _setBusy(bool value) {
    busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}
