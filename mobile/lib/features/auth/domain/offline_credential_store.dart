import '../../../../core/models/models.dart';

abstract interface class OfflineCredentialStore {
  Future<void> enroll({
    required String email,
    required String password,
    required AuthSession session,
  });

  Future<bool> hasEnrollment(String email);

  Future<AuthSession?> unlock({
    required String email,
    required String password,
  });
}

class DisabledOfflineCredentialStore implements OfflineCredentialStore {
  const DisabledOfflineCredentialStore();

  @override
  Future<void> enroll({
    required String email,
    required String password,
    required AuthSession session,
  }) async {}

  @override
  Future<bool> hasEnrollment(String email) async => false;

  @override
  Future<AuthSession?> unlock({
    required String email,
    required String password,
  }) async => null;
}
