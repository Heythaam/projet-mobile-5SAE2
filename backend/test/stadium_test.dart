import 'dart:convert';

import 'package:backend/app.dart';
import 'package:backend/database.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const _secret = 'test-secret-with-at-least-32-characters-long';

void main() {
  late AppDatabase database;
  late Handler app;
  late String owner;
  late String player;
  final day = _day(DateTime.now().add(const Duration(days: 7)));

  setUp(() async {
    database = AppDatabase(':memory:');
    app = createApp(database: database, jwtSecret: _secret);
    owner = await _register(app, 'owner');
    player = await _register(app, 'player');
  });

  tearDown(() => database.close());

  Future<Map<String, dynamic>> createStadium({
    Map<String, Object?>? extra,
  }) async {
    final response = await _send(
      app,
      'POST',
      '/owner/stadiums',
      token: owner,
      body: {..._stadiumBody, ...?extra},
    );
    final json = await _decode(response);
    expect(response.statusCode, 201, reason: '$json');
    return json['stadium'] as Map<String, dynamic>;
  }

  test(
    'owner creates a stadium with lettered pitches and slot prices',
    () async {
      final stadium = await createStadium();
      expect(stadium['name'], 'Arena Nord');
      expect(stadium['features'], ['lights', 'showers']);
      final pitches = (stadium['pitches'] as List).cast<Map<String, dynamic>>();
      expect(pitches.map((p) => p['name']), ['A', 'B']);

      final overview = await _decode(
        await _send(app, 'GET', '/owner/stadiums', token: owner),
      );
      expect((overview['stadiums'] as List), hasLength(1));
      expect(overview['weekIncome'], 0);

      final availability = await _decode(
        await _send(
          app,
          'GET',
          '/owner/stadiums/${stadium['id']}/availability?date=$day',
          token: owner,
        ),
      );
      final slots = ((availability['pitches'] as List).first['slots'] as List)
          .cast<Map<String, dynamic>>();
      expect(slots, hasLength(8));
      expect(slots.first['start'], 16 * 60);
      expect(slots.first['price'], 60);
      expect(slots.firstWhere((s) => s['start'] == 20 * 60)['price'], 72);
      expect(slots.every((s) => s['state'] == 'free'), isTrue);
    },
  );

  test('rejects invalid stadium input', () async {
    for (final invalid in <Map<String, Object?>>[
      {'name': 'A'},
      {'phone': 'call me'},
      {'pitches': <Object?>[]},
      {'slotMinutes': 45},
      {'openMinute': 23 * 60, 'closeMinute': 23 * 60 + 30},
      {
        'features': ['pool'],
      },
      {'openDays': 0},
    ]) {
      final response = await _send(
        app,
        'POST',
        '/owner/stadiums',
        token: owner,
        body: {..._stadiumBody, ...invalid},
      );
      expect(response.statusCode, 400, reason: '$invalid');
    }
  });

  test('stadiums are private to their owner', () async {
    final stadium = await createStadium();
    final response = await _send(
      app,
      'GET',
      '/owner/stadiums/${stadium['id']}',
      token: player,
    );
    expect(response.statusCode, 404);
    final unauthenticated = await _send(app, 'GET', '/owner/stadiums');
    expect(unauthenticated.statusCode, 401);
  });

  test('players hold slots and owners accept or decline them', () async {
    final stadium = await createStadium();
    final pitchId = (stadium['pitches'] as List).first['id'];

    final hold = await _send(
      app,
      'POST',
      '/stadiums/${stadium['id']}/bookings',
      token: player,
      body: {
        'pitchId': pitchId,
        'date': day,
        'start': 19 * 60,
        'matchId': 'm1',
      },
    );
    expect(hold.statusCode, 201);
    final booking = (await _decode(hold))['booking'] as Map<String, dynamic>;
    expect(booking['status'], 'pending');
    expect(booking['hostName'], 'player');

    final doubleHold = await _send(
      app,
      'POST',
      '/stadiums/${stadium['id']}/bookings',
      token: owner,
      body: {'pitchId': pitchId, 'date': day, 'start': 19 * 60},
    );
    expect(doubleHold.statusCode, 409);

    final publicSlots = await _decode(
      await _send(
        app,
        'GET',
        '/stadiums/${stadium['id']}/slots?date=$day',
        token: player,
      ),
    );
    final publicSlot = ((publicSlots['pitches'] as List).first['slots'] as List)
        .firstWhere((s) => s['start'] == 19 * 60);
    expect(publicSlot['state'], 'taken');
    expect(publicSlot.containsKey('booking'), isFalse);

    final inbox = await _decode(
      await _send(app, 'GET', '/owner/bookings', token: owner),
    );
    expect((inbox['pending'] as List).single['stadiumName'], 'Arena Nord');

    final accept = await _send(
      app,
      'POST',
      '/owner/bookings/${booking['id']}/accept',
      token: owner,
    );
    expect(accept.statusCode, 200);
    final again = await _send(
      app,
      'POST',
      '/owner/bookings/${booking['id']}/decline',
      token: owner,
    );
    expect(again.statusCode, 409);

    final confirmed = await _decode(
      await _send(app, 'GET', '/owner/bookings', token: owner),
    );
    expect(confirmed['pending'], isEmpty);
    expect((confirmed['confirmed'] as List).single['pitchName'], 'A');

    final removePitch = await _send(
      app,
      'PUT',
      '/owner/stadiums/${stadium['id']}',
      token: owner,
      body: {
        ..._stadiumBody,
        'pitches': [
          {
            'id': (stadium['pitches'] as List).last['id'],
            'size': '7v7',
            'surface': 'indoor',
          },
        ],
      },
    );
    expect(removePitch.statusCode, 409);

    final delete = await _send(
      app,
      'DELETE',
      '/owner/stadiums/${stadium['id']}',
      token: owner,
    );
    expect(delete.statusCode, 409);

    final release = await _send(
      app,
      'DELETE',
      '/stadium-bookings/${booking['id']}',
      token: player,
    );
    expect(release.statusCode, 204);
    final afterRelease = await _decode(
      await _send(app, 'GET', '/owner/bookings', token: owner),
    );
    expect(afterRelease['confirmed'], isEmpty);
  });

  test('auto-confirm, blocks and pause control availability', () async {
    final stadium = await createStadium();
    final id = stadium['id'];
    final pitchId = (stadium['pitches'] as List).first['id'];

    final settings = await _send(
      app,
      'PUT',
      '/owner/settings',
      token: owner,
      body: {'autoConfirm': true},
    );
    expect(settings.statusCode, 200);
    final hold = await _send(
      app,
      'POST',
      '/stadiums/$id/bookings',
      token: player,
      body: {'pitchId': pitchId, 'date': day, 'start': 17 * 60},
    );
    expect((await _decode(hold))['booking']['status'], 'confirmed');

    final block = await _send(
      app,
      'POST',
      '/owner/stadiums/$id/blocks',
      token: owner,
      body: {'pitchId': pitchId, 'date': day, 'start': 21 * 60},
    );
    expect(block.statusCode, 201);
    final blockId = (await _decode(block))['blockId'];
    final blockedHold = await _send(
      app,
      'POST',
      '/stadiums/$id/bookings',
      token: player,
      body: {'pitchId': pitchId, 'date': day, 'start': 21 * 60},
    );
    expect(blockedHold.statusCode, 409);
    final blockBooked = await _send(
      app,
      'POST',
      '/owner/stadiums/$id/blocks',
      token: owner,
      body: {'pitchId': pitchId, 'date': day, 'start': 17 * 60},
    );
    expect(blockBooked.statusCode, 409);

    final ownerView = await _decode(
      await _send(
        app,
        'GET',
        '/owner/stadiums/$id/availability?date=$day',
        token: owner,
      ),
    );
    final states = {
      for (final slot
          in ((ownerView['pitches'] as List).first['slots'] as List))
        slot['start']: slot['state'],
    };
    expect(states[17 * 60], 'confirmed');
    expect(states[21 * 60], 'blocked');

    final unblock = await _send(
      app,
      'DELETE',
      '/owner/blocks/$blockId',
      token: owner,
    );
    expect(unblock.statusCode, 204);

    final pause = await _send(
      app,
      'POST',
      '/owner/stadiums/$id/pause',
      token: owner,
      body: {'paused': true},
    );
    expect((await _decode(pause))['stadium']['paused'], isTrue);
    final publicList = await _decode(
      await _send(app, 'GET', '/stadiums', token: player),
    );
    expect(publicList['stadiums'], isEmpty);
    final pausedHold = await _send(
      app,
      'POST',
      '/stadiums/$id/bookings',
      token: player,
      body: {'pitchId': pitchId, 'date': day, 'start': 22 * 60},
    );
    expect(pausedHold.statusCode, 409);
  });

  test('closed days have no slots and editing keeps pitch ids', () async {
    final stadium = await createStadium();
    final id = stadium['id'];
    final pitches = (stadium['pitches'] as List).cast<Map<String, dynamic>>();
    final weekday = DateTime.parse(day).weekday;
    final update = await _send(
      app,
      'PUT',
      '/owner/stadiums/$id',
      token: owner,
      body: {
        ..._stadiumBody,
        'openDays': 127 & ~(1 << (weekday - 1)),
        'pitches': [
          {'id': pitches.last['id'], 'size': '11v11', 'surface': 'grass'},
          {'size': '5v5', 'surface': 'indoor'},
        ],
      },
    );
    expect(update.statusCode, 200);
    final updated = (await _decode(update))['stadium'] as Map<String, dynamic>;
    final updatedPitches = (updated['pitches'] as List)
        .cast<Map<String, dynamic>>();
    expect(updatedPitches.first['id'], pitches.last['id']);
    expect(updatedPitches.map((p) => p['name']), ['A', 'B']);
    expect(updatedPitches.first['size'], '11v11');

    final closed = await _decode(
      await _send(
        app,
        'GET',
        '/owner/stadiums/$id/availability?date=$day',
        token: owner,
      ),
    );
    expect(closed['open'], isFalse);

    final delete = await _send(
      app,
      'DELETE',
      '/owner/stadiums/$id',
      token: owner,
    );
    expect(delete.statusCode, 204);
  });

  test('hours edits that strand a booking are refused', () async {
    final stadium = await createStadium();
    final id = stadium['id'];
    final pitchId = (stadium['pitches'] as List).first['id'];
    final pitches = (stadium['pitches'] as List)
        .map((p) => {'id': (p as Map)['id'], 'size': p['size'], 'surface': p['surface']})
        .toList();
    final hold = await _send(
      app,
      'POST',
      '/stadiums/$id/bookings',
      token: player,
      body: {'pitchId': pitchId, 'date': day, 'start': 19 * 60},
    );
    expect(hold.statusCode, 201);

    Future<Response> edit(Map<String, Object?> changes) => _send(
      app,
      'PUT',
      '/owner/stadiums/$id',
      token: owner,
      body: {..._stadiumBody, 'pitches': pitches, ...changes},
    );

    // Closing before the booking, a 90 minute grid and a closed weekday all
    // move or remove the 19:00 slot.
    expect((await edit({'closeMinute': 18 * 60})).statusCode, 409);
    expect((await edit({'slotMinutes': 90})).statusCode, 409);
    final weekday = DateTime.parse(day).weekday;
    expect(
      (await edit({'openDays': 127 & ~(1 << (weekday - 1))})).statusCode,
      409,
    );

    // Edits that keep 19:00 as a slot still work, price changes included.
    expect(
      (await edit({'closeMinute': 22 * 60, 'pricePerHour': 80})).statusCode,
      200,
    );

    // After the booking is cancelled the hours are free to change.
    final bookingId = ((await _decode(hold))['booking'] as Map)['id'];
    final cancel = await _send(
      app,
      'DELETE',
      '/stadium-bookings/$bookingId',
      token: player,
    );
    expect(cancel.statusCode, 204);
    expect((await edit({'closeMinute': 18 * 60})).statusCode, 200);
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
