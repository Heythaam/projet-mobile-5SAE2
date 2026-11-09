// Stadium module — server side.
//
// Everything the Stadium module needs on the API lives in this one file:
// its tables, its validation rules and its routes. The rest of the backend
// only calls [createStadiumTables] (from database.dart) and
// [mountStadiumRoutes] (from app.dart).
//
// Isolation rules:
// * Stadium tables never reference users, XP, friends or messages. A stadium
//   stores its owner as an opaque `owner_id`; a booking stores its host as an
//   opaque `host_id` (plus a display-name snapshot) and an optional
//   `match_id` that belongs to the Match module.
// * Other modules use only the three public endpoints:
//     GET    /stadiums                       list open stadiums
//     GET    /stadiums/<id>/slots?date=      free and taken slots for a day
//     POST   /stadiums/<id>/bookings         hold a slot
//     DELETE /stadium-bookings/<id>          release a held slot
// * Owner screens use the /owner/... endpoints.

import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';

const stadiumPitchSizes = {'5v5', '7v7', '11v11'};
const stadiumSurfaces = {'turf', 'grass', 'indoor'};
const stadiumFeatures = {'lights', 'showers', 'parking', 'cafe'};
const stadiumSlotLengths = {60, 90, 120};
const stadiumEveningFrom = 20 * 60;
const _maxPitches = 8;
const _activeBooking = "('pending', 'confirmed')";

// ---------------------------------------------------------------------------
// Schema
// ---------------------------------------------------------------------------

void createStadiumTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS stadiums (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      owner_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      address TEXT NOT NULL,
      features TEXT NOT NULL DEFAULT '',
      open_days INTEGER NOT NULL,
      open_minute INTEGER NOT NULL,
      close_minute INTEGER NOT NULL,
      slot_minutes INTEGER NOT NULL,
      price_per_hour INTEGER NOT NULL,
      evening_surcharge INTEGER NOT NULL DEFAULT 0,
      paused INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS stadium_pitches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      stadium_id INTEGER NOT NULL REFERENCES stadiums(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      size TEXT NOT NULL,
      surface TEXT NOT NULL,
      position INTEGER NOT NULL DEFAULT 0
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS stadium_blocks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pitch_id INTEGER NOT NULL REFERENCES stadium_pitches(id) ON DELETE CASCADE,
      day TEXT NOT NULL,
      start_minute INTEGER NOT NULL,
      UNIQUE (pitch_id, day, start_minute)
    )
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS stadium_bookings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pitch_id INTEGER NOT NULL REFERENCES stadium_pitches(id) ON DELETE CASCADE,
      day TEXT NOT NULL,
      start_minute INTEGER NOT NULL,
      end_minute INTEGER NOT NULL,
      price INTEGER NOT NULL,
      host_id INTEGER NOT NULL,
      host_name TEXT NOT NULL,
      match_id TEXT,
      status TEXT NOT NULL
        CHECK (status IN ('pending', 'confirmed', 'declined', 'cancelled')),
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  ''');
  db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS stadium_bookings_active_slot
    ON stadium_bookings(pitch_id, day, start_minute)
    WHERE status IN $_activeBooking
  ''');
  db.execute('''
    CREATE TABLE IF NOT EXISTS stadium_owner_settings (
      owner_id INTEGER PRIMARY KEY,
      auto_confirm INTEGER NOT NULL DEFAULT 0
    )
  ''');
  db.execute(
    'CREATE INDEX IF NOT EXISTS stadiums_owner_idx ON stadiums(owner_id)',
  );
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

void mountStadiumRoutes(
  Router router, {
  required Handler Function(Handler handler) authenticated,
}) {
  Handler guarded(Handler handler) => authenticated(_guard(handler));

  router
    // Public contract used by other modules.
    ..get('/stadiums', guarded(_publicList))
    ..get('/stadiums/<stadiumId>/slots', guarded(_publicSlots))
    ..post('/stadiums/<stadiumId>/bookings', guarded(_holdSlot))
    ..delete('/stadium-bookings/<bookingId>', guarded(_releaseSlot))
    // Owner screens.
    ..get('/owner/stadiums', guarded(_ownerOverview))
    ..post('/owner/stadiums', guarded(_createStadium))
    ..get('/owner/stadiums/<stadiumId>', guarded(_ownerStadium))
    ..put('/owner/stadiums/<stadiumId>', guarded(_updateStadium))
    ..delete('/owner/stadiums/<stadiumId>', guarded(_deleteStadium))
    ..post('/owner/stadiums/<stadiumId>/pause', guarded(_pauseStadium))
    ..get(
      '/owner/stadiums/<stadiumId>/availability',
      guarded(_ownerAvailability),
    )
    ..post('/owner/stadiums/<stadiumId>/blocks', guarded(_blockSlot))
    ..delete('/owner/blocks/<blockId>', guarded(_unblockSlot))
    ..get('/owner/bookings', guarded(_ownerBookings))
    ..post('/owner/bookings/<bookingId>/<decision>', guarded(_decideBooking))
    ..put('/owner/settings', guarded(_updateSettings));
}

