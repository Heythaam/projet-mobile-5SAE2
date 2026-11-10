// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../local/doc_store.dart';
import '../models/bracket.dart';
import '../models/player_profile.dart';
import '../models/team_details.dart';
import '../models/tournament.dart';
import '../models/tournament_notification.dart';
import '../models/tournament_stats.dart';
import '../tournament_constants.dart';
import 'tournament_rules.dart';
import 'tournament_store.dart';
import '../services/tournament_service.dart';

typedef TournamentCache = Future<DocStore> Function();

/// Tournaments in Firestore with a copy on the phone in SQFlite.
///
/// The rules the Dart server used to apply (who may join, team limits,
/// requests, captaincy) run here on one tournament document at a time, saved
/// in a Firestore transaction. Lists and details are saved on the phone and
/// read from there when there is no connection; changes need a connection.
class FirestoreTournamentService implements TournamentService {
  FirestoreTournamentService({
    required this.meId,
    required this.meName,
    required TournamentStore store,
    TournamentCache? cache,
  }) : _store = store,
       _cache = cache;

  final int meId;
  final String meName;
  final TournamentStore _store;
  final TournamentCache? _cache;

  static const _collection = 'tournaments';
  static const _listLimit = 100;
  static const _statusOrder = {
    'active': 0,
    'upcoming': 1,
    'finished': 2,
    'cancelled': 3,
  };

  // ---- Helpers -----------------------------------------------------------

  Tournament _detail(Doc doc) =>
      Tournament.fromJson(TournamentRules.detail(doc, meId));

  Future<Doc> _change(int id, void Function(Doc doc) change) =>
      _store.mutate(id, change);

  Future<void> _remember(Doc doc) async {
    final open = _cache;
    if (open == null) return;
    try {
      await (await open()).put(_collection, '${doc['id']}', doc);
    } catch (_) {}
  }

  Future<void> _rememberAll(List<Doc> docs) async {
    final open = _cache;
    if (open == null) return;
    try {
      await (await open()).replaceAll(_collection, {
        for (final doc in docs) '${doc['id']}': doc,
      });
    } catch (_) {}
  }

