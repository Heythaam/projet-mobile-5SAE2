import 'dart:async';

import '../../bd/challenge_database.dart';
import '../../entities/challenge/challenge_model.dart';
import '../../entities/challenge/team_model.dart';
import 'challenge_cloud.dart';

abstract class ChallengeRepository {
  Future<List<Challenge>> getCreatedChallenges(int userId);
  Future<List<Challenge>> getJoinedChallenges(int userId);
  Future<List<Challenge>> getBrowseChallenges(int userId);
  Future<List<Team>> getLocalTeams();
  Future<Challenge> createChallenge(Challenge challenge);
  Future<bool> updateChallenge(Challenge challenge);
  Future<bool> deleteChallenge(int challengeId, int userId);
  Future<bool> joinChallenge(int challengeId, int userId);
  Future<bool> leaveChallenge(int challengeId, int userId);
  Future<Challenge?> findByJoinCode(String code, int userId);
  Future<String> generateUniqueJoinCode();
}

/// Challenges kept in SQFlite on the phone and copied to the cloud.
///
/// Reads come from the phone; before the lists are read the challenges other
/// phones saved are pulled in (at most every 20 seconds). Changes go to the
/// phone first and are then sent to the cloud. Demo challenges (sample and
/// built-in ones) stay on the phone.
class SqliteChallengeRepository implements ChallengeRepository {
  SqliteChallengeRepository([
    ChallengeDatabase? db,
    ChallengeCloud cloud = const NoopChallengeCloud(),
  ]) : _db = db ?? ChallengeDatabase(),
       _cloud = cloud;

  final ChallengeDatabase _db;
  final ChallengeCloud _cloud;
  DateTime? _lastSync;

  static bool _isDemo(int creatorId) =>
      (creatorId >= 997 && creatorId <= 999) ||
      (creatorId >= 9000 && creatorId < 10000);

  Future<void> _push(Challenge challenge) async {
    if (_isDemo(challenge.createdByUserId)) return;
    final id = challenge.id;
    final players = id == null
        ? [challenge.createdByUserId]
        : await _db.participantsOf(id);
    await _cloud.push(challenge, players);
  }

  Future<void> _pushById(int id) async {
    final fresh = await _db.getById(id);
    if (fresh != null) await _push(fresh);
  }

  Future<void> _sync(int userId) async {
    if (userId <= 0) return;
    final last = _lastSync;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 20)) {
      return;
    }
    try {
      final remote = await _cloud.pull(userId);
      if (remote == null) return;
      _lastSync = DateTime.now();
      for (final code in remote.cancelled) {
        await _db.deleteByJoinCode(code);
      }
      final inCloud = <String>{};
      for (final item in remote.challenges) {
        inCloud.add(item.challenge.joinCode);
        try {
          await _db.upsertFromCloud(item.challenge, item.participants);
        } catch (_) {
          // One bad cloud record must not stop the others.
        }
      }
      // Challenges made offline that the cloud has not seen yet.
      for (final mine in await _db.getCreatedChallenges(userId)) {
        if (!inCloud.contains(mine.joinCode) &&
            !remote.cancelled.contains(mine.joinCode)) {
          unawaited(_push(mine));
        }
      }
    } catch (_) {}
  }

  @override
  Future<List<Challenge>> getCreatedChallenges(int userId) async {
    await _sync(userId);
    return _db.getCreatedChallenges(userId);
  }

  @override
  Future<List<Challenge>> getJoinedChallenges(int userId) async {
    await _sync(userId);
    return _db.getJoinedChallenges(userId);
  }

  @override
  Future<List<Challenge>> getBrowseChallenges(int userId) async {
    await _sync(userId);
    return _db.getBrowseChallenges(userId);
  }

  @override
  Future<List<Team>> getLocalTeams() => _db.getTeams();

  @override
  Future<Challenge> createChallenge(Challenge challenge) async {
    final id = await _db.insertChallenge(challenge);
    final created = challenge.copyWith(
      id: id,
      isJoined: true,
      isCreatedByMe: true,
    );
    unawaited(_push(created));
    return created;
  }

  @override
  Future<bool> updateChallenge(Challenge challenge) async {
    final ok = await _db.updateChallenge(challenge);
    final id = challenge.id;
    if (ok && id != null) unawaited(_pushById(id));
    return ok;
  }

  @override
  Future<bool> deleteChallenge(int challengeId, int userId) async {
    final known = await _db.getById(challengeId);
    final ok = await _db.deleteChallenge(challengeId, userId);
    if (ok && known != null && !_isDemo(known.createdByUserId)) {
      unawaited(_cloud.cancel(known.joinCode));
    }
    return ok;
  }

  @override
  Future<bool> joinChallenge(int challengeId, int userId) async {
    final local = await _db.getById(challengeId);
    if (local != null && !_isDemo(local.createdByUserId)) {
      // Another player may have joined since this phone last looked.
      final remote = await _cloud.fetch(local.joinCode);
      if (remote.cancelled) {
        await _db.deleteByJoinCode(local.joinCode);
        return false;
      }
      final shared = remote.challenge;
      if (shared != null) {
        await _db.upsertFromCloud(shared.challenge, shared.participants);
      }
    }
    final ok = await _db.joinChallenge(challengeId, userId);
    if (ok) unawaited(_pushById(challengeId));
    return ok;
  }

  @override
  Future<bool> leaveChallenge(int challengeId, int userId) async {
    final ok = await _db.leaveChallenge(challengeId, userId);
    if (ok) unawaited(_pushById(challengeId));
    return ok;
  }

  @override
  Future<Challenge?> findByJoinCode(String code, int userId) async {
    final remote = await _cloud.fetch(code.trim().toUpperCase());
    if (remote.cancelled) {
      await _db.deleteByJoinCode(code);
      return null;
    }
    final shared = remote.challenge;
    if (shared != null) {
      await _db.upsertFromCloud(shared.challenge, shared.participants);
    }
    return _db.findByJoinCode(code, userId);
  }

  @override
  Future<String> generateUniqueJoinCode() => _db.generateUniqueJoinCode();
}