class _StadiumError implements Exception {
  _StadiumError(this.status, this.message);

  final int status;
  final String message;
}

Handler _guard(Handler handler) => (request) async {
  try {
    return await handler(request);
  } on _StadiumError catch (error) {
    return _json({'error': error.message}, status: error.status);
  } on FormatException {
    return _json({'error': 'Request body must be valid JSON.'}, status: 400);
  }
};

// ---------------------------------------------------------------------------
// Public contract
// ---------------------------------------------------------------------------

Response _publicList(Request request) {
  final db = _db(request);
  final rows = db.select(
    'SELECT * FROM stadiums WHERE paused = 0 ORDER BY name COLLATE NOCASE',
  );
  return _json({
    'stadiums': [for (final row in rows) _stadiumJson(db, row)],
  });
}

Response _publicSlots(Request request) {
  final db = _db(request);
  final stadium = _stadiumRow(db, _param(request, 'stadiumId'));
  if (stadium['paused'] == 1) {
    throw _StadiumError(404, 'Stadium not found.');
  }
  final day = _dayQuery(request);
  return _json(_availability(db, stadium, day, forOwner: false));
}

Future<Response> _holdSlot(Request request) async {
  final db = _db(request);
  final userId = _userId(request);
  final stadium = _stadiumRow(db, _param(request, 'stadiumId'));
  if (stadium['paused'] == 1) {
    throw _StadiumError(409, 'This stadium is not taking bookings right now.');
  }
  final body = await _body(request);
  final pitchId = _int(body, 'pitchId');
  final day = _parseDay(body['date']);
  final start = _int(body, 'start');
  final matchId = body['matchId'];
  if (matchId != null && (matchId is! String || matchId.length > 64)) {
    throw _StadiumError(400, 'Invalid match reference.');
  }

  final pitch = _pitchOf(db, stadium['id'] as int, pitchId);
  final slot = _slotsFor(stadium, day).where((slot) => slot.start == start);
  if (slot.isEmpty) {
    throw _StadiumError(400, 'That time is outside the stadium hours.');
  }
  if (_isPast(day, start)) {
    throw _StadiumError(400, 'That slot has already started.');
  }
  final blocked = db.select(
    'SELECT id FROM stadium_blocks WHERE pitch_id = ? AND day = ? AND start_minute = ?',
    [pitch['id'], day, start],
  );
  if (blocked.isNotEmpty) {
    throw _StadiumError(409, 'That slot is not available.');
  }

  final autoConfirm = _autoConfirm(db, stadium['owner_id'] as int);
  try {
    db.execute(
      '''
        INSERT INTO stadium_bookings
          (pitch_id, day, start_minute, end_minute, price, host_id, host_name,
           match_id, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        pitch['id'],
        day,
        start,
        slot.first.end,
        slot.first.price,
        userId,
        _displayName(db, userId),
        matchId,
        autoConfirm ? 'confirmed' : 'pending',
      ],
    );
  } on SqliteException catch (error) {
    if (error.message.contains('UNIQUE constraint failed')) {
      throw _StadiumError(409, 'Someone already holds that slot.');
    }
    rethrow;
  }
  final booking = _bookingRow(db, db.lastInsertRowId);
  return _json({'booking': _bookingJson(booking)}, status: 201);
}

Response _releaseSlot(Request request) {
  final db = _db(request);
  final booking = _bookingRow(db, _param(request, 'bookingId'));
  if (booking['host_id'] != _userId(request)) {
    throw _StadiumError(404, 'Booking not found.');
  }
  db.execute(
    "UPDATE stadium_bookings SET status = 'cancelled' "
    'WHERE id = ? AND status IN $_activeBooking',
    [booking['id']],
  );
  return Response(204);
}

// ---------------------------------------------------------------------------
// Owner: stadiums
// ---------------------------------------------------------------------------

Response _ownerOverview(Request request) {
  final db = _db(request);
  final ownerId = _userId(request);
  final today = _formatDay(DateTime.now());
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final weekStart = _formatDay(monday);
  final weekEnd = _formatDay(monday.add(const Duration(days: 6)));

  final stadiums = db.select(
    'SELECT * FROM stadiums WHERE owner_id = ? ORDER BY paused, id',
    [ownerId],
  );
  final cards = <Map<String, Object?>>[];
  for (final stadium in stadiums) {
    final json = _stadiumJson(db, stadium);
    final pitchCount = (json['pitches'] as List).length;
    final todayBooked = db
        .select(
          '''
        SELECT COUNT(*) AS n FROM stadium_bookings b
        JOIN stadium_pitches p ON p.id = b.pitch_id
        WHERE p.stadium_id = ? AND b.day = ? AND b.status IN $_activeBooking
      ''',
          [stadium['id'], today],
        )
        .first['n'];
    cards.add({
      ...json,
      'todayBooked': todayBooked,
      'todaySlots': _slotsFor(stadium, today).length * pitchCount,
    });
  }

  final totals = db
      .select(
        '''
      SELECT
        COALESCE(SUM(CASE WHEN b.day = ? THEN 1 ELSE 0 END), 0) AS today,
        COALESCE(SUM(CASE WHEN b.status = 'confirmed' AND b.day BETWEEN ? AND ?
          THEN b.price ELSE 0 END), 0) AS income,
        COALESCE(SUM(CASE WHEN b.status = 'pending' AND b.day >= ?
          THEN 1 ELSE 0 END), 0) AS pending
      FROM stadium_bookings b
      JOIN stadium_pitches p ON p.id = b.pitch_id
      JOIN stadiums s ON s.id = p.stadium_id
      WHERE s.owner_id = ? AND b.status IN $_activeBooking
    ''',
        [today, weekStart, weekEnd, today, ownerId],
      )
      .first;

  return _json({
    'todayBookings': totals['today'],
    'weekIncome': totals['income'],
    'pendingBookings': totals['pending'],
    'stadiums': cards,
  });
}

Future<Response> _createStadium(Request request) async {
  final db = _db(request);
  final input = _StadiumInput.parse(await _body(request));
  db.execute('BEGIN');
  try {
    db.execute(
      '''
        INSERT INTO stadiums
          (owner_id, name, phone, address, features, open_days, open_minute,
           close_minute, slot_minutes, price_per_hour, evening_surcharge)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [_userId(request), ...input.columns],
    );
    final stadiumId = db.lastInsertRowId;
    for (final (index, pitch) in input.pitches.indexed) {
      _insertPitch(db, stadiumId, index, pitch);
    }
    db.execute('COMMIT');
    return _json({
      'stadium': _stadiumJson(db, _stadiumRow(db, stadiumId)),
    }, status: 201);
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

Response _ownerStadium(Request request) {
  final db = _db(request);
  final stadium = _ownedStadium(request, db);
  return _json({'stadium': _stadiumJson(db, stadium)});
}

Future<Response> _updateStadium(Request request) async {
  final db = _db(request);
  final stadium = _ownedStadium(request, db);
  final stadiumId = stadium['id'] as int;
  final input = _StadiumInput.parse(await _body(request));

  final existing = {
    for (final row in db.select(
      'SELECT id, name FROM stadium_pitches WHERE stadium_id = ?',
      [stadiumId],
    ))
      row['id'] as int: row['name'] as String,
  };
  final kept = input.pitches.map((pitch) => pitch.id).whereType<int>().toSet();
  for (final id in kept) {
    if (!existing.containsKey(id)) {
      throw _StadiumError(400, 'Unknown pitch in this stadium.');
    }
  }
  final removed = existing.keys.where((id) => !kept.contains(id));
  for (final id in removed) {
    if (_hasUpcomingBookings(db, 'b.pitch_id = ?', [id])) {
      throw _StadiumError(
        409,
        'Pitch ${existing[id]} has upcoming bookings, so it cannot be removed.',
      );
    }
  }

  _requireBookingsStillFit(db, stadiumId, input);

  db.execute('BEGIN');
  try {
    db.execute(
      '''
        UPDATE stadiums SET name = ?, phone = ?, address = ?, features = ?,
          open_days = ?, open_minute = ?, close_minute = ?, slot_minutes = ?,
          price_per_hour = ?, evening_surcharge = ?
        WHERE id = ?
      ''',
      [...input.columns, stadiumId],
    );
    for (final id in removed) {
      db.execute('DELETE FROM stadium_pitches WHERE id = ?', [id]);
    }
    for (final (index, pitch) in input.pitches.indexed) {
      if (pitch.id == null) {
        _insertPitch(db, stadiumId, index, pitch);
      } else {
        db.execute(
          '''
            UPDATE stadium_pitches SET name = ?, size = ?, surface = ?,
              position = ?
            WHERE id = ?
          ''',
          [_pitchLetter(index), pitch.size, pitch.surface, index, pitch.id],
        );
      }
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
  return _json({'stadium': _stadiumJson(db, _stadiumRow(db, stadiumId))});
}

/// Refuses an edit of the opening days, hours or slot length that would leave
/// an upcoming pending or confirmed booking outside the new slots. Without this
/// the owner's inbox and the player's booking would point at a time that no
/// longer exists.
void _requireBookingsStillFit(Database db, int stadiumId, _StadiumInput input) {
  final next = <String, Object?>{
    'open_days': input.openDays,
    'open_minute': input.openMinute,
    'close_minute': input.closeMinute,
    'slot_minutes': input.slotMinutes,
    'price_per_hour': input.pricePerHour,
    'evening_surcharge': input.eveningSurcharge,
  };
  final rows = db.select(
    '''
      SELECT b.day, b.start_minute, b.end_minute FROM stadium_bookings b
      JOIN stadium_pitches p ON p.id = b.pitch_id
      WHERE p.stadium_id = ? AND b.status IN $_activeBooking AND b.day >= ?
      ORDER BY b.day, b.start_minute
    ''',
    [stadiumId, _formatDay(DateTime.now())],
  );
  for (final row in rows) {
    final day = row['day'] as String;
    final start = row['start_minute'] as int;
    final end = row['end_minute'] as int;
    if (_isFinished(day, end)) continue;
    final fits = _slotsFor(
      next,
      day,
    ).any((slot) => slot.start == start && slot.end == end);
    if (!fits) {
      final hour = (start ~/ 60).toString().padLeft(2, '0');
      final minute = (start % 60).toString().padLeft(2, '0');
      throw _StadiumError(
        409,
        'A booking on $day at $hour:$minute would no longer fit these '
        'hours. Answer or cancel it first.',
      );
    }
  }
}

Response _deleteStadium(Request request) {
  final db = _db(request);
  final stadium = _ownedStadium(request, db);
  if (_hasUpcomingBookings(db, 'p.stadium_id = ?', [stadium['id']])) {
    throw _StadiumError(
      409,
      'This stadium has upcoming bookings. Pause it instead.',
    );
  }
  db.execute('DELETE FROM stadiums WHERE id = ?', [stadium['id']]);
  return Response(204);
}

Future<Response> _pauseStadium(Request request) async {
  final db = _db(request);
  final stadium = _ownedStadium(request, db);
  final paused = (await _body(request))['paused'];
  if (paused is! bool) {
    throw _StadiumError(400, 'The "paused" field must be true or false.');
  }
  db.execute('UPDATE stadiums SET paused = ? WHERE id = ?', [
    paused ? 1 : 0,
    stadium['id'],
  ]);
  return _json({
    'stadium': _stadiumJson(db, _stadiumRow(db, stadium['id'] as int)),
  });
}

// ---------------------------------------------------------------------------
// Owner: availability and blocks
// ---------------------------------------------------------------------------

Response _ownerAvailability(Request request) {
  final db = _db(request);
  final stadium = _ownedStadium(request, db);
  return _json(_availability(db, stadium, _dayQuery(request), forOwner: true));
}

Future<Response> _blockSlot(Request request) async {
  final db = _db(request);
  final stadium = _ownedStadium(request, db);
  final body = await _body(request);
  final pitch = _pitchOf(db, stadium['id'] as int, _int(body, 'pitchId'));
  final day = _parseDay(body['date']);
  final start = _int(body, 'start');
  if (!_slotsFor(stadium, day).any((slot) => slot.start == start)) {
    throw _StadiumError(400, 'That time is outside the stadium hours.');
  }
  final booked = db.select(
    '''
      SELECT id FROM stadium_bookings
      WHERE pitch_id = ? AND day = ? AND start_minute = ?
        AND status IN $_activeBooking
    ''',
    [pitch['id'], day, start],
  );
  if (booked.isNotEmpty) {
    throw _StadiumError(409, 'That slot is already booked.');
  }
  db.execute(
    '''
      INSERT OR IGNORE INTO stadium_blocks (pitch_id, day, start_minute)
      VALUES (?, ?, ?)
    ''',
    [pitch['id'], day, start],
  );
  final block = db.select(
    'SELECT id FROM stadium_blocks WHERE pitch_id = ? AND day = ? AND start_minute = ?',
    [pitch['id'], day, start],
  ).first;
  return _json({'blockId': block['id']}, status: 201);
}

Response _unblockSlot(Request request) {
  final db = _db(request);
  final blockId = _param(request, 'blockId');
  final rows = db.select(
    '''
      SELECT k.id FROM stadium_blocks k
      JOIN stadium_pitches p ON p.id = k.pitch_id
      JOIN stadiums s ON s.id = p.stadium_id
      WHERE k.id = ? AND s.owner_id = ?
    ''',
    [blockId, _userId(request)],
  );
  if (rows.isEmpty) throw _StadiumError(404, 'Blocked slot not found.');
  db.execute('DELETE FROM stadium_blocks WHERE id = ?', [blockId]);
  return Response(204);
}

// ---------------------------------------------------------------------------
// Owner: bookings inbox
// ---------------------------------------------------------------------------

Response _ownerBookings(Request request) {
  final db = _db(request);
  final ownerId = _userId(request);
  final rows = db.select(
    '''
      SELECT b.*, p.name AS pitch_name, p.size AS pitch_size,
        s.id AS stadium_id, s.name AS stadium_name
      FROM stadium_bookings b
      JOIN stadium_pitches p ON p.id = b.pitch_id
      JOIN stadiums s ON s.id = p.stadium_id
      WHERE s.owner_id = ? AND b.status IN $_activeBooking AND b.day >= ?
      ORDER BY b.day, b.start_minute, p.position
    ''',
    [ownerId, _formatDay(DateTime.now())],
  );
  final upcoming = rows
      .where(
        (row) => !_isFinished(row['day'] as String, row['end_minute'] as int),
      )
      .map(_bookingJson)
      .toList();
  return _json({
    'autoConfirm': _autoConfirm(db, ownerId),
    'pending': upcoming.where((b) => b['status'] == 'pending').toList(),
    'confirmed': upcoming.where((b) => b['status'] == 'confirmed').toList(),
  });
}

Response _decideBooking(Request request) {
  final db = _db(request);
  final decision = request.params['decision'];
  if (decision != 'accept' && decision != 'decline') {
    throw _StadiumError(404, 'Unknown booking action.');
  }
  final bookingId = _param(request, 'bookingId');
  final rows = db.select(
    '''
      SELECT b.status FROM stadium_bookings b
      JOIN stadium_pitches p ON p.id = b.pitch_id
      JOIN stadiums s ON s.id = p.stadium_id
      WHERE b.id = ? AND s.owner_id = ?
    ''',
    [bookingId, _userId(request)],
  );
  if (rows.isEmpty) throw _StadiumError(404, 'Booking not found.');
  if (rows.first['status'] != 'pending') {
    throw _StadiumError(409, 'This booking was already handled.');
  }
  db.execute('UPDATE stadium_bookings SET status = ? WHERE id = ?', [
    decision == 'accept' ? 'confirmed' : 'declined',
    bookingId,
  ]);
  return _json({'booking': _bookingJson(_bookingRow(db, bookingId))});
}

Future<Response> _updateSettings(Request request) async {
  final db = _db(request);
  final autoConfirm = (await _body(request))['autoConfirm'];
  if (autoConfirm is! bool) {
    throw _StadiumError(400, 'The "autoConfirm" field must be true or false.');
  }
  db.execute(
    '''
      INSERT INTO stadium_owner_settings (owner_id, auto_confirm) VALUES (?, ?)
      ON CONFLICT(owner_id) DO UPDATE SET auto_confirm = excluded.auto_confirm
    ''',
    [_userId(request), autoConfirm ? 1 : 0],
  );
  return _json({'autoConfirm': autoConfirm});
}

// ---------------------------------------------------------------------------
// Input validation
// ---------------------------------------------------------------------------

class _PitchInput {
  _PitchInput(this.id, this.size, this.surface);

  final int? id;
  final String size;
  final String surface;
}

class _StadiumInput {
  _StadiumInput({
    required this.name,
    required this.phone,
    required this.address,
    required this.features,
    required this.openDays,
    required this.openMinute,
    required this.closeMinute,
    required this.slotMinutes,
    required this.pricePerHour,
    required this.eveningSurcharge,
    required this.pitches,
  });

  factory _StadiumInput.parse(Map<String, dynamic> body) {
    final name = _text(body, 'name', 'Stadium name', min: 2, max: 40);
    final phone = _text(body, 'phone', 'Contact number', min: 6, max: 20);
    if (!RegExp(r'^\+?[0-9 ]{6,20}$').hasMatch(phone)) {
      throw _StadiumError(400, 'Enter a valid contact number.');
    }
    final address = _text(body, 'address', 'Address', min: 3, max: 80);

    final rawFeatures = body['features'] ?? const <Object?>[];
    if (rawFeatures is! List ||
        rawFeatures.any((f) => !stadiumFeatures.contains(f))) {
      throw _StadiumError(400, 'Unknown stadium feature.');
    }
    final features = stadiumFeatures.where(rawFeatures.contains).toList();

    final openDays = _int(body, 'openDays');
    if (openDays < 1 || openDays > 127) {
      throw _StadiumError(400, 'Pick at least one open day.');
    }
    final slotMinutes = _int(body, 'slotMinutes');
    if (!stadiumSlotLengths.contains(slotMinutes)) {
      throw _StadiumError(400, 'Slot length must be 1h, 1.5h or 2h.');
    }
    final openMinute = _int(body, 'openMinute');
    final closeMinute = _int(body, 'closeMinute');
    if (openMinute < 0 ||
        closeMinute > 24 * 60 ||
        openMinute % 30 != 0 ||
        closeMinute % 30 != 0 ||
        closeMinute - openMinute < slotMinutes) {
      throw _StadiumError(
        400,
        'Opening hours must fit at least one ${_duration(slotMinutes)} slot.',
      );
    }
    final pricePerHour = _int(body, 'pricePerHour');
    if (pricePerHour < 1 || pricePerHour > 10000) {
      throw _StadiumError(400, 'Price per hour must be between 1 and 10000.');
    }
    final eveningSurcharge = _int(body, 'eveningSurcharge');
    if (eveningSurcharge < 0 || eveningSurcharge > 100) {
      throw _StadiumError(400, 'Evening surcharge must be 0-100%.');
    }

    final rawPitches = body['pitches'];
    if (rawPitches is! List || rawPitches.isEmpty) {
      throw _StadiumError(400, 'Add at least one pitch.');
    }
    if (rawPitches.length > _maxPitches) {
      throw _StadiumError(
        400,
        'A stadium can have up to $_maxPitches pitches.',
      );
    }
    final pitches = <_PitchInput>[];
    for (final raw in rawPitches) {
      if (raw is! Map ||
          !stadiumPitchSizes.contains(raw['size']) ||
          !stadiumSurfaces.contains(raw['surface']) ||
          (raw['id'] != null && raw['id'] is! int)) {
        throw _StadiumError(400, 'Each pitch needs a valid size and surface.');
      }
      pitches.add(
        _PitchInput(
          raw['id'] as int?,
          raw['size'] as String,
          raw['surface'] as String,
        ),
      );
    }

    return _StadiumInput(
      name: name,
      phone: phone,
      address: address,
      features: features,
      openDays: openDays,
      openMinute: openMinute,
      closeMinute: closeMinute,
      slotMinutes: slotMinutes,
      pricePerHour: pricePerHour,
      eveningSurcharge: eveningSurcharge,
      pitches: pitches,
    );
  }

  final String name;
  final String phone;
  final String address;
  final List<String> features;
  final int openDays;
  final int openMinute;
  final int closeMinute;
  final int slotMinutes;
  final int pricePerHour;
  final int eveningSurcharge;
  final List<_PitchInput> pitches;

  List<Object?> get columns => [
    name,
    phone,
    address,
    features.join(','),
    openDays,
    openMinute,
    closeMinute,
    slotMinutes,
    pricePerHour,
    eveningSurcharge,
  ];
}

String _text(
  Map<String, dynamic> body,
  String key,
  String label, {
  required int min,
  required int max,
}) {
  final value = body[key];
  final text = value is String ? value.trim() : '';
  if (text.length < min || text.length > max) {
    throw _StadiumError(400, '$label must be $min-$max characters.');
  }
  return text;
}

// ---------------------------------------------------------------------------
// Slots
// ---------------------------------------------------------------------------

class _Slot {
  const _Slot(this.start, this.end, this.price);

  final int start;
  final int end;
  final int price;
}

List<_Slot> _slotsFor(Map<String, Object?> stadium, String day) {
  final date = DateTime.parse(day);
  final openDays = stadium['open_days'] as int;
  if (openDays & (1 << (date.weekday - 1)) == 0) return const [];
  final length = stadium['slot_minutes'] as int;
  final close = stadium['close_minute'] as int;
  final hourly = stadium['price_per_hour'] as int;
  final surcharge = stadium['evening_surcharge'] as int;
  return [
    for (
      var start = stadium['open_minute'] as int;
      start + length <= close;
      start += length
    )
      _Slot(
        start,
        start + length,
        (hourly *
                length /
                60 *
                (start >= stadiumEveningFrom ? 1 + surcharge / 100 : 1))
            .round(),
      ),
  ];
}

Map<String, Object?> _availability(
  Database db,
  Row stadium,
  String day, {
  required bool forOwner,
}) {
  final slots = _slotsFor(stadium, day);
  final pitches = db.select(
    'SELECT * FROM stadium_pitches WHERE stadium_id = ? ORDER BY position, id',
    [stadium['id']],
  );
  final pitchJson = <Map<String, Object?>>[];
  for (final pitch in pitches) {
    final bookings = {
      for (final row in db.select(
        '''
          SELECT * FROM stadium_bookings
          WHERE pitch_id = ? AND day = ? AND status IN $_activeBooking
        ''',
        [pitch['id'], day],
      ))
        row['start_minute'] as int: row,
    };
    final blocks = {
      for (final row in db.select(
        'SELECT id, start_minute FROM stadium_blocks WHERE pitch_id = ? AND day = ?',
        [pitch['id'], day],
      ))
        row['start_minute'] as int: row['id'] as int,
    };
    pitchJson.add({
      ..._pitchJson(pitch),
      'slots': [
        for (final slot in slots)
          _slotJson(
            slot,
            day,
            bookings[slot.start],
            blocks[slot.start],
            forOwner,
          ),
      ],
    });
  }
  return {'date': day, 'open': slots.isNotEmpty, 'pitches': pitchJson};
}

Map<String, Object?> _slotJson(
  _Slot slot,
  String day,
  Row? booking,
  int? blockId,
  bool forOwner,
) {
  final String state;
  if (booking != null) {
    state = forOwner ? booking['status'] as String : 'taken';
  } else if (blockId != null) {
    state = forOwner ? 'blocked' : 'taken';
  } else if (_isPast(day, slot.start)) {
    state = 'past';
  } else {
    state = 'free';
  }
  return {
    'start': slot.start,
    'end': slot.end,
    'price': slot.price,
    'state': state,
    if (forOwner && booking != null) 'booking': _bookingJson(booking),
    if (forOwner && blockId != null) 'blockId': blockId,
  };
}

// ---------------------------------------------------------------------------
// Rows and JSON
// ---------------------------------------------------------------------------

Map<String, Object?> _stadiumJson(Database db, Row row) {
  final features = (row['features'] as String)
      .split(',')
      .where((feature) => feature.isNotEmpty)
      .toList();
  final pitches = db.select(
    'SELECT * FROM stadium_pitches WHERE stadium_id = ? ORDER BY position, id',
    [row['id']],
  );
  return {
    'id': row['id'],
    'name': row['name'],
    'phone': row['phone'],
    'address': row['address'],
    'features': features,
    'openDays': row['open_days'],
    'openMinute': row['open_minute'],
    'closeMinute': row['close_minute'],
    'slotMinutes': row['slot_minutes'],
    'pricePerHour': row['price_per_hour'],
    'eveningSurcharge': row['evening_surcharge'],
    'eveningFrom': stadiumEveningFrom,
    'paused': row['paused'] == 1,
    'pitches': pitches.map(_pitchJson).toList(),
  };
}

Map<String, Object?> _pitchJson(Row row) => {
  'id': row['id'],
  'name': row['name'],
  'size': row['size'],
  'surface': row['surface'],
};

Map<String, Object?> _bookingJson(Row row) => {
  'id': row['id'],
  'pitchId': row['pitch_id'],
  'date': row['day'],
  'start': row['start_minute'],
  'end': row['end_minute'],
  'price': row['price'],
  'hostName': row['host_name'],
  'matchId': row['match_id'],
  'status': row['status'],
  if (row.containsKey('pitch_name')) 'pitchName': row['pitch_name'],
  if (row.containsKey('pitch_size')) 'pitchSize': row['pitch_size'],
  if (row.containsKey('stadium_id')) 'stadiumId': row['stadium_id'],
  if (row.containsKey('stadium_name')) 'stadiumName': row['stadium_name'],
};

void _insertPitch(Database db, int stadiumId, int index, _PitchInput pitch) {
  db.execute(
    '''
      INSERT INTO stadium_pitches (stadium_id, name, size, surface, position)
      VALUES (?, ?, ?, ?, ?)
    ''',
    [stadiumId, _pitchLetter(index), pitch.size, pitch.surface, index],
  );
}

String _pitchLetter(int index) => String.fromCharCode(65 + index);

Row _stadiumRow(Database db, int id) {
  final rows = db.select('SELECT * FROM stadiums WHERE id = ?', [id]);
  if (rows.isEmpty) throw _StadiumError(404, 'Stadium not found.');
  return rows.first;
}

Row _ownedStadium(Request request, Database db) {
  final stadium = _stadiumRow(db, _param(request, 'stadiumId'));
  if (stadium['owner_id'] != _userId(request)) {
    throw _StadiumError(404, 'Stadium not found.');
  }
  return stadium;
}

Row _pitchOf(Database db, int stadiumId, int pitchId) {
  final rows = db.select(
    'SELECT * FROM stadium_pitches WHERE id = ? AND stadium_id = ?',
    [pitchId, stadiumId],
  );
  if (rows.isEmpty) throw _StadiumError(404, 'Pitch not found.');
  return rows.first;
}

Row _bookingRow(Database db, int id) {
  final rows = db.select('SELECT * FROM stadium_bookings WHERE id = ?', [id]);
  if (rows.isEmpty) throw _StadiumError(404, 'Booking not found.');
  return rows.first;
}

bool _hasUpcomingBookings(Database db, String where, List<Object?> args) {
  final rows = db.select(
    '''
      SELECT b.day, b.end_minute FROM stadium_bookings b
      JOIN stadium_pitches p ON p.id = b.pitch_id
      WHERE $where AND b.status IN $_activeBooking AND b.day >= ?
    ''',
    [...args, _formatDay(DateTime.now())],
  );
  return rows.any(
    (row) => !_isFinished(row['day'] as String, row['end_minute'] as int),
  );
}

bool _autoConfirm(Database db, int ownerId) {
  final rows = db.select(
    'SELECT auto_confirm FROM stadium_owner_settings WHERE owner_id = ?',
    [ownerId],
  );
  return rows.isNotEmpty && rows.first['auto_confirm'] == 1;
}

String _displayName(Database db, int userId) {
  // Read-only lookup for the inbox label; the booking keeps a snapshot so the
  // Stadium tables never depend on the users table.
  try {
    final rows = db.select('SELECT username FROM users WHERE id = ?', [userId]);
    if (rows.isNotEmpty) return rows.first['username'] as String;
  } on SqliteException {
    // The users table belongs to another module; fall back gracefully.
  }
  return 'Player';
}

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

String _formatDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _parseDay(Object? value) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      DateTime.tryParse(value) == null ||
      _formatDay(DateTime.parse(value)) != value) {
    throw _StadiumError(400, 'Dates must look like YYYY-MM-DD.');
  }
  return value;
}

String _dayQuery(Request request) => _parseDay(
  request.url.queryParameters['date'] ?? _formatDay(DateTime.now()),
);

DateTime _at(String day, int minute) =>
    DateTime.parse(day).add(Duration(minutes: minute));

bool _isPast(String day, int start) => !_at(day, start).isAfter(DateTime.now());

bool _isFinished(String day, int end) => !_at(day, end).isAfter(DateTime.now());

String _duration(int minutes) =>
    minutes % 60 == 0 ? '${minutes ~/ 60}h' : '${minutes / 60}h';

// ---------------------------------------------------------------------------
// Request helpers
// ---------------------------------------------------------------------------

Database _db(Request request) =>
    (request.context['database']! as AppDatabase).db;

int _userId(Request request) => request.context['userId']! as int;

int _param(Request request, String name) {
  final value = int.tryParse(request.params[name] ?? '');
  if (value == null) throw _StadiumError(404, 'Not found.');
  return value;
}

int _int(Map<String, dynamic> body, String key) {
  final value = body[key];
  if (value is! int) {
    throw _StadiumError(400, 'The "$key" field must be a whole number.');
  }
  return value;
}

Future<Map<String, dynamic>> _body(Request request) async {
  final decoded = jsonDecode(await request.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw _StadiumError(400, 'Request body must be a JSON object.');
  }
  return decoded;
}

Response _json(Object? value, {int status = 200}) => Response(
  status,
  body: jsonEncode(value),
  headers: {'content-type': 'application/json; charset=utf-8'},
);
