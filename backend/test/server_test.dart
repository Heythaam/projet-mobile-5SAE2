import 'dart:convert';

import 'package:backend/app.dart';
import 'package:backend/database.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const _secret = 'test-secret-with-at-least-32-characters-long';

void main() {
  late AppDatabase database;
  late Handler app;

  setUp(() {
    database = AppDatabase(':memory:');
    app = createApp(database: database, jwtSecret: _secret);
  });

  tearDown(() => database.close());

  test(
    'registers accounts and signs in with the stored password hash',
    () async {
      final registration = await sendRequest(
        app,
        'POST',
        '/auth/register',
        body: {
          'username': 'player_one',
          'email': 'Player@example.com',
          'password': 'secure-pass-123',
        },
      );
      expect(registration.statusCode, 201);
      final registered = await decode(registration);
      expect(registered['user']['username'], 'player_one');
      expect(registered['token'], isA<String>());

      final login = await sendRequest(
        app,
        'POST',
        '/auth/login',
        body: {'email': 'player@example.com', 'password': 'secure-pass-123'},
      );
      expect(login.statusCode, 200);

      final duplicate = await sendRequest(
        app,
        'POST',
        '/auth/register',
        body: {
          'username': 'other_player',
          'email': 'player@example.com',
          'password': 'secure-pass-123',
        },
      );
      expect(duplicate.statusCode, 409);
    },
  );

  test('friends can accept requests and exchange messages', () async {
    final alice = await register(app, 'alice');
    final bob = await register(app, 'bob');

    final invite = await sendRequest(
      app,
      'POST',
      '/friend-requests',
      token: alice['token'] as String,
      body: {'username': 'bob'},
    );
    expect(invite.statusCode, 201);

    final incoming = await sendRequest(
      app,
      'GET',
      '/friend-requests',
      token: bob['token'] as String,
    );
    final incomingJson = await decode(incoming);
    final request = (incomingJson['requests'] as List).single;
    final requestId = request['id'] as int;
    final accepted = await sendRequest(
      app,
      'POST',
      '/friend-requests/$requestId/accept',
      token: bob['token'] as String,
    );
    expect(accepted.statusCode, 200);

    final send = await sendRequest(
      app,
      'POST',
      '/friends/${bob['user']['id']}/messages',
      token: alice['token'] as String,
      body: {'body': 'See you at kickoff!'},
    );
    expect(send.statusCode, 201);

    final messages = await sendRequest(
      app,
      'GET',
      '/friends/${alice['user']['id']}/messages',
      token: bob['token'] as String,
    );
    final messagesJson = await decode(messages);
    final received = (messagesJson['messages'] as List).single;
    expect(received['body'], 'See you at kickoff!');
    expect(received['senderId'], alice['user']['id']);

    final career = await sendRequest(
      app,
      'GET',
      '/gamification',
      token: alice['token'] as String,
    );
    expect(career.statusCode, 200);
    final careerJson = await decode(career);
    expect(careerJson['xp'], 310);
    expect(careerJson['level'], 2);
    expect(careerJson['currentStreak'], 1);
    expect(careerJson['sentMessages'], 1);
    final earned = (careerJson['achievements'] as List)
        .cast<Map<String, dynamic>>()
        .where((achievement) => achievement['unlockedAt'] != null)
        .map((achievement) => achievement['code'])
        .toSet();
    expect(
      earned,
      containsAll(['first_kickoff', 'first_teammate', 'first_message']),
    );

    final removed = await sendRequest(
      app,
      'DELETE',
      '/friends/${bob['user']['id']}',
      token: alice['token'] as String,
    );
    expect(removed.statusCode, 204);

    final blockedChat = await sendRequest(
      app,
      'GET',
      '/friends/${alice['user']['id']}/messages',
      token: bob['token'] as String,
    );
    expect(blockedChat.statusCode, 403);
  });

  test('rejects protected requests without a valid token', () async {
    final response = await sendRequest(app, 'GET', '/friends');
    expect(response.statusCode, 401);
  });
}

Future<Map<String, dynamic>> register(Handler app, String username) async {
  final response = await sendRequest(
    app,
    'POST',
    '/auth/register',
    body: {
      'username': username,
      'email': '$username@example.com',
      'password': 'secure-pass-123',
    },
  );
  expect(response.statusCode, 201);
  return decode(response);
}

Future<Response> sendRequest(
  Handler app,
  String method,
  String path, {
  Map<String, Object?>? body,
  String? token,
}) async {
  final headers = <String, String>{};
  if (body != null) headers['content-type'] = 'application/json';
  if (token != null) headers['authorization'] = 'Bearer $token';
  return await app(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    ),
  );
}

Future<Map<String, dynamic>> decode(Response response) async =>
    jsonDecode(await response.readAsString()) as Map<String, dynamic>;
