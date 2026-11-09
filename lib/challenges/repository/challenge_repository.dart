import '../database/challenge_database.dart';
import '../models/challenge_model.dart';
import '../models/team_model.dart';

abstract class ChallengeRepository {
  Future<List<Challenge>> getCreatedChallenges(int userId);
  Future<List<Challenge>> getJoinedChallenges(int userId);
  Future<List<Challenge>> getBrowseChallenges(int userId);
  Future<List<Team>> getLocalTeams();
  Future<Challenge> createChallenge(Challenge challenge);
  Future<bool> joinChallenge(int challengeId, int userId);
  Future<Challenge?> findByJoinCode(String code, int userId);
  Future<String> generateUniqueJoinCode();
}

class SqliteChallengeRepository implements ChallengeRepository {
  SqliteChallengeRepository([ChallengeDatabase? db])
      : _db = db ?? ChallengeDatabase();

  final ChallengeDatabase _db;

  @override
  Future<List<Challenge>> getCreatedChallenges(int userId) =>
      _db.getCreatedChallenges(userId);

  @override
  Future<List<Challenge>> getJoinedChallenges(int userId) =>
      _db.getJoinedChallenges(userId);

  @override
  Future<List<Challenge>> getBrowseChallenges(int userId) =>
      _db.getBrowseChallenges(userId);

  @override
  Future<List<Team>> getLocalTeams() => _db.getTeams();

  @override
  Future<Challenge> createChallenge(Challenge challenge) async {
    final id = await _db.insertChallenge(challenge);
    return challenge.copyWith(id: id, isJoined: true, isCreatedByMe: true);
  }

  @override
  Future<bool> joinChallenge(int challengeId, int userId) =>
      _db.joinChallenge(challengeId, userId);

  @override
  Future<Challenge?> findByJoinCode(String code, int userId) =>
      _db.findByJoinCode(code, userId);

  @override
  Future<String> generateUniqueJoinCode() => _db.generateUniqueJoinCode();
}
