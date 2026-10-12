import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';
import 'gamification.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message, {this.code});

  final int status;
  final String message;

  /// Machine-readable reason for clients that react to specific failures.
  final String? code;
}

Handler createApp({required AppDatabase database, required String jwtSecret}) {
  final router = Router()
    ..get('/', (_) => _json({'service': 'football-match-api'}))
    ..post(
      '/auth/register',
      (request) => _register(request, database, jwtSecret),
    )
    ..post('/auth/login', (request) => _login(request, database, jwtSecret))
    ..get('/me', _authenticated(database, jwtSecret, _me))
    ..get(
      '/me/tournament-requests',
      _authenticated(database, jwtSecret, _myTournamentRequests),
    )
    ..get(
      '/users/<userId>/profile',
      _authenticated(database, jwtSecret, _userProfile),
    )
    ..get('/gamification', _authenticated(database, jwtSecret, _gamification))
    ..get('/friends', _authenticated(database, jwtSecret, _friends))
    ..get(
      '/friend-requests',
      _authenticated(database, jwtSecret, _incomingRequests),
    )
    ..post(
      '/friend-requests',
      _authenticated(database, jwtSecret, _sendFriendRequest),
    )
    ..post(
      '/friend-requests/<requestId>/accept',
      _authenticated(database, jwtSecret, _acceptFriendRequest),
    )
    ..delete(
      '/friends/<friendId>',
      _authenticated(database, jwtSecret, _removeFriend),
    )
    ..get(
      '/friends/<friendId>/messages',
      _authenticated(database, jwtSecret, _messages),
    )
    ..post(
      '/friends/<friendId>/messages',
      _authenticated(database, jwtSecret, _sendMessage),
    )
    ..get('/tournaments', _authenticated(database, jwtSecret, _tournaments))
    ..get(
      '/tournaments/<tournamentId>',
      _authenticated(database, jwtSecret, _tournament),
    )
    ..post(
      '/tournaments/<tournamentId>/join',
      _authenticated(database, jwtSecret, _joinTournament),
    )
    ..delete(
      '/tournaments/<tournamentId>/join',
      _authenticated(database, jwtSecret, _leaveTournament),
    )
    ..post(
      '/tournaments/<tournamentId>/transfer-captaincy',
      _authenticated(database, jwtSecret, _transferCaptaincy),
    )
    ..post(
      '/tournaments/<tournamentId>/teams/<teamId>/request',
      _authenticated(database, jwtSecret, _requestToJoinTeam),
    )
    ..get(
      '/tournaments/<tournamentId>/teams/<teamId>',
      _authenticated(database, jwtSecret, _tournamentTeam),
    )
    ..delete(
      '/tournaments/<tournamentId>/teams/<teamId>/members/<memberId>',
      _authenticated(database, jwtSecret, _removeTeamMember),
    )
    ..get(
      '/tournaments/<tournamentId>/requests',
      _authenticated(database, jwtSecret, _teamJoinRequests),
    )
    ..put(
      '/tournaments/<tournamentId>/requests/<requestId>',
      _authenticated(database, jwtSecret, _answerJoinRequest),
    )
    ..delete(
      '/tournaments/<tournamentId>/disband-notice',
      _authenticated(database, jwtSecret, _dismissDisbandNotice),
    )
    ..get(
      '/tournaments/<tournamentId>/standings',
      _authenticated(database, jwtSecret, _tournamentStandings),
    )
    ..get(
      '/tournaments/<tournamentId>/bracket',
      _authenticated(database, jwtSecret, _tournamentBracket),
    );

  return Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_errors)
      .addHandler(router.call);
}

Middleware get _errors =>
    (Handler inner) => (Request request) async {
      try {
        return await inner(request);
      } on ApiException catch (error) {
        return _json({
          'error': error.message,
          if (error.code != null) 'code': error.code,
        }, status: error.status);
      } on FormatException {
        return _json({
          'error': 'Request body must be valid JSON.',
        }, status: 400);
      }
    };

Handler _authenticated(AppDatabase database, String secret, Handler handler) {
  return (request) async {
    final authorization = request.headers['authorization'];
    if (authorization == null || !authorization.startsWith('Bearer ')) {
      throw ApiException(401, 'Sign in to continue.');
    }

    try {
      final token = authorization.substring('Bearer '.length);
      final jwt = JWT.verify(
        token,
        SecretKey(secret),
        issuer: 'football-match-api',
      );
      final userId = (jwt.payload as Map<String, dynamic>)['userId'];
      if (userId is! int) {
        throw ApiException(401, 'Invalid session.');
      }
      return await handler(
        request.change(context: {'userId': userId, 'database': database}),
      );
    } on JWTException {
      throw ApiException(
        401,
        'Your session has expired. Please sign in again.',
      );
    }
  };
}

Future<Response> _register(
  Request request,
  AppDatabase database,
  String secret,
) async {
  final body = await _body(request);
  final username = _requiredString(body, 'username').trim().toLowerCase();
  final email = _requiredString(body, 'email').trim().toLowerCase();
  final password = _requiredString(body, 'password');

  if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
    throw ApiException(
      400,
      'Username must be 3-20 characters (letters, numbers, or underscores).',
    );
  }
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ||
      email.length > 254) {
    throw ApiException(400, 'Enter a valid email address.');
  }
  if (password.length < 8 || utf8.encode(password).length > 72) {
    throw ApiException(400, 'Password must be between 8 and 72 characters.');
  }

  final existing = database.db.select(
    'SELECT id FROM users WHERE username = ? OR email = ?',
    [username, email],
  );
  if (existing.isNotEmpty) {
    throw ApiException(409, 'That username or email is already registered.');
  }

  try {
    database.db.execute(
      'INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)',
      [username, email, BCrypt.hashpw(password, BCrypt.gensalt())],
    );
  } on SqliteException catch (error) {
    if (error.message.contains('UNIQUE constraint failed')) {
      throw ApiException(409, 'That username or email is already registered.');
    }
    rethrow;
  }

  final user = database.db.select(
    'SELECT id, username, email FROM users WHERE username = ?',
    [username],
  ).first;
  recordActiveDay(database, user['id'] as int);
  unlockAchievement(database, user['id'] as int, 'first_kickoff');
  return _sessionResponse(user, secret, status: 201);
}

Future<Response> _login(
  Request request,
  AppDatabase database,
  String secret,
) async {
  final body = await _body(request);
  final email = _requiredString(body, 'email').trim().toLowerCase();
  final password = _requiredString(body, 'password');
  final users = database.db.select(
    'SELECT id, username, email, password_hash FROM users WHERE email = ?',
    [email],
  );

  if (users.isEmpty ||
      !BCrypt.checkpw(password, users.first['password_hash'] as String)) {
    throw ApiException(401, 'Email or password is incorrect.');
  }
  recordActiveDay(database, users.first['id'] as int);
  return _sessionResponse(users.first, secret);
}

Response _sessionResponse(Row user, String secret, {int status = 200}) {
  final token = JWT(
    {'userId': user['id']},
    issuer: 'football-match-api',
  ).sign(SecretKey(secret), expiresIn: const Duration(hours: 24));
  return _json({
    'token': token,
    'user': {
      'id': user['id'],
      'username': user['username'],
      'email': user['email'],
    },
  }, status: status);
}

Response _me(Request request) {
  final userId = _userId(request);
  final database = _database(request);
  recordActiveDay(database, userId);
  final rows = database.db.select(
    'SELECT id, username, email FROM users WHERE id = ?',
    [userId],
  );
  if (rows.isEmpty) {
    throw ApiException(404, 'Account not found.');
  }
  final user = rows.first;
  return _json({
    'id': user['id'],
    'username': user['username'],
    'email': user['email'],
  });
}

Response _gamification(Request request) {
  final database = _database(request);
  final userId = _userId(request);
  recordActiveDay(database, userId);
  unlockAchievement(database, userId, 'first_kickoff');
  unlockEligibleAchievements(database, userId);
  return _json(gamificationSnapshot(database, userId));
}

