import 'dart:async';
import 'dart:convert';

import 'package:backend/app.dart';
import 'package:backend/database.dart';
import 'package:backend/live_hub.dart';
import 'package:shelf/shelf.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'server_test.dart' show decode, register, sendRequest;

const _secret = 'test-secret-with-at-least-32-characters-long';

class FakeWebSocketChannel extends StreamChannelMixin implements WebSocketChannel {
  FakeWebSocketChannel(this._inController, this._outController);
  final StreamController<dynamic> _inController;
  final StreamController<dynamic> _outController;

  @override
  Stream get stream => _inController.stream;

  @override
  WebSocketSink get sink => _FakeWebSocketSink(_outController);

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._controller);
  final StreamController<dynamic> _controller;

  @override
  void add(dynamic data) => _controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);

  @override
  Future addStream(Stream stream) => _controller.addStream(stream);

  @override
  Future close([int? closeCode, String? closeReason]) => _controller.close();

  @override
  Future get done => _controller.done;
}

void main() {
  late AppDatabase database;
  late Handler app;

  setUp(() {
    database = AppDatabase(':memory:');
    app = createApp(database: database, jwtSecret: _secret);
  });

  tearDown(() => database.close());

  int seedTournament({
    String name = 'Stats Cup',
    String status = 'active',
    int? createdBy,
  }) {
    database.db.execute(
      '''
        INSERT INTO tournaments
          (name, description, format, status, start_date, end_date,
           max_teams, location, prize, created_by)
        VALUES (?, 'Tournament description.', 'league', ?, '2026-11-01T10:00:00Z',
          '2026-11-30T18:00:00Z', 4, 'Stadium', 'Gold', ?)
      ''',
      [name, status, createdBy],
    );
    return database.db.lastInsertRowId;
  }

  int seedTeam(int tournamentId, int captainId, String name) {
    database.db.execute(
      '''
        INSERT INTO tournament_teams (tournament_id, captain_id, name, status)
        VALUES (?, ?, ?, 'active')
      ''',
      [tournamentId, captainId, name],
    );
    return database.db.lastInsertRowId;
  }

  int seedMatch({
    required int tournamentId,
    required int homeTeamId,
    required int awayTeamId,
    int? homeScore,
    int? awayScore,
    int? winnerTeamId,
    String status = 'played',
  }) {
    database.db.execute(
      '''
        INSERT INTO tournament_matches
          (tournament_id, home_team_id, away_team_id, home_score, away_score,
           winner_team_id, status)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        tournamentId,
        homeTeamId,
        awayTeamId,
        homeScore,
        awayScore,
        winnerTeamId,
        status,
      ],
    );
    return database.db.lastInsertRowId;
  }

  group('Feature 15: Tournament Stats', () {
    test('computes totals, top scorers and win rates', () async {
      final organizer = await register(app, 'organizer');
      final organizerToken = organizer['token'] as String;
      final orgId = (organizer['user'] as Map<String, dynamic>)['id'] as int;

      final p1 = await register(app, 'player1');
      final p1Id = (p1['user'] as Map<String, dynamic>)['id'] as int;

      final p2 = await register(app, 'player2');
      final p2Id = (p2['user'] as Map<String, dynamic>)['id'] as int;

      final tournamentId = seedTournament(createdBy: orgId);
      final teamA = seedTeam(tournamentId, p1Id, 'Lions');
      final teamB = seedTeam(tournamentId, p2Id, 'Tigers');

      // Match 1: Lions 3 - 1 Tigers (Lions won)
      seedMatch(
        tournamentId: tournamentId,
        homeTeamId: teamA,
        awayTeamId: teamB,
        homeScore: 3,
        awayScore: 1,
        winnerTeamId: teamA,
      );

      // Match 2: Tigers 2 - 2 Lions (Draw, Tigers won shootout)
      seedMatch(
        tournamentId: tournamentId,
        homeTeamId: teamB,
        awayTeamId: teamA,
        homeScore: 2,
        awayScore: 2,
        winnerTeamId: teamB,
      );

      final response = await sendRequest(
        app,
        'GET',
        '/tournaments/$tournamentId/stats',
        token: organizerToken,
      );
      expect(response.statusCode, 200);

      final data = await decode(response);

      // Totals
      final totals = data['tournamentTotals'] as Map<String, dynamic>;
      expect(totals['totalGoals'], 8);
      expect(totals['totalMatches'], 2);
      expect(totals['averageGoalsPerMatch'], 4.0);

      // Top scorers
      final topScorers = (data['topScorers'] as List).cast<Map<String, dynamic>>();
      expect(topScorers.length, 2);
      // Lions scored 3 + 2 = 5 goals. Tigers scored 1 + 2 = 3 goals.
      expect(topScorers.first['name'], 'Lions');
      expect(topScorers.first['goals'], 5);
      expect(topScorers[1]['name'], 'Tigers');
      expect(topScorers[1]['goals'], 3);

      // Win rates
      final winRates = data['winRates'] as Map<String, dynamic>;
      // Both played 2 matches and won 1 match => 50.0%
      expect(winRates[teamA.toString()], 50.0);
      expect(winRates[teamB.toString()], 50.0);
    });

    test('returns empty stats with zeroes when no matches played', () async {
      final user = await register(app, 'stats_user');
      final token = user['token'] as String;
      final tournamentId = seedTournament();

      final response = await sendRequest(
        app,
        'GET',
        '/tournaments/$tournamentId/stats',
        token: token,
      );
      expect(response.statusCode, 200);

      final data = await decode(response);
      final totals = data['tournamentTotals'] as Map<String, dynamic>;
      expect(totals['totalGoals'], 0);
      expect(totals['totalMatches'], 0);
      expect(totals['averageGoalsPerMatch'], 0.0);
      expect((data['topScorers'] as List), isEmpty);
      expect((data['winRates'] as Map), isEmpty);
    });
  });

  group('Feature 17: Live Tournament Updates', () {
    test('LiveTournamentHub tracks connections and broadcasts updates', () async {
      final hub = LiveTournamentHub();
      final inController = StreamController<dynamic>();
      final outController = StreamController<dynamic>();
      final channel = FakeWebSocketChannel(inController, outController);

      hub.addConnection(10, channel);
      expect(hub.connectionCount(10), 1);

      final received = <String>[];
      final sub = outController.stream.listen((msg) => received.add(msg as String));

      hub.broadcast(10, {
        'event': 'match_updated',
        'matchId': 42,
        'score': '2-1',
      });
      await pumpEventQueue();

      expect(received.length, 1);
      expect(jsonDecode(received.first)['score'], '2-1');

      await sub.cancel();
      await inController.close();
      await pumpEventQueue();
      expect(hub.connectionCount(10), 0);
    });
  });

  group('Feature 18: Notifications and Triggers', () {
    test('creates notifications for join, result, and request answers', () async {
      final organizer = await register(app, 'org_notif');
      final orgToken = organizer['token'] as String;
      final orgId = (organizer['user'] as Map<String, dynamic>)['id'] as int;

      final capA = await register(app, 'cap_a');
      final capAToken = capA['token'] as String;
      final capAId = (capA['user'] as Map<String, dynamic>)['id'] as int;

      final capB = await register(app, 'cap_b');
      final capBToken = capB['token'] as String;
      final capBId = (capB['user'] as Map<String, dynamic>)['id'] as int;

      final player = await register(app, 'player_x');
      final playerToken = player['token'] as String;

      // 1. Organizer creates tournament
      final tournamentId = seedTournament(status: 'upcoming', createdBy: orgId);

      // 2. Cap A joins tournament -> Organizer gets notification
      final joinRes = await sendRequest(
        app,
        'POST',
        '/tournaments/$tournamentId/join',
        token: capAToken,
        body: {'name': 'Team Alpha'},
      );
      expect(joinRes.statusCode, 200);

      // Check organizer notifications
      final orgNotifRes = await sendRequest(
        app,
        'GET',
        '/notifications',
        token: orgToken,
      );
      expect(orgNotifRes.statusCode, 200);
      final orgNotifData = await decode(orgNotifRes);
      expect(orgNotifData['unreadCount'], 1);
      final firstNotif = (orgNotifData['notifications'] as List).first as Map<String, dynamic>;
      expect(firstNotif['title'], 'New Team Joined');
      expect(firstNotif['isRead'], false);

      // Cap B joins
      await sendRequest(
        app,
        'POST',
        '/tournaments/$tournamentId/join',
        token: capBToken,
        body: {'name': 'Team Beta'},
      );

      // 3. Player requests to join Team Alpha -> Organizer gets notified
      final teams = database.db.select(
        'SELECT id, name FROM tournament_teams WHERE tournament_id = ? AND captain_id = ?',
        [tournamentId, capAId],
      );
      final teamAId = teams.first['id'] as int;

      final reqRes = await sendRequest(
        app,
        'POST',
        '/tournaments/$tournamentId/teams/$teamAId/request',
        token: playerToken,
      );
      expect(reqRes.statusCode, 201);

      // 4. Cap A accepts the join request -> Player gets notified
      final joinRequests = database.db.select(
        'SELECT id FROM join_requests WHERE tournament_id = ?',
        [tournamentId],
      );
      final requestId = joinRequests.first['id'] as int;

      final answerRes = await sendRequest(
        app,
        'PUT',
        '/tournaments/$tournamentId/requests/$requestId',
        token: capAToken,
        body: {'status': 'accepted'},
      );
      expect(answerRes.statusCode, 200);

      // Check player notifications
      final playerNotifRes = await sendRequest(
        app,
        'GET',
        '/notifications',
        token: playerToken,
      );
      expect(playerNotifRes.statusCode, 200);
      final playerNotifs = await decode(playerNotifRes);
      expect(playerNotifs['unreadCount'], 1);
      final pNotif = (playerNotifs['notifications'] as List).first as Map<String, dynamic>;
      expect(pNotif['title'], 'Join Request Accepted');
      expect(pNotif['isRead'], false);

      // Test marking notification as read
      final notifId = pNotif['id'] as int;
      final readRes = await sendRequest(
        app,
        'PUT',
        '/notifications/$notifId/read',
        token: playerToken,
      );
      expect(readRes.statusCode, 200);

      final playerNotifRes2 = await sendRequest(
        app,
        'GET',
        '/notifications',
        token: playerToken,
      );
      final playerNotifs2 = await decode(playerNotifRes2);
      expect(playerNotifs2['unreadCount'], 0);

      // 5. Match result recorded -> Both captains get notified
      // Switch tournament to active
      database.db.execute(
        "UPDATE tournaments SET status = 'active' WHERE id = ?",
        [tournamentId],
      );
      final teamsB = database.db.select(
        'SELECT id FROM tournament_teams WHERE tournament_id = ? AND captain_id = ?',
        [tournamentId, capBId],
      );
      final teamBId = teamsB.first['id'] as int;

      final matchId = seedMatch(
        tournamentId: tournamentId,
        homeTeamId: teamAId,
        awayTeamId: teamBId,
        status: 'scheduled',
      );

      final recordRes = await sendRequest(
        app,
        'POST',
        '/tournaments/$tournamentId/matches/$matchId/result',
        token: orgToken,
        body: {'homeScore': 2, 'awayScore': 1},
      );
      expect(recordRes.statusCode, 200);

      // Verify captain A and captain B received match result notification
      final capANotifs = await decode(
        await sendRequest(app, 'GET', '/notifications', token: capAToken),
      );
      final capBNotifs = await decode(
        await sendRequest(app, 'GET', '/notifications', token: capBToken),
      );
      expect(
        (capANotifs['notifications'] as List)
            .any((n) => n['title'] == 'Match Result Recorded'),
        isTrue,
      );
      expect(
        (capBNotifs['notifications'] as List)
            .any((n) => n['title'] == 'Match Result Recorded'),
        isTrue,
      );
    });
  });
}
