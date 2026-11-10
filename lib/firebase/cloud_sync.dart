import '../local/match_local_store.dart';
import '../local/user_local_store.dart';

/// Copies the phone's data to the cloud and back. The phone (SQFlite) stays the main
/// copy, so every call is best effort: it never throws and the app keeps
/// working offline.
abstract class CloudSync {
  /// The signed-in player's profile as saved in the cloud, or null when there
  /// is none or the phone is offline. Used to restore it on a new phone.
  Future<Map<String, dynamic>?> pullProfile();

  Future<void> pushProfile(LocalUser user);

  Future<void> pushMatch(LocalMatch match);

  Future<void> deleteMatch(String code);
}

/// Used in tests and when Firebase could not start.
class NoopCloudSync implements CloudSync {
  const NoopCloudSync();

  @override
  Future<Map<String, dynamic>?> pullProfile() async => null;

  @override
  Future<void> pushProfile(LocalUser user) async {}

  @override
  Future<void> pushMatch(LocalMatch match) async {}

  @override
  Future<void> deleteMatch(String code) async {}
}