Response _friends(Request request) {
  final userId = _userId(request);
  final rows = _database(request).db.select(
    '''
      SELECT u.id, u.username
      FROM friendships f
      JOIN users u ON u.id = CASE
        WHEN f.requester_id = ? THEN f.addressee_id
        ELSE f.requester_id
      END
      WHERE (f.requester_id = ? OR f.addressee_id = ?) AND f.status = 'accepted'
      ORDER BY u.username COLLATE NOCASE
    ''',
    [userId, userId, userId],
  );
  return _json({'friends': rows.map(_friendJson).toList()});
}

Response _incomingRequests(Request request) {
  final userId = _userId(request);
  final rows = _database(request).db.select(
    '''
      SELECT f.id, u.id AS user_id, u.username, f.created_at
      FROM friendships f
      JOIN users u ON u.id = f.requester_id
      WHERE f.addressee_id = ? AND f.status = 'pending'
      ORDER BY f.id DESC
    ''',
    [userId],
  );
  return _json({
    'requests': rows
        .map(
          (row) => {
            'id': row['id'],
            'user': {'id': row['user_id'], 'username': row['username']},
            'createdAt': row['created_at'],
          },
        )
        .toList(),
  });
}

Future<Response> _sendFriendRequest(Request request) async {
  final database = _database(request);
  final userId = _userId(request);
  final username = _requiredString(
    await _body(request),
    'username',
  ).trim().toLowerCase();
  if (username.isEmpty) throw ApiException(400, 'Enter a username.');

  final targets = database.db.select(
    'SELECT id, username FROM users WHERE username = ?',
    [username],
  );
  if (targets.isEmpty) throw ApiException(404, 'No account has that username.');
  final target = targets.first;
  final targetId = target['id'] as int;
  if (targetId == userId) {
    throw ApiException(400, 'You cannot send a friend request to yourself.');
  }

  final existing = database.db.select(
    '''
      SELECT status FROM friendships
      WHERE (requester_id = ? AND addressee_id = ?)
         OR (requester_id = ? AND addressee_id = ?)
    ''',
    [userId, targetId, targetId, userId],
  );
  if (existing.isNotEmpty) {
    final status = existing.first['status'];
    final message = status == 'accepted'
        ? 'You are already friends.'
        : 'A friend request already exists between you.';
    throw ApiException(409, message);
  }

  database.db.execute(
    'INSERT INTO friendships (requester_id, addressee_id, status) VALUES (?, ?, ?)',
    [userId, targetId, 'pending'],
  );
  return _json({
    'request': {'user': _friendJson(target)},
  }, status: 201);
}

Response _acceptFriendRequest(Request request) {
  final requestId = int.tryParse(request.params['requestId'] ?? '');
  if (requestId == null) throw ApiException(400, 'Invalid friend request.');
  final database = _database(request);
  final result = database.db.select(
    '''
      SELECT id FROM friendships
      WHERE id = ? AND addressee_id = ? AND status = 'pending'
    ''',
    [requestId, _userId(request)],
  );
  if (result.isEmpty) throw ApiException(404, 'Friend request not found.');
  database.db.execute(
    "UPDATE friendships SET status = 'accepted' WHERE id = ?",
    [requestId],
  );
  final requesterId =
      database.db.select('SELECT requester_id FROM friendships WHERE id = ?', [
            requestId,
          ]).first['requester_id']
          as int;
  grantFriendshipXp(database, requesterId);
  grantFriendshipXp(database, _userId(request));
  return _json({'accepted': true});
}

Response _removeFriend(Request request) {
  final friendId = int.tryParse(request.params['friendId'] ?? '');
  if (friendId == null) throw ApiException(400, 'Invalid friend account.');
  final userId = _userId(request);
  final database = _database(request);
  database.db.execute(
    '''
      DELETE FROM friendships
      WHERE status = 'accepted'
        AND ((requester_id = ? AND addressee_id = ?)
          OR (requester_id = ? AND addressee_id = ?))
    ''',
    [userId, friendId, friendId, userId],
  );
  if (database.db.updatedRows == 0) {
    throw ApiException(404, 'Friend not found.');
  }
  return Response(204);
}

Response _messages(Request request) {
  final friendId = _friendId(request);
  final userId = _userId(request);
  final database = _database(request);
  _requireFriendship(database, userId, friendId);

  final after = int.tryParse(request.url.queryParameters['after'] ?? '0');
  if (after == null || after < 0) {
    throw ApiException(400, 'Invalid message cursor.');
  }
  final rows = database.db.select(
    '''
      SELECT id, sender_id, recipient_id, body, sent_at
      FROM messages
      WHERE ((sender_id = ? AND recipient_id = ?)
          OR (sender_id = ? AND recipient_id = ?))
        AND id > ?
      ORDER BY id
      LIMIT 100
    ''',
    [userId, friendId, friendId, userId, after],
  );
  return _json({
    'messages': rows
        .map(
          (row) => {
            'id': row['id'],
            'senderId': row['sender_id'],
            'recipientId': row['recipient_id'],
            'body': row['body'],
            'sentAt': row['sent_at'],
          },
        )
        .toList(),
  });
}

Future<Response> _sendMessage(Request request) async {
  final friendId = _friendId(request);
  final userId = _userId(request);
  final database = _database(request);
  _requireFriendship(database, userId, friendId);
  final body = _requiredString(await _body(request), 'body').trim();
  if (body.isEmpty || body.length > 2000) {
    throw ApiException(400, 'Message must contain 1-2000 characters.');
  }
  database.db.execute(
    'INSERT INTO messages (sender_id, recipient_id, body) VALUES (?, ?, ?)',
    [userId, friendId, body],
  );
  final messageId = database.db.lastInsertRowId;
  grantMessageXp(database, userId);
  final message = database.db
      .select(
        '''
      SELECT id, sender_id, recipient_id, body, sent_at
      FROM messages WHERE id = ?
    ''',
        [messageId],
      )
      .first;
  return _json({
    'message': {
      'id': message['id'],
      'senderId': message['sender_id'],
      'recipientId': message['recipient_id'],
      'body': message['body'],
      'sentAt': message['sent_at'],
    },
  }, status: 201);
}

const _tournamentStatuses = {'upcoming', 'active', 'finished', 'cancelled'};
const _tournamentListLimit = 100;
const _winPoints = 3;
const _drawPoints = 1;
const _teamNameMinLength = 3;
const _teamNameMaxLength = 30;
final _teamNamePattern = RegExp(r"^[\p{L}\p{M}\p{N} '._-]+$", unicode: true);
final _teamNameAlphanumeric = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// The team the signed-in user (`?1`) plays for in tournament `t`, as the
/// captain of an active team or as an accepted player.
const _myTeamId = '''
  COALESCE(
    (SELECT tt.id FROM tournament_teams tt
      WHERE tt.tournament_id = t.id AND tt.captain_id = ?1
        AND tt.status = 'active'),
    (SELECT jr.team_id FROM join_requests jr
      WHERE jr.tournament_id = t.id AND jr.requester_id = ?1
        AND jr.status = 'accepted'))
''';

