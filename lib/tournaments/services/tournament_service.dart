import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../api_client.dart';
import '../models/bracket.dart';
import '../models/player_profile.dart';
import '../models/team_details.dart';
import '../models/tournament.dart';
import '../tournament_constants.dart';

class TournamentException implements Exception {
  const TournamentException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get requiresSignIn => statusCode == 401;

  @override
  String toString() => message;
}

/// Tournament API calls. Screens use this service and never touch HTTP
/// directly; the base URL and session token come from [ApiClient].
class TournamentService {
  const TournamentService(this._api);

  final ApiClient _api;

  Future<List<Tournament>> getTournaments({TournamentStatus? status}) async {
    final path = status == null
        ? TournamentEndpoints.LIST
        : '${TournamentEndpoints.LIST}?status=${status.apiValue}';
    return _guard(TournamentStrings.ERROR_LOAD_LIST, () async {
      final response = await _api.sendAuthenticated('GET', path);
      return (response['tournaments'] as List<dynamic>)
          .map((item) => Tournament.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Tournament> getTournament(int id) =>
      _guard(TournamentStrings.ERROR_LOAD_DETAIL, () async {
        final response = await _api.sendAuthenticated(
          'GET',
          TournamentEndpoints.detail(id),
        );
        return Tournament.fromJson(
          response['tournament'] as Map<String, dynamic>,
        );
      });

  /// Registers the signed-in user and returns the updated tournament.
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

  /// Withdraws the signed-in user's team; allowed before the tournament starts.
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

  Future<List<StandingRow>> getStandings(int id) =>
      _guard(TournamentStrings.ERROR_LOAD_STANDINGS, () async {
        final response = await _api.sendAuthenticated(
          'GET',
          TournamentEndpoints.standings(id),
        );
        return (response['standings'] as List<dynamic>)
            .map((item) => StandingRow.fromJson(item as Map<String, dynamic>))
            .toList()
          ..sort(_byGroupThenPosition);
      });

  /// Knockout rounds with every slot; empty until the draw is made.
  Future<List<BracketRound>> getBracket(int id) =>
      _guard(TournamentStrings.ERROR_LOAD_BRACKET, () async {
        final response = await _api.sendAuthenticated(
          'GET',
          TournamentEndpoints.bracket(id),
        );
        final bracket = response['bracket'] as Map<String, dynamic>;
        return (bracket['rounds'] as List<dynamic>)
            .map((item) => BracketRound.fromJson(item as Map<String, dynamic>))
            .toList();
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
      throw TournamentException(error.message, statusCode: error.statusCode);
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
