import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';
import 'gamification.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;
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
        return _json({'error': error.message}, status: error.status);
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