/// Selects tournament summaries. The first parameter is the signed-in user,
/// used (as `?1`) for their team and requests. Later plain `?` placeholders
/// continue numbering from 2. Teams that left are not counted.
const _tournamentSelect =
    '''
  SELECT t.id, t.name, t.description, t.format, t.status, t.start_date,
    t.end_date, t.max_teams, t.team_size, t.location, t.prize,
    u.username AS created_by,
    (SELECT COUNT(*) FROM tournament_teams tt
      WHERE tt.tournament_id = t.id AND tt.status = 'active') AS current_teams,
    EXISTS (SELECT 1 FROM tournament_teams tt
      WHERE tt.tournament_id = t.id AND tt.captain_id = ?1
        AND tt.status = 'active') AS joined,
    $_myTeamId AS my_team_id,
    (SELECT COUNT(*) FROM join_requests jr
      WHERE jr.team_id = $_myTeamId AND jr.status = 'accepted')
      AS my_team_players,
    EXISTS (SELECT 1 FROM tournament_matches m
      WHERE m.home_team_id = $_myTeamId OR m.away_team_id = $_myTeamId)
      AS my_team_has_matches,
    (SELECT COUNT(*) FROM join_requests jr
      JOIN tournament_teams tt ON tt.id = jr.team_id
      WHERE jr.tournament_id = t.id AND tt.captain_id = ?1
        AND tt.status = 'active' AND jr.status = 'pending') AS pending_requests
  FROM tournaments t
  LEFT JOIN users u ON u.id = t.created_by
''';

Response _tournaments(Request request) {
  final status = request.url.queryParameters['status'];
  if (status != null && !_tournamentStatuses.contains(status)) {
    throw ApiException(400, 'Invalid tournament status.');
  }
  final rows = _database(request).db.select(
    '''
      $_tournamentSelect
      WHERE ? IS NULL OR t.status = ?
      ORDER BY CASE t.status
          WHEN 'active' THEN 0
          WHEN 'upcoming' THEN 1
          WHEN 'finished' THEN 2
          ELSE 3
        END,
        t.start_date, t.id
      LIMIT $_tournamentListLimit
    ''',
    [_userId(request), status, status],
  );
  return _json({'tournaments': rows.map(_tournamentJson).toList()});
}

Response _tournament(Request request) => _json({
  'tournament': _tournamentDetailJson(
    _database(request),
    _tournamentId(request),
    _userId(request),
  ),
});

Future<Response> _joinTournament(Request request) async {
  final database = _database(request);
  final userId = _userId(request);
  final tournamentId = _tournamentId(request);
  final tournament = _findTournament(database, tournamentId, userId);
  final teamName = _teamName(await _body(request));
  if (tournament['joined'] == 1) {
    throw ApiException(409, 'You already joined this tournament.');
  }
  if (tournament['my_team_id'] != null) throw _alreadyOnTeam();
  if (tournament['status'] != 'upcoming') throw _registrationClosed();
  final users = database.db.select('SELECT id FROM users WHERE id = ?', [
    userId,
  ]);
  if (users.isEmpty) throw ApiException(404, 'Account not found.');
  final sameName = database.db.select(
    '''
      SELECT id FROM tournament_teams
      WHERE tournament_id = ? AND name = ? COLLATE NOCASE
        AND status = 'active'
    ''',
    [tournamentId, teamName],
  );
  if (sameName.isNotEmpty) throw _teamNameTaken();

  // The capacity, status and membership checks are part of the insert, so a
  // full or closed tournament never gains a team and players keep one team.
  _inTransaction(database, () {
    try {
      database.db.execute(
        '''
          INSERT INTO tournament_teams (tournament_id, captain_id, name)
          SELECT t.id, ?1, ?2
          FROM tournaments t
          WHERE t.id = ?3 AND t.status = 'upcoming'
            AND (SELECT COUNT(*) FROM tournament_teams tt
              WHERE tt.tournament_id = t.id AND tt.status = 'active')
              < t.max_teams
            AND NOT EXISTS (SELECT 1 FROM join_requests jr
              WHERE jr.tournament_id = t.id AND jr.requester_id = ?1
                AND jr.status = 'accepted')
        ''',
        [userId, teamName, tournamentId],
      );
    } on SqliteException catch (error) {
      // A concurrent join can pass the checks above; the unique indexes decide.
      if (error.message.contains('UNIQUE constraint failed')) {
        if (error.message.contains('captain_id')) {
          throw ApiException(409, 'You already joined this tournament.');
        }
        throw _teamNameTaken();
      }
      rethrow;
    }
    if (database.db.updatedRows == 0) {
      final current = _findTournament(database, tournamentId, userId);
      if (current['my_team_id'] != null) throw _alreadyOnTeam();
      throw ApiException(409, 'This tournament is full.');
    }
    // Captaining a team replaces any request to join another one.
    database.db.execute(
      '''
        UPDATE join_requests
        SET status = 'cancelled', responded_at = CURRENT_TIMESTAMP
        WHERE tournament_id = ? AND requester_id = ? AND status = 'pending'
      ''',
      [tournamentId, userId],
    );
  });
  return _json({
    'tournament': _tournamentDetailJson(database, tournamentId, userId),
  });
}

/// Trims and collapses spaces, then applies the same rules as the app.
String _teamName(Map<String, dynamic> body) {
  final name = _requiredString(
    body,
    'name',
  ).trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.length < _teamNameMinLength || name.length > _teamNameMaxLength) {
    throw ApiException(
      400,
      'Team names must be $_teamNameMinLength to $_teamNameMaxLength characters.',
    );
  }
  if (!_teamNamePattern.hasMatch(name) ||
      !_teamNameAlphanumeric.hasMatch(name)) {
    throw ApiException(
      400,
      "Team names can only use letters, numbers, spaces and ' . _ -",
    );
  }
  return name;
}

ApiException _teamNameTaken() =>
    ApiException(409, 'That team name is already taken in this tournament.');

/// Withdraws the signed-in user while registration is open.
///
/// A player's membership is marked `left`. A captain's team is kept as
/// `left`, with `left_at`, freeing its spot and name; pending requests to it
/// are cancelled. A team with players is only withdrawn with
/// `?disband=true`, which marks it `disbanded` and frees its players.
Response _leaveTournament(Request request) {
  final database = _database(request);
  final userId = _userId(request);
  final tournamentId = _tournamentId(request);
  final disband = request.url.queryParameters['disband'] == 'true';
  final tournament = _findTournament(database, tournamentId, userId);
  if (tournament['my_team_id'] == null) throw _notJoined();
  if (tournament['status'] != 'upcoming') throw _leaveClosed();
  if (tournament['joined'] != 1) {
    _leaveTeamAsPlayer(database, tournamentId, userId);
  } else {
    _withdrawTeam(database, tournamentId, userId, disband: disband);
  }
  return _json({
    'tournament': _tournamentDetailJson(database, tournamentId, userId),
  });
}

void _leaveTeamAsPlayer(AppDatabase database, int tournamentId, int userId) {
  database.db.execute(
    '''
      UPDATE join_requests
      SET status = 'left', responded_at = CURRENT_TIMESTAMP
      WHERE tournament_id = ?1 AND requester_id = ?2 AND status = 'accepted'
        AND EXISTS (SELECT 1 FROM tournaments t
          WHERE t.id = ?1 AND t.status = 'upcoming')
    ''',
    [tournamentId, userId],
  );
  if (database.db.updatedRows == 0) {
    final current = _findTournament(database, tournamentId, userId);
    if (current['my_team_id'] == null) throw _notJoined();
    throw _leaveClosed();
  }
}

