import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api_client.dart';
import '../../bd/core_database.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../entities/tournament/bracket.dart';
import '../../entities/tournament/player_profile.dart';
import '../../entities/tournament/tournament_notification.dart';
import '../../entities/tournament/tournament_stats.dart';
import '../../entities/tournament/team_details.dart';
import '../../entities/tournament/tournament.dart';
import '../../items/tournament/tournament_constants.dart';

class TournamentException implements Exception {
  const TournamentException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// API reason code, see [TournamentErrorCodes].
  final String? code;

  bool get requiresSignIn => statusCode == 401;

  @override
  String toString() => message;
}

/// Tournament API calls. Screens use this service and never touch HTTP
/// directly; the base URL and session token come from [ApiClient].
class TournamentService {
  const TournamentService(this._api);

  final ApiClient _api;

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
    final response = await _api.sendAuthenticated(
      'POST',
      TournamentEndpoints.LIST,
      body: {
        'name': name,
        'format': format,
        'startDate': startDate,
        'endDate': endDate,
        'maxTeams': maxTeams,
        'teamSize': teamSize,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (location != null && location.isNotEmpty) 'location': location,
        if (prize != null && prize.isNotEmpty) 'prize': prize,
      },
    );
    return Tournament.fromJson(
      response['tournament'] as Map<String, dynamic>,
    );
  });

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
    final response = await _api.sendAuthenticated(
      'PATCH',
      TournamentEndpoints.detail(id),
      body: {
        'name': ?name,
        'description': ?description,
        'location': ?location,
        'prize': ?prize,
        'startDate': ?startDate,
        'endDate': ?endDate,
        'status': ?status,
      },
    );
    return Tournament.fromJson(
      response['tournament'] as Map<String, dynamic>,
    );
  });

  Future<Tournament> updateTournamentStatus(int id, String status) =>
      editTournament(id, status: status);

  Future<void> recordMatchResult(
    int tournamentId,
    int matchId, {
    required int homeScore,
    required int awayScore,
    int? winnerId,
  }) => _guard(TournamentStrings.ERROR_RECORD_RESULT, () async {
    await _api.sendAuthenticated(
      'POST',
      TournamentEndpoints.matchResult(tournamentId, matchId),
      body: {
        'homeScore': homeScore,
        'awayScore': awayScore,
        'winnerId': ?winnerId,
      },
    );
  });

  Future<void> scheduleMatch(
    int tournamentId,
    int matchId, {
    DateTime? scheduledAt,
    String? location,
  }) => _guard(TournamentStrings.ERROR_SCHEDULE_MATCH, () async {
    await _api.sendAuthenticated(
      'PATCH',
      TournamentEndpoints.match(tournamentId, matchId),
      body: {
        'scheduledAt': ?scheduledAt?.toIso8601String(),
        'location': ?location,
      },
    );
  });

  Future<void> generateFixtures(int id) =>
      _guard(TournamentStrings.ERROR_GENERATE_FIXTURES, () async {
        await _api.sendAuthenticated(
          'POST',
          TournamentEndpoints.generateFixtures(id),
        );
      });

  Future<({List<Tournament> tournaments, bool hasMore})> getTournaments({
    TournamentStatus? status,
    int offset = 0,
  }) async {
    final params = <String>[];
    if (status != null) params.add('status=${status.apiValue}');
    if (offset > 0) params.add('offset=$offset');
    final path = params.isEmpty
        ? TournamentEndpoints.LIST
        : '${TournamentEndpoints.LIST}?${params.join('&')}';

    try {
      final response = await _guard(
        TournamentStrings.ERROR_LOAD_LIST,
        () => _api.sendAuthenticated('GET', path),
      );
      final rawTournaments = (response['tournaments'] as List<dynamic>? ?? const [])
          .map((item) => (item as Map).cast<String, dynamic>())
          .toList();

      if (offset == 0) {
        await LocalDatabase.instance.cacheTournaments(rawTournaments);
      }

      return (
        tournaments: rawTournaments
            .map((item) => Tournament.fromJson(item))
            .toList(),
        hasMore: response['hasMore'] as bool? ?? false,
      );
    } catch (e) {
      final cached = await LocalDatabase.instance.getCachedTournaments();
      if (cached.isNotEmpty) {
        var tournaments = cached
            .map((item) => Tournament.fromJson(item))
            .toList();
        if (status != null) {
          tournaments = tournaments.where((t) => t.status == status).toList();
        }
        return (
          tournaments: tournaments,
          hasMore: false,
        );
      }
      rethrow;
    }
  }

  Future<Tournament> getTournament(int id) async {
    try {
      final response = await _guard(
        TournamentStrings.ERROR_LOAD_DETAIL,
        () => _api.sendAuthenticated(
          'GET',
          TournamentEndpoints.detail(id),
        ),
      );
      final rawTournament =
          (response['tournament'] as Map).cast<String, dynamic>();
      await LocalDatabase.instance.cacheTournamentDetail(id, rawTournament);
      return Tournament.fromJson(rawTournament);
    } catch (e) {
      final cached = await LocalDatabase.instance.getCachedTournament(id);
      if (cached != null) {
        return Tournament.fromJson(cached);
      }
      rethrow;
    }
  }

  /// Registers the signed-in user as captain of a team named [teamName].
  Future<Tournament> joinTournament(int id, String teamName) =>
      _guard(TournamentStrings.ERROR_JOIN, () async {
        final response = await _api.sendAuthenticated(
          'POST',
          TournamentEndpoints.join(id),
          body: {'name': TeamName.normalize(teamName)},
        );
        return Tournament.fromJson(
          response['tournament'] as Map<String, dynamic>,
        );
      });

  /// Withdraws the signed-in user's team, or takes a player off their team;
  /// allowed before the tournament starts.
  Future<Tournament> leaveTournament(int id) =>
      _guard(TournamentStrings.ERROR_LEAVE, () async {
        final response = await _api.sendAuthenticated(
          'DELETE',
          TournamentEndpoints.join(id),
        );
        return Tournament.fromJson(
          response['tournament'] as Map<String, dynamic>,
        );
      });

  /// Withdraws the signed-in captain's team and frees its players.
  Future<Tournament> disbandTeam(int id) =>
      _guard(TournamentStrings.ERROR_DISBAND, () async {
        final response = await _api.sendAuthenticated(
          'DELETE',
          TournamentEndpoints.disband(id),
        );
        return Tournament.fromJson(
          response['tournament'] as Map<String, dynamic>,
        );
      });

  /// Makes [newCaptainId], a player of the signed-in captain's team, its
  /// captain. The former captain stays on the team as a player.
  Future<Tournament> transferCaptaincy(int id, int newCaptainId) =>
      _guard(TournamentStrings.ERROR_TRANSFER, () async {
        final response = await _api.sendAuthenticated(
          'POST',
          TournamentEndpoints.transferCaptaincy(id),
          body: {'newCaptainId': newCaptainId},
        );
        return Tournament.fromJson(
          response['tournament'] as Map<String, dynamic>,
        );
      });

  /// Stops reporting that the user's team was disbanded, on every device.
  Future<void> dismissDisbandNotice(int id) =>
      _guard(TournamentStrings.ERROR_DISMISS_NOTICE, () async {
        await _api.sendAuthenticated(
          'DELETE',
          TournamentEndpoints.disbandNotice(id),
        );
      });

  /// Stops reporting that the user was removed from a team, on every device.
  Future<void> dismissRemovedNotice(int id) =>
      _guard(TournamentStrings.ERROR_DISMISS_NOTICE, () async {
        await _api.sendAuthenticated(
          'DELETE',
          TournamentEndpoints.removedNotice(id),
        );
      });

  /// Asks the captain of [teamId] to let the signed-in user play for it.
  Future<Tournament> requestToJoinTeam(int id, int teamId) =>
      _guard(TournamentStrings.ERROR_REQUEST, () async {
        final response = await _api.sendAuthenticated(
          'POST',
          TournamentEndpoints.teamRequest(id, teamId),
        );
        return Tournament.fromJson(
          response['tournament'] as Map<String, dynamic>,
        );
      });

  /// Pending requests to the signed-in captain's team, oldest first.
  Future<List<TeamJoinRequest>> getJoinRequests(int id) => _guard(
    TournamentStrings.ERROR_LOAD_REQUESTS,
    () async {
      final response = await _api.sendAuthenticated(
        'GET',
        TournamentEndpoints.requests(id),
      );
      return (response['requests'] as List<dynamic>)
          .map((item) => TeamJoinRequest.fromJson(item as Map<String, dynamic>))
          .toList();
    },
  );

  /// Accepts or declines a request to the signed-in captain's team.
  Future<TeamJoinRequest> answerJoinRequest(
    int id,
    int requestId, {
    required bool accept,
  }) => _guard(TournamentStrings.ERROR_ANSWER, () async {
    final response = await _api.sendAuthenticated(
      'PUT',
      TournamentEndpoints.request(id, requestId),
      body: {
        'status': accept
            ? JoinRequestStatus.accepted.apiValue
            : JoinRequestStatus.declined.apiValue,
      },
    );
    return TeamJoinRequest.fromJson(
      response['request'] as Map<String, dynamic>,
    );
  });

  /// Total requests waiting for the signed-in captain in open tournaments.
  Future<int> getPendingRequestCount() =>
      _guard(TournamentStrings.ERROR_PENDING_COUNT, () async {
        final response = await _api.sendAuthenticated(
          'GET',
          TournamentEndpoints.PENDING_REQUESTS,
        );
        return response['pendingRequests'] as int;
      });

  Future<TeamDetails> getTeam(int id, int teamId) =>
      _guard(TournamentStrings.ERROR_LOAD_TEAM, () async {
        final response = await _api.sendAuthenticated(
          'GET',
          TournamentEndpoints.team(id, teamId),
        );
        return TeamDetails.fromJson(response['team'] as Map<String, dynamic>);
      });

  /// Removes a player from the signed-in captain's team.
  Future<TeamDetails> removePlayer(int id, int teamId, int playerId) =>
      _guard(TournamentStrings.ERROR_REMOVE, () async {
        final response = await _api.sendAuthenticated(
          'DELETE',
          TournamentEndpoints.member(id, teamId, playerId),
        );
        return TeamDetails.fromJson(response['team'] as Map<String, dynamic>);
      });

  Future<PlayerProfile> getPlayerProfile(int userId) =>
      _guard(TournamentStrings.ERROR_LOAD_PROFILE, () async {
        final response = await _api.sendAuthenticated(
          'GET',
          TournamentEndpoints.profile(userId),
        );
        return PlayerProfile.fromJson(
          response['profile'] as Map<String, dynamic>,
        );
      });

  Future<List<StandingRow>> getStandings(int id) async {
    try {
      final response = await _guard(
        TournamentStrings.ERROR_LOAD_STANDINGS,
        () => _api.sendAuthenticated(
          'GET',
          TournamentEndpoints.standings(id),
        ),
      );
      final rawStandings = response['standings'] as List<dynamic>? ?? const [];
      await LocalDatabase.instance.cacheJson('standings_$id', rawStandings);
      return rawStandings
          .map((item) => StandingRow.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort(_byGroupThenPosition);
    } catch (e) {
      final cached = await LocalDatabase.instance.getCachedJson('standings_$id');
      if (cached is List<dynamic> && cached.isNotEmpty) {
        return cached
            .map((item) => StandingRow.fromJson(item as Map<String, dynamic>))
            .toList()
          ..sort(_byGroupThenPosition);
      }
      rethrow;
    }
  }

  /// Knockout rounds with every slot; empty until the draw is made.
  Future<List<BracketRound>> getBracket(int id) async {
    try {
      final response = await _guard(
        TournamentStrings.ERROR_LOAD_BRACKET,
        () => _api.sendAuthenticated(
          'GET',
          TournamentEndpoints.bracket(id),
        ),
      );
      final bracket = response['bracket'] as Map<String, dynamic>;
      final rawRounds = bracket['rounds'] as List<dynamic>? ?? const [];
      await LocalDatabase.instance.cacheJson('bracket_$id', rawRounds);
      return rawRounds
          .map((item) => BracketRound.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final cached = await LocalDatabase.instance.getCachedJson('bracket_$id');
      if (cached is List<dynamic> && cached.isNotEmpty) {
        return cached
            .map((item) => BracketRound.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  Future<TournamentStats> getTournamentStats(int id) async {
    try {
      final response = await _guard(
        TournamentStrings.ERROR_LOAD_STATS,
        () => _api.sendAuthenticated(
          'GET',
          TournamentEndpoints.stats(id),
        ),
      );
      await LocalDatabase.instance.cacheJson('stats_$id', response);
      return TournamentStats.fromJson(response);
    } catch (e) {
      final cached = await LocalDatabase.instance.getCachedJson('stats_$id');
      if (cached is Map<String, dynamic>) {
        return TournamentStats.fromJson(cached);
      }
      rethrow;
    }
  }

  /// Connects to live match updates via WebSocket.
  Stream<dynamic> connectToLiveMatches(int id) {
    final uri = Uri.parse('${_api.wsBaseUrl}${TournamentEndpoints.live(id)}');
    final channel = WebSocketChannel.connect(uri);
    return channel.stream;
  }

  /// Lists recent notifications for the signed-in user.
  Future<List<TournamentNotification>> getNotifications() =>
      _guard(TournamentStrings.ERROR_LOAD_NOTIFICATIONS, () async {
        final response = await _api.sendAuthenticated(
          'GET',
          TournamentEndpoints.NOTIFICATIONS,
        );
        return (response['notifications'] as List<dynamic>? ?? const [])
            .map((item) =>
                TournamentNotification.fromJson(item as Map<String, dynamic>))
            .toList();
      });

  /// Marks a single notification as read.
  Future<void> markNotificationRead(int id) => _guard('', () async {
        await _api.sendAuthenticated(
          'PUT',
          TournamentEndpoints.notificationRead(id),
        );
      });

  /// Groups in label order (teams without a group last), then by position.
  static int _byGroupThenPosition(StandingRow left, StandingRow right) {
    final leftGroup = left.group;
    final rightGroup = right.group;
    if (leftGroup != rightGroup) {
      if (leftGroup == null) return 1;
      if (rightGroup == null) return -1;
      return leftGroup.compareTo(rightGroup);
    }
    return left.position.compareTo(right.position);
  }

  Future<T> _guard<T>(String fallback, Future<T> Function() request) async {
    try {
      return await request().timeout(TournamentEndpoints.REQUEST_TIMEOUT);
    } on ApiException catch (error) {
      // API errors carry messages written for players by the backend.
      throw TournamentException(
        error.message,
        statusCode: error.statusCode,
        code: error.code,
      );
    } on TimeoutException {
      throw const TournamentException(TournamentStrings.ERROR_TIMEOUT);
    } on FormatException catch (error) {
      debugPrint('Tournament response could not be parsed: $error');
      throw const TournamentException(TournamentStrings.ERROR_INVALID_RESPONSE);
    } on TypeError catch (error) {
      debugPrint('Tournament response had an unexpected shape: $error');
      throw const TournamentException(TournamentStrings.ERROR_INVALID_RESPONSE);
    } catch (error) {
      // Network failures can include host details; keep them out of the UI.
      debugPrint('Tournament request failed: $error');
      throw TournamentException(fallback);
    }
  }
}
