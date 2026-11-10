import '../../entities/challenge/challenge_model.dart';

/// A challenge as the cloud holds it, with the ids of the players in it.
class CloudChallenge {
  const CloudChallenge(this.challenge, this.participants);

  final Challenge challenge;
  final List<int> participants;
}

/// What the cloud holds for a player's challenges.
class CloudChallenges {
  const CloudChallenges(this.challenges, this.cancelled);

  /// Challenges the player is in, and open ones.
  final List<CloudChallenge> challenges;

  /// Join codes of challenges that were cancelled.
  final Set<String> cancelled;
}

/// The cloud copy of challenges. Every call is best effort and never throws:
/// the phone's SQFlite copy keeps working offline.
abstract class ChallengeCloud {
  Future<void> push(Challenge challenge, List<int> participants);

  Future<void> cancel(String joinCode);

  /// The player's challenges and the open ones, or null when offline.
  Future<CloudChallenges?> pull(int userId);

  /// One challenge by join code. [challenge] is null when it does not exist or
  /// the phone is offline.
  Future<({CloudChallenge? challenge, bool cancelled})> fetch(String joinCode);
}

/// Used in tests and when Firebase could not start.
class NoopChallengeCloud implements ChallengeCloud {
  const NoopChallengeCloud();

  @override
  Future<void> push(Challenge challenge, List<int> participants) async {}

  @override
  Future<void> cancel(String joinCode) async {}

  @override
  Future<CloudChallenges?> pull(int userId) async => null;

  @override
  Future<({CloudChallenge? challenge, bool cancelled})> fetch(
    String joinCode,
  ) async => (challenge: null, cancelled: false);
}
