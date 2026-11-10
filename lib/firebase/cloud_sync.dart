import '../local/match_local_store.dart';
import '../local/user_local_store.dart';

/// What the cloud holds for a player's matches.
class CloudMatches {
  const CloudMatches(this.matches, this.cancelled);

  /// Matches the player is in, and public ones.
  final List<LocalMatch> matches;

  /// Codes of matches that were cancelled.
  final Set<String> cancelled;
}

/// Copies the phone's data to the cloud and back. The phone (SQFlite) stays the main
/// copy, so every call is best effort: it never throws and the app keeps
/// working offline.
abstract class CloudSync {
  /// The signed-in player's profile as saved in the cloud, or null when there
  /// is none or the phone is offline. Used to restore it on a new phone.
  Future<Map<String, dynamic>?> pullProfile();

  Future<void> pushProfile(LocalUser user);

  Future<void> pushMatch(LocalMatch match);

  /// The player's matches and the public ones, or null when the phone is
  /// offline.
  Future<CloudMatches?> pullMatches(String uid);

  /// One match by code. [cancelled] is true when it was cancelled; [match] is
  /// null when it does not exist or the phone is offline.
  Future<({LocalMatch? match, bool cancelled})> fetchMatch(String code);

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
  Future<CloudMatches?> pullMatches(String uid) async => null;

  @override
  Future<({LocalMatch? match, bool cancelled})> fetchMatch(String code) async =>
      (match: null, cancelled: false);

  @override
  Future<void> deleteMatch(String code) async {}
}