  Future<List<Doc>> _cachedAll() async {
    final open = _cache;
    if (open == null) return const [];
    try {
      return [
        for (final json in await (await open()).list(_collection))
          cloneDoc(json),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<Doc?> _cachedOne(int id) async {
    final open = _cache;
    if (open == null) return null;
    try {
      final json = await (await open()).get(_collection, '$id');
      return json == null ? null : cloneDoc(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _notify(
    int userId,
    String title,
    String body,
    int tournamentId,
  ) async {
    if (userId == meId) return;
    try {
      final now = DateTime.now();
      await _store.addNotification({
        'id': now.microsecondsSinceEpoch,
        'userId': userId,
        'title': title,
        'body': body,
        'isRead': false,
        'tournamentId': tournamentId,
        'createdAt': now.toUtc().toIso8601String(),
        'createdAtMs': now.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  Future<T> _guard<T>(String fallback, Future<T> Function() request) async {
    try {
      return await request().timeout(TournamentEndpoints.REQUEST_TIMEOUT);
    } on TournamentException {
      rethrow;
    } on TournamentMissing {
      throw const TournamentException(
        'Tournament not found.',
        statusCode: 404,
      );
    } on TimeoutException {
      throw const TournamentException(TournamentStrings.ERROR_TIMEOUT);
    } catch (error) {
      debugPrint('Tournament request failed: $error');
      throw TournamentException(fallback);
    }
  }

  // ---- Create and edit ---------------------------------------------------

  @override
  Future<Tournament> createTournament({
    required String name,
    required String format,
    required String startDate,
    required String endDate,
    required int maxTeams,
    required int teamSize,
    String? description,
    String? location,
    String? prize,
  }) => _guard(TournamentStrings.ERROR_CREATE, () async {
    final doc = await _store.create(
      (id) => TournamentRules.create(
        id: id,
        me: meId,
        myName: meName,
        name: name,
        format: format,
        startDate: startDate,
        endDate: endDate,
        maxTeams: maxTeams,
        teamSize: teamSize,
        description: description,
        location: location,
        prize: prize,
      ),
    );
    await _remember(doc);
    return _detail(doc);
  });

  @override
  Future<Tournament> editTournament(
    int id, {
    String? name,
    String? description,
    String? location,
    String? prize,
    String? startDate,
    String? endDate,
    String? status,
  }) => _guard(TournamentStrings.ERROR_EDIT, () async {
    final doc = await _change(
      id,
      (doc) => TournamentRules.edit(
        doc,
        meId,
        name: name,
        description: description,
        location: location,
        prize: prize,
        startDate: startDate,
        endDate: endDate,
        status: status,
      ),
    );
    await _remember(doc);
    return _detail(doc);
  });

  @override
  Future<Tournament> updateTournamentStatus(int id, String status) =>
      editTournament(id, status: status);

  // ---- Reading -----------------------------------------------------------

  @override
  Future<({List<Tournament> tournaments, bool hasMore})> getTournaments({
    TournamentStatus? status,
    int offset = 0,
  }) async {
    List<Doc> docs;
    try {
      docs = await _store.all().timeout(TournamentEndpoints.REQUEST_TIMEOUT);
      await _rememberAll(docs);
    } catch (error) {
      docs = await _cachedAll();
      if (docs.isEmpty) {
        debugPrint('Tournament list failed: $error');
        throw const TournamentException(TournamentStrings.ERROR_LOAD_LIST);
      }
    }
    final wanted = status?.apiValue;
    final shown = [
      for (final doc in docs)
        if (wanted == null || doc['status'] == wanted) doc,
    ];
    shown.sort((a, b) {
      final byStatus = _statusOrder[a['status']]!.compareTo(
        _statusOrder[b['status']]!,
      );
      if (byStatus != 0) return byStatus;
      final byStart = (a['startDate'] as String).compareTo(
        b['startDate'] as String,
      );
      return byStart != 0
          ? byStart
          : (a['id'] as int).compareTo(b['id'] as int);
    });
    final page = shown.skip(offset).take(_listLimit + 1).toList();
    final hasMore = page.length > _listLimit;
    return (
      tournaments: [
        for (final doc in page.take(_listLimit))
          Tournament.fromJson(TournamentRules.summary(doc, meId)),
      ],
      hasMore: hasMore,
    );
  }

  @override
  Future<Tournament> getTournament(int id) async {
    try {
      final doc = await _store
          .get(id)
          .timeout(TournamentEndpoints.REQUEST_TIMEOUT);
      if (doc == null) {
        throw const TournamentException(
          'Tournament not found.',
          statusCode: 404,
        );
      }
      await _remember(doc);
      return _detail(doc);
    } on TournamentException {
      rethrow;
    } catch (error) {
      final cached = await _cachedOne(id);
      if (cached != null) return _detail(cached);
      debugPrint('Tournament detail failed: $error');
      throw const TournamentException(TournamentStrings.ERROR_LOAD_DETAIL);
    }
  }

  // ---- Teams -------------------------------------------------------------

  @override
  Future<Tournament> joinTournament(int id, String teamName) =>
      _guard(TournamentStrings.ERROR_JOIN, () async {
        final doc = await _change(
          id,
          (doc) => TournamentRules.join(doc, meId, meName, teamName),
        );
        await _remember(doc);
        await _notify(
          doc['createdBy'] as int,
          'New Team Joined',
          'Team "${TeamName.normalize(teamName)}" joined ${doc['name']}.',
          id,
        );
        return _detail(doc);
      });

  @override
  Future<Tournament> leaveTournament(int id) =>
      _guard(TournamentStrings.ERROR_LEAVE, () async {
        final doc = await _change(
          id,
          (doc) => TournamentRules.leave(doc, meId, disband: false),
        );
        await _remember(doc);
        return _detail(doc);
      });

  @override
  Future<Tournament> disbandTeam(int id) =>
      _guard(TournamentStrings.ERROR_DISBAND, () async {
        final doc = await _change(
          id,
          (doc) => TournamentRules.leave(doc, meId, disband: true),
        );
        await _remember(doc);
        return _detail(doc);
      });

  @override
  Future<Tournament> transferCaptaincy(int id, int newCaptainId) =>
      _guard(TournamentStrings.ERROR_TRANSFER, () async {
        final doc = await _change(
          id,
          (doc) => TournamentRules.transferCaptaincy(doc, meId, newCaptainId),
        );
        await _remember(doc);
        return _detail(doc);
      });

  @override
  Future<void> dismissDisbandNotice(int id) =>
      _guard(TournamentStrings.ERROR_DISMISS_NOTICE, () async {
        await _change(
          id,
          (doc) => TournamentRules.dismissNotice(doc, meId, 'disbanded'),
        );
      });

  @override
  Future<void> dismissRemovedNotice(int id) =>
      _guard(TournamentStrings.ERROR_DISMISS_NOTICE, () async {
        await _change(
          id,
          (doc) => TournamentRules.dismissNotice(doc, meId, 'removed'),
        );
      });

  @override
  Future<Tournament> requestToJoinTeam(int id, int teamId) =>
      _guard(TournamentStrings.ERROR_REQUEST, () async {
        final doc = await _change(
          id,
          (doc) => TournamentRules.requestToJoin(doc, meId, meName, teamId),
        );
        await _remember(doc);
        await _notify(
          doc['createdBy'] as int,
          'New Join Request',
          'A player requested to join a team in ${doc['name']}.',
          id,
        );
        return _detail(doc);
      });

  @override
  Future<List<TeamJoinRequest>> getJoinRequests(int id) =>
      _guard(TournamentStrings.ERROR_LOAD_REQUESTS, () async {
        final doc = await _store.get(id);
        if (doc == null) throw const TournamentMissing();
        return [
          for (final json in TournamentRules.pendingRequests(doc, meId))
            TeamJoinRequest.fromJson(json.cast<String, dynamic>()),
        ];
      });

  @override
  Future<TeamJoinRequest> answerJoinRequest(
    int id,
    int requestId, {
    required bool accept,
  }) => _guard(TournamentStrings.ERROR_ANSWER, () async {
    final doc = await _change(
      id,
      (doc) => TournamentRules.answer(doc, meId, requestId, accept: accept),
    );
    await _remember(doc);
    final request = TournamentRules.list(
      doc,
      'requests',
    ).firstWhere((r) => r['id'] == requestId);
    final json = TournamentRules.requestJson(doc, request);
    await _notify(
      request['requester'] as int,
      accept ? 'Join Request Accepted' : 'Join Request Declined',
      'Your request to join ${json['teamName']} was '
          '${accept ? 'accepted' : 'declined'}.',
      id,
    );
    return TeamJoinRequest.fromJson(json.cast<String, dynamic>());
  });

  @override
  Future<int> getPendingRequestCount() =>
      _guard(TournamentStrings.ERROR_PENDING_COUNT, () async {
        final docs = await _store.all();
        return docs.fold<int>(
          0,
          (sum, doc) => sum + TournamentRules.openPendingFor(doc, meId),
        );
      });

  @override
  Future<TeamDetails> getTeam(int id, int teamId) =>
      _guard(TournamentStrings.ERROR_LOAD_TEAM, () async {
        final doc = await _store.get(id);
        if (doc == null) throw const TournamentMissing();
        return TeamDetails.fromJson(
          TournamentRules.teamDetail(doc, meId, teamId).cast<String, dynamic>(),
        );
      });

  @override
  Future<TeamDetails> removePlayer(int id, int teamId, int playerId) =>
      _guard(TournamentStrings.ERROR_REMOVE, () async {
        final doc = await _change(
          id,
          (doc) => TournamentRules.removePlayer(doc, meId, teamId, playerId),
        );
        await _remember(doc);
        return TeamDetails.fromJson(
          TournamentRules.teamDetail(doc, meId, teamId).cast<String, dynamic>(),
        );
      });

  @override
  Future<PlayerProfile> getPlayerProfile(int userId) =>
      _guard(TournamentStrings.ERROR_LOAD_PROFILE, () async {
        String? name;
        for (final doc in await _store.all()) {
          final names = doc['names'] as Map<String, dynamic>?;
          name ??= names?['$userId'] as String?;
        }
        if (name == null) {
          throw const TournamentException(
            'Player not found.',
            statusCode: 404,
          );
        }
        return PlayerProfile.fromJson({
          'id': userId,
          'username': name,
          'xp': 0,
          'level': 1,
          'rank': 'ROOKIE',
          'currentStreak': 0,
          'bestStreak': 0,
          'achievements': <Object?>[],
          'recentMatches': <Object?>[],
        });
      });

  // ---- Notifications -----------------------------------------------------

  @override
  Future<List<TournamentNotification>> getNotifications() =>
      _guard(TournamentStrings.ERROR_LOAD_NOTIFICATIONS, () async {
        return [
          for (final note in await _store.notifications(meId))
            TournamentNotification.fromJson(note),
        ];
      });

  @override
  Future<void> markNotificationRead(int id) => _guard('', () async {
    await _store.markNotificationRead(id);
  });

  // ---- Fixtures, results, tables (next step) ----------------------------

  static const _soon = TournamentException(
    'Fixtures and results are not available yet.',
  );

  @override
  Future<void> recordMatchResult(
    int tournamentId,
    int matchId, {
    required int homeScore,
    required int awayScore,
    int? winnerId,
  }) async => throw _soon;

  @override
  Future<void> scheduleMatch(
    int tournamentId,
    int matchId, {
    DateTime? scheduledAt,
    String? location,
  }) async => throw _soon;

  @override
  Future<void> generateFixtures(int id) async => throw _soon;

  @override
  Future<List<StandingRow>> getStandings(int id) async => const [];

  @override
  Future<List<BracketRound>> getBracket(int id) async => const [];

  @override
  Future<TournamentStats> getTournamentStats(int id) async =>
      TournamentStats.fromJson(const {});

  @override
  Stream<dynamic> connectToLiveMatches(int id) => const Stream.empty();
}
