import '../local/match_local_store.dart';
import '../local/user_local_store.dart';

/// Copies the phone's data to the cloud. The phone (SQFlite) stays the main
/// copy, so every call is best effort: it never throws and the app keeps
/// working offline.
abstract class CloudSync {
  /// Signs in to the cloud with the same email and password as the account,
  /// creating the cloud account the first time.
  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> pushProfile(LocalUser user);

  Future<void> pushMatch(LocalMatch match);

  Future<void> deleteMatch(String code);
}

/// Used in tests and when Firebase could not start.
class NoopCloudSync implements CloudSync {
  const NoopCloudSync();

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> pushProfile(LocalUser user) async {}

  @override
  Future<void> pushMatch(LocalMatch match) async {}

  @override
  Future<void> deleteMatch(String code) async {}
}