void _withdrawTeam(
  AppDatabase database,
  int tournamentId,
  int userId, {
  required bool disband,
}) {
  _inTransaction(database, () {
    final teams = database.db.select(
      '''
        SELECT id FROM tournament_teams
        WHERE tournament_id = ? AND captain_id = ? AND status = 'active'
      ''',
      [tournamentId, userId],
    );
    if (teams.isEmpty) throw _notJoined();
    final teamId = teams.first['id'] as int;
    // Status, fixtures and players are checked again inside the update, so
    // a team that gains matches or players meanwhile is kept.
    database.db.execute(
      '''
        UPDATE tournament_teams
        SET status = CASE WHEN EXISTS (SELECT 1 FROM join_requests jr
              WHERE jr.team_id = ?1 AND jr.status = 'accepted')
            THEN 'disbanded' ELSE 'left' END,
          left_at = CURRENT_TIMESTAMP
        WHERE id = ?1 AND status = 'active'
          AND EXISTS (SELECT 1 FROM tournaments t
            WHERE t.id = tournament_teams.tournament_id
              AND t.status = 'upcoming')
          AND NOT EXISTS (SELECT 1 FROM tournament_matches m
            WHERE m.home_team_id = ?1 OR m.away_team_id = ?1)
          AND (?2 OR NOT EXISTS (SELECT 1 FROM join_requests jr
            WHERE jr.team_id = ?1 AND jr.status = 'accepted'))
      ''',
      [teamId, disband ? 1 : 0],
    );
    if (database.db.updatedRows == 0) {
      final current = _findTournament(database, tournamentId, userId);
      if (current['status'] != 'upcoming') throw _leaveClosed();
      if (current['my_team_has_matches'] == 1) {
        throw ApiException(
          409,
          'Your team already has scheduled matches and cannot leave.',
        );
      }
      throw ApiException(
        409,
        'Your team has players. Transfer captaincy or disband the team.',
      );
    }
    // The team's players are free to join another team and are told why
    // the next time they open the tournament (`teamDisbanded`). Requests to
    // the team can no longer be answered.
    database.db.execute(
      '''
        UPDATE join_requests
        SET status = CASE status WHEN 'accepted' THEN 'disbanded'
            ELSE 'cancelled' END,
          responded_at = CURRENT_TIMESTAMP
        WHERE team_id = ? AND status IN ('pending', 'accepted')
      ''',
      [teamId],
    );
  });
}

/// Makes a player of the signed-in captain's team its captain before
/// kickoff. The former captain stays on the team as a player.
Future<Response> _transferCaptaincy(Request request) async {
  final database = _database(request);
  final userId = _userId(request);
  final tournamentId = _tournamentId(request);
  final newCaptainId = (await _body(request))['newCaptainId'];
  if (newCaptainId is! int) {
    throw ApiException(400, 'The "newCaptainId" field is required.');
  }
  if (newCaptainId == userId) {
    throw ApiException(400, 'You are already the captain.');
  }

  // Everything is checked under the write lock, so a team withdrawn or a
  // tournament started by a concurrent request is reported as such.
  _inTransaction(database, () {
    final tournament = _findTournament(database, tournamentId, userId);
    if (tournament['joined'] != 1) {
      throw _transferBlocked(database, tournamentId, userId, tournament);
    }
    if (tournament['status'] != 'upcoming') throw _transferClosed();
    final teamId = tournament['my_team_id'] as int;
    database.db.execute(
      '''
        UPDATE join_requests
        SET status = 'promoted', responded_at = CURRENT_TIMESTAMP
        WHERE team_id = ? AND requester_id = ? AND status = 'accepted'
      ''',
      [teamId, newCaptainId],
    );
    if (database.db.updatedRows == 0) {
      throw ApiException(
        404,
        'Player not found on this team.',
        code: 'player_not_on_team',
      );
    }
    database.db.execute(
      'UPDATE tournament_teams SET captain_id = ? WHERE id = ?',
      [newCaptainId, teamId],
    );
    database.db.execute(
      '''
        INSERT INTO join_requests
          (tournament_id, team_id, requester_id, status, responded_at)
        VALUES (?, ?, ?, 'accepted', CURRENT_TIMESTAMP)
      ''',
      [tournamentId, teamId, userId],
    );
  });
  return _json({
    'tournament': _tournamentDetailJson(database, tournamentId, userId),
  });
}

/// Why a user who does not captain an active team cannot transfer: their
/// team was withdrawn, captaincy already moved, or they never captained one.
ApiException _transferBlocked(
  AppDatabase database,
  int tournamentId,
  int userId,
  Row tournament,
) {
  if (tournament['my_team_id'] != null) {
    return ApiException(
      403,
      'You are no longer the captain of this team.',
      code: 'not_captain',
    );
  }
  final withdrawn = database.db.select(
    '''
      SELECT 1 FROM tournament_teams
      WHERE tournament_id = ? AND captain_id = ? AND status != 'active'
    ''',
    [tournamentId, userId],
  );
  if (withdrawn.isNotEmpty) {
    return ApiException(
      409,
      'Your team is no longer in this tournament.',
      code: 'team_withdrawn',
    );
  }
  return ApiException(
    403,
    'Only the team captain can transfer captaincy.',
    code: 'not_captain',
  );
}

ApiException _transferClosed() => ApiException(
  409,
  'Captaincy can only be transferred before the tournament starts.',
  code: 'transfer_closed',
);

/// Records that the user saw that their team was disbanded, so
/// `teamDisbanded` stops being reported on every device.
Response _dismissDisbandNotice(Request request) {
  final database = _database(request);
  final userId = _userId(request);
  final tournamentId = _tournamentId(request);
  _findTournament(database, tournamentId, userId);
  database.db.execute(
    '''
      UPDATE join_requests SET notice_seen_at = CURRENT_TIMESTAMP
      WHERE tournament_id = ? AND requester_id = ? AND status = 'disbanded'
        AND notice_seen_at IS NULL
    ''',
    [tournamentId, userId],
  );
  return Response(204);
}

ApiException _notJoined() =>
    ApiException(409, 'You have not joined this tournament.');

ApiException _leaveClosed() =>
    ApiException(409, 'You can only leave before the tournament starts.');

ApiException _registrationClosed() =>
    ApiException(409, 'Registration for this tournament is closed.');

ApiException _alreadyOnTeam() =>
    ApiException(409, 'You already play for a team in this tournament.');

/// Asks a team's captain to let the signed-in user play for that team.
Response _requestToJoinTeam(Request request) {
  final database = _database(request);
  final userId = _userId(request);
  final tournamentId = _tournamentId(request);
  final teamId = int.tryParse(request.params['teamId'] ?? '');
  if (teamId == null) throw ApiException(400, 'Invalid team.');
  _checkCanRequest(database, tournamentId, teamId, userId);

  // Status, capacity and team ownership are checked again inside the insert;
  // the partial unique index keeps one live request per user and tournament.
  try {
    database.db.execute(
      '''
        INSERT INTO join_requests (tournament_id, team_id, requester_id)
        SELECT t.id, tt.id, ?1
        FROM tournament_teams tt
        JOIN tournaments t ON t.id = tt.tournament_id
        WHERE tt.id = ?2 AND t.id = ?3 AND t.status = 'upcoming'
          AND tt.status = 'active'
          AND NOT EXISTS (SELECT 1 FROM tournament_teams c
            WHERE c.tournament_id = t.id AND c.captain_id = ?1
              AND c.status = 'active')
          AND 1 + (SELECT COUNT(*) FROM join_requests a
            WHERE a.team_id = tt.id AND a.status = 'accepted') < t.team_size
      ''',
      [userId, teamId, tournamentId],
    );
  } on SqliteException catch (error) {
    if (error.message.contains('UNIQUE constraint failed')) {
      _checkCanRequest(database, tournamentId, teamId, userId);
    }
    rethrow;
  }
  if (database.db.updatedRows == 0) {
    _checkCanRequest(database, tournamentId, teamId, userId);
    throw ApiException(409, 'This request can no longer be sent.');
  }
  return _json({
    'tournament': _tournamentDetailJson(database, tournamentId, userId),
  }, status: 201);
}

