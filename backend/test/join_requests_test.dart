import 'package:backend/app.dart';
import 'package:backend/database.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'server_test.dart' show decode, register, sendRequest;

const _secret = 'test-secret-with-at-least-32-characters-long';

void main() {
  late AppDatabase database;
  late Handler app;

  setUp(() {
    database = AppDatabase(':memory:');
    app = createApp(database: database, jwtSecret: _secret);
  });

  tearDown(() => database.close());

  int seedTournament({String name = 'Sunday Cup', int teamSize = 3}) {
    database.db.execute(
      '''
        INSERT INTO tournaments
          (name, format, status, start_date, end_date, max_teams, team_size)
        VALUES (?, 'league', 'upcoming', '2026-11-01T10:00:00Z',
          '2026-11-30T18:00:00Z', 8, ?)
      ''',
      [name, teamSize],
    );
    return database.db.lastInsertRowId;
  }

  void setStatus(int tournamentId, String status) => database.db.execute(
    'UPDATE tournaments SET status = ? WHERE id = ?',
    [status, tournamentId],
  );

  Future<String> user(String username) async =>
      (await register(app, username))['token'] as String;

  /// Creates a team captained by [token] and returns the team id.
  Future<int> createTeam(String token, int tournamentId, String name) async {
    final response = await sendRequest(
      app,
      'POST',
      '/tournaments/$tournamentId/join',
      token: token,
      body: {'name': name},
    );
    expect(response.statusCode, 200);
    final teams = (await decode(response))['tournament']['teams'] as List;
    return (teams.last as Map<String, dynamic>)['id'] as int;
  }

  Future<Response> ask(String token, int tournamentId, int teamId) =>
      sendRequest(
        app,
        'POST',
        '/tournaments/$tournamentId/teams/$teamId/request',
        token: token,
      );

  Future<List<Map<String, dynamic>>> inbox(String token, int id) async {
    final response = await sendRequest(
      app,
      'GET',
      '/tournaments/$id/requests',
      token: token,
    );
    expect(response.statusCode, 200);
    return ((await decode(response))['requests'] as List)
        .cast<Map<String, dynamic>>();
  }

  Future<Response> answer(String token, int id, int requestId, String status) =>
      sendRequest(
        app,
        'PUT',
        '/tournaments/$id/requests/$requestId',
        token: token,
        body: {'status': status},
      );

  Future<Map<String, dynamic>> detail(String token, int id) async =>
      (await decode(
            await sendRequest(app, 'GET', '/tournaments/$id', token: token),
          ))['tournament']
          as Map<String, dynamic>;

  Future<String> errorOf(Response response) async =>
      (await decode(response))['error'] as String;

  test('request routes require a session', () async {
    final id = seedTournament();
    for (final (method, path) in [
      ('POST', '/tournaments/$id/teams/1/request'),
      ('GET', '/tournaments/$id/requests'),
      ('PUT', '/tournaments/$id/requests/1'),
    ]) {
      final response = await sendRequest(app, method, path);
      expect(response.statusCode, 401, reason: '$method $path');
    }
  });

  test('a captain accepts a request and the player joins the team', () async {
    final captain = await user('captain');
    final player = await user('player');
    final id = seedTournament();
    final teamId = await createTeam(captain, id, 'Red Lions');

    final sent = await ask(player, id, teamId);
    expect(sent.statusCode, 201);
    final pending = (await decode(sent))['tournament'];
    expect(pending['myRequests'], [
      {'teamId': teamId, 'status': 'pending'},
    ]);
    expect((await detail(captain, id))['pendingRequests'], 1);

    final requests = await inbox(captain, id);
    expect(requests.single['requesterName'], 'player');
    expect(requests.single['teamName'], 'Red Lions');
    expect(requests.single['requesterId'], isA<int>());

    final accepted = await answer(
      captain,
      id,
      requests.single['id'] as int,
      'accepted',
    );
    expect(accepted.statusCode, 200);
    expect((await decode(accepted))['request']['status'], 'accepted');

    final playerView = await detail(player, id);
    expect(playerView['myTeamId'], teamId);
    expect(playerView['joined'], isFalse);
    expect(playerView['teams'], [
      {'id': teamId, 'name': 'Red Lions', 'players': 2},
    ]);
    final captainView = await detail(captain, id);
    expect(captainView['pendingRequests'], 0);
    // Players would lose their team, so the captain cannot leave.
    expect(captainView['canLeave'], isFalse);
    final leave = await sendRequest(
      app,
      'DELETE',
      '/tournaments/$id/join',
      token: captain,
    );
    expect(leave.statusCode, 409);
    expect(await errorOf(leave), contains('players'));

    // Members can neither create a team nor ask another one.
    final ownTeam = await sendRequest(
      app,
      'POST',
      '/tournaments/$id/join',
      token: player,
      body: {'name': 'Solo FC'},
    );
    expect(ownTeam.statusCode, 409);
    expect(await errorOf(ownTeam), contains('already play'));

    final standings = await decode(
      await sendRequest(
        app,
        'GET',
        '/tournaments/$id/standings',
        token: player,
      ),
    );
    expect((standings['standings'] as List).single['isUserTeam'], isTrue);
  });

  test('one pending request at a time and no repeat after a decline', () async {
    final lions = await user('lions');
    final hawks = await user('hawks');
    final player = await user('player');
    final id = seedTournament();
    final lionsTeam = await createTeam(lions, id, 'Red Lions');
    final hawksTeam = await createTeam(hawks, id, 'Blue Hawks');

    expect((await ask(player, id, lionsTeam)).statusCode, 201);
    final second = await ask(player, id, hawksTeam);
    expect(second.statusCode, 409);
    expect(await errorOf(second), contains('pending'));

    final requestId = (await inbox(lions, id)).single['id'] as int;
    expect((await answer(lions, id, requestId, 'declined')).statusCode, 200);
    final again = await answer(lions, id, requestId, 'accepted');
    expect(again.statusCode, 409);
    expect(await errorOf(again), contains('already answered'));

    final repeat = await ask(player, id, lionsTeam);
    expect(repeat.statusCode, 409);
    expect(await errorOf(repeat), contains('declined'));
    expect((await ask(player, id, hawksTeam)).statusCode, 201);
    expect((await detail(player, id))['myRequests'], [
      {'teamId': lionsTeam, 'status': 'declined'},
      {'teamId': hawksTeam, 'status': 'pending'},
    ]);

    // Creating a team cancels the pending request.
    await createTeam(player, id, 'Solo FC');
    expect(await inbox(hawks, id), isEmpty);
    expect((await detail(player, id))['myRequests'], [
      {'teamId': lionsTeam, 'status': 'declined'},
    ]);
  });

  test('captains and full teams cannot take more players', () async {
    final captain = await user('captain');
    final other = await user('other');
    final players = [
      for (final name in ['player1', 'player2', 'player3']) await user(name),
    ];
    final id = seedTournament(teamSize: 2);
    final teamId = await createTeam(captain, id, 'Red Lions');
    await createTeam(other, id, 'Blue Hawks');

    final captainAsks = await ask(other, id, teamId);
    expect(captainAsks.statusCode, 409);
    expect(await errorOf(captainAsks), contains('already play'));
    expect((await ask(captain, id, 999)).statusCode, 404);

    expect((await ask(players[0], id, teamId)).statusCode, 201);
    expect((await ask(players[1], id, teamId)).statusCode, 201);
    final requests = await inbox(captain, id);
    final first = requests[0]['id'] as int;
    final second = requests[1]['id'] as int;
    expect((await answer(captain, id, first, 'accepted')).statusCode, 200);

    final overfill = await answer(captain, id, second, 'accepted');
    expect(overfill.statusCode, 409);
    expect(await errorOf(overfill), contains('full'));
    expect((await answer(captain, id, second, 'declined')).statusCode, 200);
    final full = await ask(players[2], id, teamId);
    expect(full.statusCode, 409);
    expect(await errorOf(full), contains('full'));
  });

  test('only the team captain can see and answer its requests', () async {
    final captain = await user('captain');
    final rival = await user('rival');
    final player = await user('player');
    final id = seedTournament();
    final teamId = await createTeam(captain, id, 'Red Lions');
    await createTeam(rival, id, 'Blue Hawks');
    await ask(player, id, teamId);
    final requestId = (await inbox(captain, id)).single['id'] as int;

    final notCaptain = await sendRequest(
      app,
      'GET',
      '/tournaments/$id/requests',
      token: player,
    );
    expect(notCaptain.statusCode, 403);
    expect(await inbox(rival, id), isEmpty);
    expect((await answer(rival, id, requestId, 'accepted')).statusCode, 404);
    expect((await answer(player, id, requestId, 'accepted')).statusCode, 404);
    expect((await answer(captain, id, requestId, 'maybe')).statusCode, 400);
    expect((await answer(captain, id, 999, 'accepted')).statusCode, 404);
  });

  test('requests expire when the tournament starts', () async {
    final captain = await user('captain');
    final player = await user('player');
    final id = seedTournament();
    final teamId = await createTeam(captain, id, 'Red Lions');
    await ask(player, id, teamId);
    final requestId = (await inbox(captain, id)).single['id'] as int;

    setStatus(id, 'active');
    final late = await answer(captain, id, requestId, 'accepted');
    expect(late.statusCode, 409);
    expect(await errorOf(late), contains('closed'));
    expect((await detail(player, id))['myRequests'], [
      {'teamId': teamId, 'status': 'expired'},
    ]);
    final newRequest = await ask(await user('late'), id, teamId);
    expect(newRequest.statusCode, 409);
    expect(await errorOf(newRequest), contains('closed'));
  });
}
