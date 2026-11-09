// One story through the real API handlers, with an in-memory database:
// sign up and sign in, an owner creates a stadium, a player books a slot for
// a match, a second player is refused the same slot, the owner answers, an
// hours edit that would strand the booking is refused, the booking is
// released, friends are added, and the slot can be booked again.
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

  test('from sign in to a booked match slot', () async {
    // 1. Three accounts sign up; signing in again works and /me agrees.
    final owner = await _register(app, 'owner');
    final sami = await _register(app, 'sami');
    final yassine = await _register(app, 'yassine');
    final login = await _send(
      app,
      'POST',
      '/auth/login',
      body: {'email': 'sami@example.com', 'password': 'secure-pass-123'},
    );
    expect(login.statusCode, 200);
    final signedIn = await _decode(login);
    final me = await _decode(
      await _send(app, 'GET', '/me', token: signedIn['token'] as String),
    );
    expect(me['username'] ?? (me['user'] as Map)['username'], 'sami');

    // 2. The owner creates a stadium. Players see it in the public list.
    final created = await _send(
      app,
      'POST',
      '/owner/stadiums',
      token: owner,
      body: _stadiumBody,
    );
    expect(created.statusCode, 201);
    final stadium = (await _decode(created))['stadium'] as Map<String, dynamic>;
    final stadiumId = stadium['id'];
    final pitchId = (stadium['pitches'] as List).first['id'];

    final listed = await _decode(
      await _send(app, 'GET', '/stadiums', token: sami),
    );
    expect(
      (listed['stadiums'] as List).map((s) => (s as Map)['name']),
      contains('Arena Nord'),
    );

    // 3. Sami reads next week's free slots and holds 19:00 for match K7X92.
    final day = _day(DateTime.now().add(const Duration(days: 7)));
    Future<List<Map<String, dynamic>>> slotsOf(String token) async {
      final json = await _decode(
        await _send(
          app,
          'GET',
          '/stadiums/$stadiumId/slots?date=$day',
          token: token,
        ),
      );
      final pitch = (json['pitches'] as List).firstWhere(
        (p) => (p as Map)['id'] == pitchId,
      ) as Map<String, dynamic>;
      return (pitch['slots'] as List).cast<Map<String, dynamic>>();
    }

    Map<String, dynamic> at19(List<Map<String, dynamic>> slots) =>
        slots.firstWhere((s) => s['start'] == 19 * 60);

    expect(at19(await slotsOf(sami))['state'], 'free');
    final hold = await _send(
      app,
      'POST',
      '/stadiums/$stadiumId/bookings',
      token: sami,
      body: {
        'pitchId': pitchId,
        'date': day,
        'start': 19 * 60,
        'matchId': 'K7X92',
      },
    );
    expect(hold.statusCode, 201);
    final booking = (await _decode(hold))['booking'] as Map<String, dynamic>;
    expect(booking['matchId'], 'K7X92');
    expect(booking['hostName'], 'sami');

    // 4. Yassine sees the slot taken and cannot hold it.
    expect(at19(await slotsOf(yassine))['state'], 'taken');
    final clash = await _send(
      app,
      'POST',
      '/stadiums/$stadiumId/bookings',
      token: yassine,
      body: {'pitchId': pitchId, 'date': day, 'start': 19 * 60},
    );
    expect(clash.statusCode, 409);

    // 5. The owner finds the booking in the inbox with the match code, and
    // accepts it.
    final inbox = await _decode(
      await _send(app, 'GET', '/owner/bookings', token: owner),
    );
    final pending = (inbox['pending'] as List).single as Map<String, dynamic>;
    expect(pending['matchId'], 'K7X92');
    expect(pending['stadiumName'], 'Arena Nord');
    final accept = await _send(
      app,
      'POST',
      '/owner/bookings/${booking['id']}/accept',
      token: owner,
    );
    expect(accept.statusCode, 200);

    // 6. Hours edits that would strand the booking are refused; one that
    // keeps 19:00 is fine.
    final pitches = (stadium['pitches'] as List)
        .map((p) => {'id': (p as Map)['id'], 'size': p['size'], 'surface': p['surface']})
        .toList();
    Future<Response> edit(Map<String, Object?> changes) => _send(
      app,
      'PUT',
      '/owner/stadiums/$stadiumId',
      token: owner,
      body: {..._stadiumBody, 'pitches': pitches, ...changes},
    );
    expect((await edit({'closeMinute': 18 * 60})).statusCode, 409);
    expect((await edit({'slotMinutes': 90})).statusCode, 409);
    expect((await edit({'pricePerHour': 80})).statusCode, 200);

    // 7. Sami and Yassine become friends.
    expect(
      (await _send(
        app,
        'POST',
        '/friend-requests',
        token: yassine,
        body: {'username': 'sami'},
      )).statusCode,
      anyOf(200, 201),
    );
    final requests = await _decode(
      await _send(app, 'GET', '/friend-requests', token: sami),
    );
    final requestId = (requests['requests'] as List).single['id'];
    expect(
      (await _send(
        app,
        'POST',
        '/friend-requests/$requestId/accept',
        token: sami,
      )).statusCode,
      200,
    );
    final friends = await _decode(
      await _send(app, 'GET', '/friends', token: yassine),
    );
    expect((friends['friends'] as List).single['username'], 'sami');

    // 8. The host cancels the match: the booking is released, the slot is
    // free again and Yassine can take it.
    expect(
      (await _send(
        app,
        'DELETE',
        '/stadium-bookings/${booking['id']}',
        token: sami,
      )).statusCode,
      204,
    );
    expect(at19(await slotsOf(yassine))['state'], 'free');
    final second = await _send(
      app,
      'POST',
      '/stadiums/$stadiumId/bookings',
      token: yassine,
      body: {
        'pitchId': pitchId,
        'date': day,
        'start': 19 * 60,
        'matchId': 'P3Q4R',
      },
    );
    expect(second.statusCode, 201);

    // The first host can no longer release the new booking.
    final newId = ((await _decode(second))['booking'] as Map)['id'];
    expect(
      (await _send(app, 'DELETE', '/stadium-bookings/$newId', token: sami))
          .statusCode,
      404,
    );
  });
}

const _stadiumBody = <String, Object?>{
  'name': 'Arena Nord',
  'phone': '+216 20 123 456',
  'address': 'Rue du Stade, Tunis',
  'features': ['showers', 'lights'],
  'openDays': 127,
  'openMinute': 16 * 60,
  'closeMinute': 24 * 60,
  'slotMinutes': 60,
  'pricePerHour': 60,
  'eveningSurcharge': 20,
  'pitches': [
    {'size': '5v5', 'surface': 'turf'},
    {'size': '7v7', 'surface': 'indoor'},
  ],
};

String _day(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Future<String> _register(Handler app, String username) async {
  final response = await _send(
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
  return (await _decode(response))['token'] as String;
}

Future<Response> _send(
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

Future<Map<String, dynamic>> _decode(Response response) async =>
    jsonDecode(await response.readAsString()) as Map<String, dynamic>;
