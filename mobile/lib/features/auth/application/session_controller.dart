import 'package:flutter/foundation.dart';

import '../../../core/models/models.dart';
import '../../../core/network/api_client.dart';

enum SessionPhase { booting, guest, onboarding, authenticated }

class SessionController extends ChangeNotifier {
  SessionController({required this.client, required this.repository});

  final ApiClient client;
  final VividoRepository repository;

  SessionPhase phase = SessionPhase.booting;
  UserProfile? profile;
  List<Persona> personas = const [];
  bool busy = false;
  String? errorMessage;

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
      errorMessage = 'Kayıtlı oturum açılamadı. Lütfen yeniden giriş yap.';
    }
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) =>
      _runAuthentication(
        () => client.login(email: email.trim(), password: password),
      );

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) => _runAuthentication(
    () => client.register(
      email: email.trim(),
      password: password,
      displayName: displayName,
    ),
  );

  Future<bool> _runAuthentication(
    Future<AuthSession> Function() operation,
  ) async {
    _setBusy(true);
    try {
      await operation();
      await _loadAfterAuthentication();
      errorMessage = null;
      return true;
    } on Object catch (error) {
      errorMessage = describeError(error);
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
      errorMessage = null;
      notifyListeners();
      return true;
    } on Object catch (error) {
      errorMessage = describeError(error);
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
    errorMessage = null;
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

  void clearError() {
    errorMessage = null;
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