/// Throws the reason the user cannot ask to join [teamId], if any.
void _checkCanRequest(
  AppDatabase database,
  int tournamentId,
  int teamId,
  int userId,
) {
  final tournament = _findTournament(database, tournamentId, userId);
  if (tournament['status'] != 'upcoming') throw _registrationClosed();
  final teams = database.db.select(
    '''
      SELECT 1 + (SELECT COUNT(*) FROM join_requests jr
          WHERE jr.team_id = tt.id AND jr.status = 'accepted') AS players
      FROM tournament_teams tt
      WHERE tt.id = ? AND tt.tournament_id = ? AND tt.status = 'active'
    ''',
    [teamId, tournamentId],
  );
  if (teams.isEmpty) throw ApiException(404, 'Team not found.');
  if (tournament['my_team_id'] != null) throw _alreadyOnTeam();
  final previous = database.db.select(
    '''
      SELECT team_id, status FROM join_requests
      WHERE tournament_id = ? AND requester_id = ?
        AND status IN ('pending', 'declined', 'removed')
    ''',
    [tournamentId, userId],
  );
  if (previous.any((row) => row['status'] == 'pending')) {
    throw ApiException(
      409,
      'You already have a pending request in this tournament.',
    );
  }
  // A team that declined or removed the player cannot be asked again.
  for (final row in previous.where((row) => row['team_id'] == teamId)) {
    throw ApiException(
      409,
      row['status'] == 'removed'
          ? 'You were removed from this team.'
          : 'This team declined your request.',
    );
  }
  if ((teams.first['players'] as int) >= (tournament['team_size'] as int)) {
    throw _teamFull();
  }
}

ApiException _teamFull() => ApiException(409, 'This team is full.');

/// Pending requests to the signed-in captain's team, oldest first.
Response _teamJoinRequests(Request request) {
  final database = _database(request);
  final userId = _userId(request);
  final tournamentId = _tournamentId(request);
  final tournament = _findTournament(database, tournamentId, userId);
  if (tournament['joined'] != 1) {
    throw ApiException(403, 'Only team captains can see join requests.');
  }
  final rows = database.db.select(
    '''
      $_joinRequestSelect
      WHERE tt.tournament_id = ? AND tt.captain_id = ?
        AND tt.status = 'active' AND jr.status = 'pending'
      ORDER BY jr.created_at, jr.id
    ''',
    [tournamentId, userId],
  );
  return _json({'requests': rows.map(_joinRequestJson).toList()});
}

/// Accepts or declines a pending request to the signed-in captain's team.
Future<Response> _answerJoinRequest(Request request) async {
  final database = _database(request);
  final userId = _userId(request);
  final tournamentId = _tournamentId(request);
  final requestId = int.tryParse(request.params['requestId'] ?? '');
  if (requestId == null) throw ApiException(400, 'Invalid join request.');
  final status = _requiredString(await _body(request), 'status');
  if (status != 'accepted' && status != 'declined') {
    throw ApiException(400, 'Status must be "accepted" or "declined".');
  }
  final tournament = _findTournament(database, tournamentId, userId);
  final existing = _findJoinRequest(database, tournamentId, requestId, userId);
  if (existing['status'] != 'pending') throw _requestAnswered();
  if (tournament['status'] != 'upcoming') throw _registrationClosed();

  // Ownership, status, capacity and the requester's own team are checked
  // inside the update, so concurrent answers cannot overfill a team.
  database.db.execute(
    '''
      UPDATE join_requests
      SET status = ?1, responded_at = CURRENT_TIMESTAMP
      WHERE id = ?2 AND tournament_id = ?3 AND status = 'pending'
        AND team_id IN (SELECT id FROM tournament_teams
          WHERE tournament_id = ?3 AND captain_id = ?4 AND status = 'active')
        AND EXISTS (SELECT 1 FROM tournaments t
          WHERE t.id = ?3 AND t.status = 'upcoming')
        AND (?1 = 'declined' OR (
          1 + (SELECT COUNT(*) FROM join_requests a
            WHERE a.team_id = join_requests.team_id
              AND a.status = 'accepted')
            < (SELECT team_size FROM tournaments WHERE id = ?3)
          AND NOT EXISTS (SELECT 1 FROM tournament_teams c
            WHERE c.tournament_id = ?3 AND c.status = 'active'
              AND c.captain_id = join_requests.requester_id)))
    ''',
    [status, requestId, tournamentId, userId],
  );
  if (database.db.updatedRows == 0) {
    final current = _findJoinRequest(database, tournamentId, requestId, userId);
    if (current['status'] != 'pending') throw _requestAnswered();
    final latest = _findTournament(database, tournamentId, userId);
    if (latest['status'] != 'upcoming') throw _registrationClosed();
    final requesterTeams = database.db.select(
      '''
        SELECT 1 FROM tournament_teams
        WHERE tournament_id = ? AND captain_id = ? AND status = 'active'
      ''',
      [tournamentId, current['requester_id']],
    );
    if (requesterTeams.isNotEmpty) {
      throw ApiException(409, 'This player already has a team.');
    }
    throw ApiException(409, 'Your team is full.');
  }
  return _json({
    'request': _joinRequestJson(
      _findJoinRequest(database, tournamentId, requestId, userId),
    ),
  });
}

const _joinRequestSelect = '''
  SELECT jr.id, jr.team_id, tt.name AS team_name, tt.captain_id,
    jr.requester_id, u.username AS requester_name, jr.status, jr.created_at
  FROM join_requests jr
  JOIN tournament_teams tt ON tt.id = jr.team_id
  JOIN users u ON u.id = jr.requester_id
''';

/// Finds a request to the captain's team; other teams' requests are 404 so
/// their existence is not revealed.
Row _findJoinRequest(
  AppDatabase database,
  int tournamentId,
  int requestId,
  int captainId,
) {
  final rows = database.db.select(
    '''
      $_joinRequestSelect
      WHERE jr.id = ? AND jr.tournament_id = ? AND tt.captain_id = ?
        AND tt.status = 'active'
    ''',
    [requestId, tournamentId, captainId],
  );
  if (rows.isEmpty) throw ApiException(404, 'Join request not found.');
  return rows.first;
}

ApiException _requestAnswered() =>
    ApiException(409, 'This request was already answered.');

Map<String, Object?> _joinRequestJson(Row row) => {
  'id': row['id'],
  'teamId': row['team_id'],
  'teamName': row['team_name'],
  // Safe to share: profiles check access themselves.
  'requesterId': row['requester_id'],
  'requesterName': row['requester_name'],
  'status': row['status'],
  'createdAt': row['created_at'],
};

/// Runs [action] in one SQLite transaction, rolling back if it throws.
T _inTransaction<T>(AppDatabase database, T Function() action) {
  database.db.execute('BEGIN IMMEDIATE');
  try {
    final result = action();
    database.db.execute('COMMIT');
    return result;
  } catch (_) {
    database.db.execute('ROLLBACK');
    rethrow;
  }
}

Response _tournamentStandings(Request request) {
  final database = _database(request);
  final userId = _userId(request);
  final tournamentId = _tournamentId(request);
  final tournament = _findTournament(database, tournamentId, userId);
  final userTeamId = tournament['my_team_id'] as int?;

  final teams = database.db.select(
    '''
      SELECT id, name, group_label FROM tournament_teams
      WHERE tournament_id = ? AND status = 'active'
    ''',
    [tournamentId],
  );
  final records = {
    for (final team in teams) team['id'] as int: _TeamRecord(team, userTeamId),
  };
  final groups = {
    for (final team in teams) team['id'] as int: team['group_label'] as String?,
  };
  // Knockout matches decide the bracket, not the table.
  final matches = database.db.select(
    '''
      SELECT home_team_id, away_team_id, home_score, away_score
      FROM tournament_matches
      WHERE tournament_id = ? AND status = 'played' AND stage = 'group'
    ''',
    [tournamentId],
  );
  for (final match in matches) {
    final home = records[match['home_team_id']];
    final away = records[match['away_team_id']];
    if (home == null || away == null) continue;
    final homeScore = match['home_score'] as int;
    final awayScore = match['away_score'] as int;
    home.record(scored: homeScore, conceded: awayScore);
    away.record(scored: awayScore, conceded: homeScore);
  }

  // One table per group (teams without a group share one), ranked within it.
  final tables = <String?, List<_TeamRecord>>{};
  for (final record in records.values) {
    tables.putIfAbsent(groups[record.teamId], () => []).add(record);
  }
  final labels = tables.keys.toList()
    ..sort((left, right) {
      if (left == null) return right == null ? 0 : 1;
      if (right == null) return -1;
      return left.compareTo(right);
    });
  return _json({
    'standings': [
      for (final label in labels)
        ...() {
          final table = tables[label]!..sort(_TeamRecord.compare);
          return [
            for (var index = 0; index < table.length; index++)
              {...table[index].toJson(position: index + 1), 'group': label},
          ];
        }(),
    ],
  });
}

/// Knockout rounds with every slot of the bracket, filling rounds and matches
/// that have no row yet with `pending` placeholders whose teams are the known
/// winners of the two matches feeding them.
Response _tournamentBracket(Request request) {
  final database = _database(request);
  final tournamentId = _tournamentId(request);
  _findTournament(database, tournamentId, _userId(request));

  final rows = database.db.select(
    '''
      SELECT m.id, m.round, m.bracket_position, m.home_team_id, m.away_team_id,
        m.home_score, m.away_score, m.winner_team_id, m.status,
        m.scheduled_at, h.name AS home_name, a.name AS away_name
      FROM tournament_matches m
      LEFT JOIN tournament_teams h ON h.id = m.home_team_id
      LEFT JOIN tournament_teams a ON a.id = m.away_team_id
      WHERE m.tournament_id = ? AND m.stage = 'knockout'
      ORDER BY m.round, m.bracket_position IS NULL, m.bracket_position, m.id
    ''',
    [tournamentId],
  );
  if (rows.isEmpty) {
    return _json({
      'bracket': {'rounds': <Object>[]},
    });
  }

  final byRound = <int, List<Row>>{};
  for (final row in rows) {
    byRound.putIfAbsent(row['round'] as int, () => []).add(row);
  }
  final firstRound = byRound.keys.reduce((a, b) => a < b ? a : b);
  final lastRound = byRound.keys.reduce((a, b) => a > b ? a : b);
  final slots = _nextPowerOfTwo(_slotsNeeded(byRound[firstRound]!));
  final expectedRounds = _log2(slots) + 1;
  final roundCount = expectedRounds > lastRound - firstRound + 1
      ? expectedRounds
      : lastRound - firstRound + 1;

  final rounds = <List<Map<String, Object?>>>[];
  for (var index = 0; index < roundCount; index++) {
    final existing = byRound[firstRound + index] ?? const <Row>[];
    final expected = slots >> index;
    final needed = _slotsNeeded(existing);
    final count = needed > expected ? needed : expected;
    final previous = index == 0 ? null : rounds[index - 1];
    // Rows sit at their bracket_position; rows without one (or clashing
    // with an earlier row) fill the remaining slots in id order.
    final placed = <int, Row>{};
    final unplaced = <Row>[];
    for (final row in existing) {
      final position = row['bracket_position'] as int?;
      if (position != null && !placed.containsKey(position - 1)) {
        placed[position - 1] = row;
      } else {
        unplaced.add(row);
      }
    }
    final matches = <Map<String, Object?>>[];
    for (var slot = 0; slot < count || unplaced.isNotEmpty; slot++) {
      var row = placed[slot];
      if (row == null && unplaced.isNotEmpty) row = unplaced.removeAt(0);
      matches.add(
        row != null
            ? {..._bracketMatch(row), 'position': slot + 1}
            : _pendingMatch(
                position: slot + 1,
                home: _winnerOf(previous, slot * 2),
                away: _winnerOf(previous, slot * 2 + 1),
              ),
      );
    }
    rounds.add(matches);
  }

  return _json({
    'bracket': {
      'rounds': [
        for (var index = 0; index < rounds.length; index++)
          {
            'round': firstRound + index,
            'roundsFromEnd': rounds.length - 1 - index,
            'matches': rounds[index],
          },
      ],
    },
  });
}

/// Slots a round needs to hold all its rows at their positions.
int _slotsNeeded(List<Row> rows) {
  var needed = rows.length;
  for (final row in rows) {
    final position = row['bracket_position'] as int?;
    if (position != null && position > needed) needed = position;
  }
  return needed;
}

Map<String, Object?> _bracketMatch(Row row) {
  Map<String, Object?>? team(String idKey, String nameKey) =>
      row[idKey] == null ? null : {'id': row[idKey], 'name': row[nameKey]};
  final home = team('home_team_id', 'home_name');
  final away = team('away_team_id', 'away_name');
  final status = row['status'] as String;
  final homeScore = row['home_score'] as int?;
  final awayScore = row['away_score'] as int?;
  Object? winnerId;
  if (status == 'bye') {
    winnerId = row['home_team_id'];
  } else if (status == 'played' && homeScore != null && awayScore != null) {
    winnerId = homeScore == awayScore
        ? row['winner_team_id']
        : homeScore > awayScore
        ? row['home_team_id']
        : row['away_team_id'];
  }
  return {
    'id': row['id'],
    'home': home,
    'away': away,
    'homeScore': homeScore,
    'awayScore': awayScore,
    'status': status,
    'winnerId': winnerId,
    'scheduledAt': row['scheduled_at'],
  };
}

Map<String, Object?> _pendingMatch({
  required int position,
  Map<String, Object?>? home,
  Map<String, Object?>? away,
}) => {
  'id': null,
  'position': position,
  'home': home,
  'away': away,
  'homeScore': null,
  'awayScore': null,
  'status': 'pending',
  'winnerId': null,
  'scheduledAt': null,
};

/// The team that won match [index] of [round], or null when not decided.
Map<String, Object?>? _winnerOf(List<Map<String, Object?>>? round, int index) {
  if (round == null || index >= round.length) return null;
  final match = round[index];
  final winnerId = match['winnerId'];
  if (winnerId == null) return null;
  for (final side in [match['home'], match['away']]) {
    if (side is Map<String, Object?> && side['id'] == winnerId) return side;
  }
  return null;
}

int _nextPowerOfTwo(int value) {
  var power = 1;
  while (power < value) {
    power *= 2;
  }
  return power;
}

int _log2(int powerOfTwo) {
  var exponent = 0;
  while ((1 << exponent) < powerOfTwo) {
    exponent++;
  }
  return exponent;
}

class _TeamRecord {
  _TeamRecord(Row team, int? userTeamId)
    : teamId = team['id'] as int,
      teamName = team['name'] as String,
      isUserTeam = team['id'] == userTeamId;

  final int teamId;
  final String teamName;
  final bool isUserTeam;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  int get played => wins + draws + losses;
  int get goalDifference => goalsFor - goalsAgainst;
  int get points => wins * _winPoints + draws * _drawPoints;

  void record({required int scored, required int conceded}) {
    goalsFor += scored;
    goalsAgainst += conceded;
    if (scored > conceded) {
      wins++;
    } else if (scored == conceded) {
      draws++;
    } else {
      losses++;
    }
  }

  /// Orders by points, goal difference, goals scored, then team name.
  static int compare(_TeamRecord left, _TeamRecord right) {
    for (final difference in [
      right.points - left.points,
      right.goalDifference - left.goalDifference,
      right.goalsFor - left.goalsFor,
    ]) {
      if (difference != 0) return difference;
    }
    return left.teamName.toLowerCase().compareTo(right.teamName.toLowerCase());
  }

  Map<String, Object?> toJson({required int position}) => {
    'position': position,
    'teamId': teamId,
    'teamName': teamName,
    'played': played,
    'wins': wins,
    'draws': draws,
    'losses': losses,
    'goalsFor': goalsFor,
    'goalsAgainst': goalsAgainst,
    'goalDifference': goalDifference,
    'points': points,
    'isUserTeam': isUserTeam,
  };
}

Row _findTournament(AppDatabase database, int tournamentId, int userId) {
  final rows = database.db.select('$_tournamentSelect WHERE t.id = ?', [
    userId,
    tournamentId,
  ]);
  if (rows.isEmpty) throw ApiException(404, 'Tournament not found.');
  return rows.first;
}

Map<String, Object?> _tournamentDetailJson(
  AppDatabase database,
  int tournamentId,
  int userId,
) {
  final tournament = _findTournament(database, tournamentId, userId);
  final teams = database.db.select(
    '''
      SELECT tt.id, tt.name, 1 + (SELECT COUNT(*) FROM join_requests jr
          WHERE jr.team_id = tt.id AND jr.status = 'accepted') AS players
      FROM tournament_teams tt
      WHERE tt.tournament_id = ? AND tt.status = 'active'
      ORDER BY tt.joined_at, tt.id
    ''',
    [tournamentId],
  );
  final myRequests = database.db.select(
    '''
      SELECT team_id, status FROM join_requests
      WHERE tournament_id = ? AND requester_id = ?
        AND status NOT IN ('cancelled', 'left', 'promoted', 'disbanded')
      ORDER BY id
    ''',
    [tournamentId, userId],
  );
  final isOpen = tournament['status'] == 'upcoming';
  final unseenDisbands = database.db.select(
    '''
      SELECT 1 FROM join_requests
      WHERE tournament_id = ? AND requester_id = ? AND status = 'disbanded'
        AND notice_seen_at IS NULL
    ''',
    [tournamentId, userId],
  );
  return {
    ..._tournamentJson(tournament),
    // A team the user played for was disbanded and they have not been told.
    'teamDisbanded': unseenDisbands.isNotEmpty,
    'teams': teams
        .map(
          (team) => {
            'id': team['id'],
            'name': team['name'],
            'players': team['players'],
          },
        )
        .toList(),
    // Unanswered requests expire once registration closes.
    'myRequests': myRequests
        .map(
          (row) => {
            'teamId': row['team_id'],
            'status': row['status'] == 'pending' && !isOpen
                ? 'expired'
                : row['status'],
          },
        )
        .toList(),
  };
}

/// What the signed-in user may do with their team while registration is
/// open. Captains leave alone only without players or matches; with players
/// they transfer captaincy or disband. Players can always leave before
/// kickoff, which keeps the team's fixtures.
({bool canLeave, bool canTransfer, bool canDisband}) _teamActions(Row row) {
  final isOpen = row['status'] == 'upcoming';
  final isCaptain = row['joined'] == 1;
  final isPlayer = !isCaptain && row['my_team_id'] != null;
  final hasPlayers = (row['my_team_players'] as int) > 0;
  final hasMatches = row['my_team_has_matches'] == 1;
  return (
    canLeave: isOpen && (isPlayer || (isCaptain && !hasPlayers && !hasMatches)),
    canTransfer: isOpen && isCaptain && hasPlayers,
    canDisband: isOpen && isCaptain && hasPlayers && !hasMatches,
  );
}

Map<String, Object?> _tournamentJson(Row row) {
  final actions = _teamActions(row);
  return {
    'id': row['id'],
    'name': row['name'],
    'description': row['description'],
    'format': row['format'],
    'status': row['status'],
    'startDate': row['start_date'],
    'endDate': row['end_date'],
    'maxTeams': row['max_teams'],
    'teamSize': row['team_size'],
    'currentTeams': row['current_teams'],
    'location': row['location'],
    'prize': row['prize'],
    'createdBy': row['created_by'] ?? '',
    'joined': row['joined'] == 1,
    'canLeave': actions.canLeave,
    'canTransfer': actions.canTransfer,
    'canDisband': actions.canDisband,
    'myTeamId': row['my_team_id'],
    'pendingRequests': row['pending_requests'],
  };
}

const _profileMatchLimit = 10;

/// Users taking part in each tournament: captains, players and requesters.
const _tournamentParticipants = '''
  (SELECT tournament_id, captain_id AS user_id FROM tournament_teams
    WHERE status = 'active'
    UNION
    SELECT tournament_id, requester_id FROM join_requests
    WHERE status IN ('pending', 'accepted'))
''';

/// Total pending requests for the signed-in captain in open tournaments.
Response _myTournamentRequests(Request request) {
  final rows = _database(request).db.select(
    '''
      SELECT COUNT(*) AS count FROM join_requests jr
      JOIN tournament_teams tt ON tt.id = jr.team_id
      JOIN tournaments t ON t.id = jr.tournament_id
      WHERE tt.captain_id = ? AND tt.status = 'active'
        AND jr.status = 'pending' AND t.status = 'upcoming'
    ''',
    [_userId(request)],
  );
  return _json({'pendingRequests': rows.first['count']});
}

Response _tournamentTeam(Request request) {
  final database = _database(request);
  final userId = _userId(request);
  final tournament = _findTournament(database, _tournamentId(request), userId);
  return _json({
    'team': _teamDetailJson(database, tournament, _teamId(request), userId),
  });
}

/// Removes an accepted player from the signed-in captain's team while
/// registration is open. The request is kept as `removed`, so the player can
/// join another team but not ask this one again.
Response _removeTeamMember(Request request) {
  final database = _database(request);
  final userId = _userId(request);
  final tournamentId = _tournamentId(request);
  final teamId = _teamId(request);
  final memberId = int.tryParse(request.params['memberId'] ?? '');
  if (memberId == null) throw ApiException(400, 'Invalid player.');
  final tournament = _findTournament(database, tournamentId, userId);
  final teams = database.db.select(
    '''
      SELECT captain_id FROM tournament_teams
      WHERE id = ? AND tournament_id = ? AND status = 'active'
    ''',
    [teamId, tournamentId],
  );
  // Other captains' teams are reported as missing.
  if (teams.isEmpty || teams.first['captain_id'] != userId) {
    throw ApiException(404, 'Team not found.');
  }
  if (memberId == userId) {
    throw ApiException(
      400,
      'Captains cannot remove themselves. Transfer captaincy or leave instead.',
    );
  }
  if (tournament['status'] != 'upcoming') throw _rosterLocked();

  database.db.execute(
    '''
      UPDATE join_requests
      SET status = 'removed', responded_at = CURRENT_TIMESTAMP
      WHERE team_id = ?1 AND requester_id = ?2 AND status = 'accepted'
        AND EXISTS (SELECT 1 FROM tournament_teams tt
          JOIN tournaments t ON t.id = tt.tournament_id
          WHERE tt.id = ?1 AND tt.captain_id = ?3 AND tt.status = 'active'
            AND t.status = 'upcoming')
    ''',
    [teamId, memberId, userId],
  );
  if (database.db.updatedRows == 0) {
    final latest = _findTournament(database, tournamentId, userId);
    if (latest['status'] != 'upcoming') throw _rosterLocked();
    throw ApiException(404, 'Player not found on this team.');
  }
  return _json({
    'team': _teamDetailJson(
      database,
      _findTournament(database, tournamentId, userId),
      teamId,
      userId,
    ),
  });
}

ApiException _rosterLocked() => ApiException(
  409,
  'Players can only be removed before the tournament starts.',
);

/// Team name, captain, players with game stats, and results so far.
Map<String, Object?> _teamDetailJson(
  AppDatabase database,
  Row tournament,
  int teamId,
  int userId,
) {
  final teams = database.db.select(
    '''
      SELECT tt.id, tt.name, tt.captain_id, u.username AS captain_name
      FROM tournament_teams tt
      JOIN users u ON u.id = tt.captain_id
      WHERE tt.id = ? AND tt.tournament_id = ? AND tt.status = 'active'
    ''',
    [teamId, tournament['id']],
  );
  if (teams.isEmpty) throw ApiException(404, 'Team not found.');
  final team = teams.first;
  final players = database.db.select(
    '''
      SELECT id, username, xp, current_streak, 1 AS is_captain,
        0 AS sort_group, 0 AS joined_order
      FROM users WHERE id = ?1
      UNION ALL
      SELECT u.id, u.username, u.xp, u.current_streak, 0, 1, jr.id
      FROM join_requests jr
      JOIN users u ON u.id = jr.requester_id
      WHERE jr.team_id = ?2 AND jr.status = 'accepted'
      ORDER BY sort_group, joined_order
    ''',
    [team['captain_id'], teamId],
  );
  final record = _TeamRecord(team, teamId);
  final matches = database.db.select(
    '''
      SELECT home_team_id, home_score, away_score
      FROM tournament_matches
      WHERE status = 'played' AND (home_team_id = ?1 OR away_team_id = ?1)
    ''',
    [teamId],
  );
  for (final match in matches) {
    final isHome = match['home_team_id'] == teamId;
    final homeScore = match['home_score'] as int;
    final awayScore = match['away_score'] as int;
    record.record(
      scored: isHome ? homeScore : awayScore,
      conceded: isHome ? awayScore : homeScore,
    );
  }
  final totalXp = players.fold<int>(0, (sum, row) => sum + (row['xp'] as int));
  final levels = players.fold<int>(
    0,
    (sum, row) => sum + levelForXp(row['xp'] as int),
  );
  return {
    'id': team['id'],
    'name': team['name'],
    'captainId': team['captain_id'],
    'captainName': team['captain_name'],
    'teamSize': tournament['team_size'],
    'canManage':
        team['captain_id'] == userId && tournament['status'] == 'upcoming',
    'players': [
      for (final player in players)
        {
          'id': player['id'],
          'username': player['username'],
          'xp': player['xp'],
          'level': levelForXp(player['xp'] as int),
          'currentStreak': player['current_streak'],
          'isCaptain': player['is_captain'] == 1,
        },
    ],
    'stats': {
      'players': players.length,
      'totalXp': totalXp,
      'averageLevel': players.isEmpty ? 0 : (levels / players.length).round(),
      'played': record.played,
      'wins': record.wins,
      'draws': record.draws,
      'losses': record.losses,
      'goalsFor': record.goalsFor,
      'goalsAgainst': record.goalsAgainst,
      'points': record.points,
    },
  };
}

/// Game stats, unlocked achievements and recent results of a player the
/// viewer knows: themselves, a friend, or someone in a shared tournament.
/// Anyone else is reported as missing so ids cannot be used to list players.
Response _userProfile(Request request) {
  final database = _database(request);
  final viewerId = _userId(request);
  final targetId = int.tryParse(request.params['userId'] ?? '');
  if (targetId == null) throw ApiException(400, 'Invalid player.');
  if (!_canViewProfile(database, viewerId, targetId)) {
    throw ApiException(404, 'Player not found.');
  }
  final users = database.db.select(
    '''
      SELECT id, username, xp, current_streak, best_streak
      FROM users WHERE id = ?
    ''',
    [targetId],
  );
  if (users.isEmpty) throw ApiException(404, 'Player not found.');
  final user = users.first;
  final level = levelForXp(user['xp'] as int);

  final unlocked = database.db.select(
    '''
      SELECT code, unlocked_at FROM user_achievements
      WHERE user_id = ? ORDER BY unlocked_at, code
    ''',
    [targetId],
  );
  final definitions = {
    for (final definition in achievements) definition.code: definition,
  };

  final matches = database.db.select(
    '''
      SELECT m.home_team_id, m.home_score, m.away_score, m.scheduled_at,
        t.name AS tournament_name, h.name AS home_name, a.name AS away_name,
        mine.team_id AS my_team_id
      FROM tournament_matches m
      JOIN tournaments t ON t.id = m.tournament_id
      JOIN tournament_teams h ON h.id = m.home_team_id
      JOIN tournament_teams a ON a.id = m.away_team_id
      JOIN (SELECT id AS team_id FROM tournament_teams WHERE captain_id = ?1
          UNION
          SELECT team_id FROM join_requests
          WHERE requester_id = ?1 AND status = 'accepted') mine
        ON mine.team_id IN (m.home_team_id, m.away_team_id)
      WHERE m.status = 'played'
      ORDER BY COALESCE(m.scheduled_at, '') DESC, m.id DESC
      LIMIT $_profileMatchLimit
    ''',
    [targetId],
  );

  return _json({
    'profile': {
      'id': user['id'],
      'username': user['username'],
      'xp': user['xp'],
      'level': level,
      'rank': rankForLevel(level),
      'currentStreak': user['current_streak'],
      'bestStreak': user['best_streak'],
      'achievements': [
        for (final badge in unlocked)
          if (definitions[badge['code']] case final definition?)
            {
              'code': definition.code,
              'title': definition.title,
              'icon': definition.icon,
              'unlockedAt': badge['unlocked_at'],
            },
      ],
      'recentMatches': [for (final match in matches) _profileMatchJson(match)],
    },
  });
}

Map<String, Object?> _profileMatchJson(Row match) {
  final isHome = match['my_team_id'] == match['home_team_id'];
  final homeScore = match['home_score'] as int;
  final awayScore = match['away_score'] as int;
  final goalsFor = isHome ? homeScore : awayScore;
  final goalsAgainst = isHome ? awayScore : homeScore;
  return {
    'tournamentName': match['tournament_name'],
    'teamName': isHome ? match['home_name'] : match['away_name'],
    'opponentName': isHome ? match['away_name'] : match['home_name'],
    'goalsFor': goalsFor,
    'goalsAgainst': goalsAgainst,
    'result': goalsFor > goalsAgainst
        ? 'win'
        : goalsFor == goalsAgainst
        ? 'draw'
        : 'loss',
    'playedAt': match['scheduled_at'],
  };
}

bool _canViewProfile(AppDatabase database, int viewerId, int targetId) {
  if (viewerId == targetId) return true;
  final rows = database.db.select(
    '''
      SELECT 1 FROM friendships
      WHERE status = 'accepted'
        AND ((requester_id = ?1 AND addressee_id = ?2)
          OR (requester_id = ?2 AND addressee_id = ?1))
      UNION ALL
      SELECT 1 FROM $_tournamentParticipants viewer
      JOIN $_tournamentParticipants target
        ON target.tournament_id = viewer.tournament_id
      WHERE viewer.user_id = ?1 AND target.user_id = ?2
      LIMIT 1
    ''',
    [viewerId, targetId],
  );
  return rows.isNotEmpty;
}

int _teamId(Request request) {
  final teamId = int.tryParse(request.params['teamId'] ?? '');
  if (teamId == null) throw ApiException(400, 'Invalid team.');
  return teamId;
}

int _tournamentId(Request request) {
  final tournamentId = int.tryParse(request.params['tournamentId'] ?? '');
  if (tournamentId == null) throw ApiException(400, 'Invalid tournament.');
  return tournamentId;
}

void _requireFriendship(AppDatabase database, int userId, int friendId) {
  if (friendId == userId) throw ApiException(400, 'Invalid friend account.');
  final rows = database.db.select(
    '''
      SELECT id FROM friendships
      WHERE status = 'accepted'
        AND ((requester_id = ? AND addressee_id = ?)
          OR (requester_id = ? AND addressee_id = ?))
    ''',
    [userId, friendId, friendId, userId],
  );
  if (rows.isEmpty) {
    throw ApiException(403, 'You can only chat with a friend.');
  }
}

Map<String, Object?> _friendJson(Row row) => {
  'id': row['id'],
  'username': row['username'],
};

int _friendId(Request request) {
  final friendId = int.tryParse(request.params['friendId'] ?? '');
  if (friendId == null) throw ApiException(400, 'Invalid friend account.');
  return friendId;
}

int _userId(Request request) => request.context['userId']! as int;

AppDatabase _database(Request request) =>
    request.context['database']! as AppDatabase;

Future<Map<String, dynamic>> _body(Request request) async {
  final decoded = jsonDecode(await request.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw ApiException(400, 'Request body must be a JSON object.');
  }
  return decoded;
}

String _requiredString(Map<String, dynamic> body, String key) {
  final value = body[key];
  if (value is! String || value.isEmpty) {
    throw ApiException(400, 'The "$key" field is required.');
  }
  return value;
}

Response _json(Object? value, {int status = 200}) => Response(
  status,
  body: jsonEncode(value),
  headers: {'content-type': 'application/json; charset=utf-8'},
);
