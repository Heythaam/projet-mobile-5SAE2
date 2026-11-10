import '../tournaments/cloud/tournament_store.dart';

/// Thrown when a stadium rule refuses a change; [status] mirrors the HTTP
/// status the old server used.
class StadiumFailure implements Exception {
  const StadiumFailure(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => message;
}

const _pitchSizes = {'5v5', '7v7', '11v11'};
const _surfaces = {'turf', 'grass', 'indoor'};
const _features = {'lights', 'showers', 'parking', 'cafe'};
const stadiumSlotLengths = {60, 90, 120};
const stadiumEveningFrom = 20 * 60;
const _maxPitches = 8;

/// Ids of pitches, blocks and bookings are `stadiumId * span + n`, so a
/// booking or a block can be found from its id alone.
const idSpan = 1000000;

int stadiumOfId(int childId) => childId ~/ idSpan;

class Slot {
  const Slot(this.start, this.end, this.price);

  final int start;
  final int end;
  final int price;
}

/// The stadium rules that used to run on the Dart server, applied to one
/// stadium document. Functions either change the document or throw a
/// [StadiumFailure]; the store saves only when nothing was thrown.
abstract final class StadiumRules {
  static Never _fail(int status, String message) =>
      throw StadiumFailure(status, message);

  static List<Doc> _list(Doc doc, String key) =>
      ((doc[key] as List<dynamic>?) ?? const []).cast<Doc>();

  static bool _active(Doc booking) =>
      booking['status'] == 'pending' || booking['status'] == 'confirmed';

  static int nextId(Doc doc) {
    final n = (doc['nextId'] as int?) ?? 1;
    doc['nextId'] = n + 1;
    return (doc['id'] as int) * idSpan + n;
  }

  // ---- Dates -------------------------------------------------------------

  static String formatDay(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String parseDay(Object? value) {
    if (value is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        DateTime.tryParse(value) == null ||
        formatDay(DateTime.parse(value)) != value) {
      _fail(400, 'Dates must look like YYYY-MM-DD.');
    }
    return value;
  }

  static DateTime _at(String day, int minute) =>
      DateTime.parse(day).add(Duration(minutes: minute));

  static bool _isPast(String day, int start) =>
      !_at(day, start).isAfter(DateTime.now());

  static bool _isFinished(String day, int end) =>
      !_at(day, end).isAfter(DateTime.now());

  static String _duration(int minutes) =>
      minutes % 60 == 0 ? '${minutes ~/ 60}h' : '${minutes / 60}h';

  // ---- Input -------------------------------------------------------------

  static int _int(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value is! int) _fail(400, 'The "$key" field must be a whole number.');
    return value;
  }

  static String _text(
    Map<String, dynamic> body,
    String key,
    String label, {
    required int min,
    required int max,
  }) {
    final value = body[key];
    final text = value is String ? value.trim() : '';
    if (text.length < min || text.length > max) {
      _fail(400, '$label must be $min-$max characters.');
    }
    return text;
  }

  /// Validates what the owner filled in; returns the cleaned values.
  static Doc parse(Map<String, dynamic> body) {
    final name = _text(body, 'name', 'Stadium name', min: 2, max: 40);
    final phone = _text(body, 'phone', 'Contact number', min: 6, max: 20);
    if (!RegExp(r'^\+?[0-9 ]{6,20}$').hasMatch(phone)) {
      _fail(400, 'Enter a valid contact number.');
    }
    final address = _text(body, 'address', 'Address', min: 3, max: 80);

    final rawFeatures = body['features'] ?? const <Object?>[];
    if (rawFeatures is! List ||
        rawFeatures.any((f) => !_features.contains(f))) {
      _fail(400, 'Unknown stadium feature.');
    }
    final features = _features.where(rawFeatures.contains).toList();

    final openDays = _int(body, 'openDays');
    if (openDays < 1 || openDays > 127) {
      _fail(400, 'Pick at least one open day.');
    }
    final slotMinutes = _int(body, 'slotMinutes');
    if (!stadiumSlotLengths.contains(slotMinutes)) {
      _fail(400, 'Slot length must be 1h, 1.5h or 2h.');
    }
    final openMinute = _int(body, 'openMinute');
    final closeMinute = _int(body, 'closeMinute');
    if (openMinute < 0 ||
        closeMinute > 24 * 60 ||
        openMinute % 30 != 0 ||
        closeMinute % 30 != 0 ||
        closeMinute - openMinute < slotMinutes) {
      _fail(
        400,
        'Opening hours must fit at least one ${_duration(slotMinutes)} slot.',
      );
    }
    final pricePerHour = _int(body, 'pricePerHour');
    if (pricePerHour < 1 || pricePerHour > 10000) {
      _fail(400, 'Price per hour must be between 1 and 10000.');
    }
    final eveningSurcharge = _int(body, 'eveningSurcharge');
    if (eveningSurcharge < 0 || eveningSurcharge > 100) {
      _fail(400, 'Evening surcharge must be 0-100%.');
    }

    final rawPitches = body['pitches'];
    if (rawPitches is! List || rawPitches.isEmpty) {
      _fail(400, 'Add at least one pitch.');
    }
    if (rawPitches.length > _maxPitches) {
      _fail(400, 'A stadium can have up to $_maxPitches pitches.');
    }
    final pitches = <Doc>[];
    for (final raw in rawPitches) {
      if (raw is! Map ||
          !_pitchSizes.contains(raw['size']) ||
          !_surfaces.contains(raw['surface']) ||
          (raw['id'] != null && raw['id'] is! int)) {
        _fail(400, 'Each pitch needs a valid size and surface.');
      }
      pitches.add({
        'id': raw['id'],
        'size': raw['size'],
        'surface': raw['surface'],
      });
    }
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'features': features,
      'openDays': openDays,
      'openMinute': openMinute,
      'closeMinute': closeMinute,
      'slotMinutes': slotMinutes,
      'pricePerHour': pricePerHour,
      'eveningSurcharge': eveningSurcharge,
      'pitches': pitches,
    };
  }

  static String _letter(int index) => String.fromCharCode(65 + index);

  static const _copied = [
    'name',
    'phone',
    'address',
    'features',
    'openDays',
    'openMinute',
    'closeMinute',
    'slotMinutes',
    'pricePerHour',
    'eveningSurcharge',
  ];

  static Doc create(int id, int ownerId, Doc input) {
    final doc = <String, dynamic>{
      'id': id,
      'ownerId': ownerId,
      'paused': false,
      'nextId': 1,
      'pitches': <Doc>[],
      'blocks': <Doc>[],
      'bookings': <Doc>[],
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    };
    for (final key in _copied) {
      doc[key] = input[key];
    }
    final pitches = <Doc>[];
    final given = _list(input, 'pitches');
    for (var i = 0; i < given.length; i++) {
      pitches.add({
        'id': nextId(doc),
        'name': _letter(i),
        'size': given[i]['size'],
        'surface': given[i]['surface'],
        'position': i,
      });
    }
    doc['pitches'] = pitches;
    return doc;
  }

  // ---- Slots -------------------------------------------------------------

  static List<Slot> slotsFor(Doc stadium, String day) {
    final date = DateTime.parse(day);
    final openDays = stadium['openDays'] as int;
    if (openDays & (1 << (date.weekday - 1)) == 0) return const [];
    final length = stadium['slotMinutes'] as int;
    final close = stadium['closeMinute'] as int;
    final hourly = stadium['pricePerHour'] as int;
    final surcharge = stadium['eveningSurcharge'] as int;
    return [
      for (
        var start = stadium['openMinute'] as int;
        start + length <= close;
        start += length
      )
        Slot(
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

  // ---- What the screens get ---------------------------------------------

  static Map<String, Object?> pitchJson(Doc pitch) => {
    'id': pitch['id'],
    'name': pitch['name'],
    'size': pitch['size'],
    'surface': pitch['surface'],
  };

  static List<Doc> _sortedPitches(Doc stadium) =>
      _list(stadium, 'pitches')..sort((a, b) {
        final byPosition = (a['position'] as int).compareTo(
          b['position'] as int,
        );
        return byPosition != 0
            ? byPosition
            : (a['id'] as int).compareTo(b['id'] as int);
      });

  static Map<String, Object?> stadiumJson(Doc row) => {
    'id': row['id'],
    'name': row['name'],
    'phone': row['phone'],
    'address': row['address'],
    'features': [...(row['features'] as List<dynamic>)],
    'openDays': row['openDays'],
    'openMinute': row['openMinute'],
    'closeMinute': row['closeMinute'],
    'slotMinutes': row['slotMinutes'],
    'pricePerHour': row['pricePerHour'],
    'eveningSurcharge': row['eveningSurcharge'],
    'eveningFrom': stadiumEveningFrom,
    'paused': row['paused'] == true,
    'pitches': [for (final p in _sortedPitches(row)) pitchJson(p)],
    'rating': rating(row),
    'reviewCount': _list(row, 'reviews').length,
  };

  // ---- Reviews -----------------------------------------------------------

  /// Average stars rounded to one decimal, or null before the first review.
  static double? rating(Doc stadium) {
    final reviews = _list(stadium, 'reviews');
    if (reviews.isEmpty) return null;
    final total = reviews.fold<int>(0, (sum, r) => sum + (r['stars'] as int));
    return double.parse((total / reviews.length).toStringAsFixed(1));
  }

  static Map<String, Object?> reviewsJson(Doc stadium, int me) {
    final reviews = [..._list(stadium, 'reviews')]
      ..sort(
        (a, b) =>
            (b['createdAtMs'] as int).compareTo(a['createdAtMs'] as int),
      );
    return {
      'rating': rating(stadium),
      'count': reviews.length,
      'canReview': _list(stadium, 'bookings').any(
        (b) => b['hostId'] == me && _active(b),
      ),
      'reviews': [
        for (final r in reviews)
          {
            'userName': r['userName'],
            'stars': r['stars'],
            'comment': r['comment'] ?? '',
            'createdAt': DateTime.fromMillisecondsSinceEpoch(
              r['createdAtMs'] as int,
              isUtc: true,
            ).toIso8601String(),
            'mine': r['userId'] == me,
          },
      ],
    };
  }

  /// Adds or replaces the player's review. Only players who booked this
  /// stadium can review it, and each player has one review.
  static void addReview(
    Doc stadium, {
    required int userId,
    required String userName,
    required int stars,
    required String comment,
  }) {
    if (stars < 1 || stars > 5) _fail(400, 'Pick 1 to 5 stars.');
    final text = comment.trim();
    if (text.length > 200) {
      _fail(400, 'A review can have up to 200 characters.');
    }
    final booked = _list(stadium, 'bookings').any(
      (b) => b['hostId'] == userId && _active(b),
    );
    if (!booked) _fail(403, 'Book this stadium before reviewing it.');
    final reviews = [..._list(stadium, 'reviews')];
    final entry = {
      'userId': userId,
      'userName': userName,
      'stars': stars,
      'comment': text,
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    };
    final index = reviews.indexWhere((r) => r['userId'] == userId);
    if (index >= 0) {
      reviews[index] = entry;
    } else {
      reviews.add(entry);
    }
    stadium['reviews'] = reviews;
  }

  static Map<String, Object?> bookingJson(
    Doc booking, {
    Doc? stadium,
    Doc? pitch,
  }) => {
    'id': booking['id'],
    'pitchId': booking['pitchId'],
    'date': booking['day'],
    'start': booking['start'],
    'end': booking['end'],
    'price': booking['price'],
    'hostName': booking['hostName'],
    'matchId': booking['matchId'],
    'status': booking['status'],
    if (pitch != null) 'pitchName': pitch['name'],
    if (pitch != null) 'pitchSize': pitch['size'],
    if (stadium != null) 'stadiumId': stadium['id'],
    if (stadium != null) 'stadiumName': stadium['name'],
  };

  static Map<String, Object?> availability(
    Doc stadium,
    String day, {
    required bool forOwner,
  }) {
    final slots = slotsFor(stadium, day);
    final pitchJsons = <Map<String, Object?>>[];
    for (final pitch in _sortedPitches(stadium)) {
      final bookings = <int, Doc>{
        for (final b in _list(stadium, 'bookings'))
          if (b['pitchId'] == pitch['id'] && b['day'] == day && _active(b))
            b['start'] as int: b,
      };
      final blocks = <int, int>{
        for (final k in _list(stadium, 'blocks'))
          if (k['pitchId'] == pitch['id'] && k['day'] == day)
            k['start'] as int: k['id'] as int,
      };
      pitchJsons.add({
        ...pitchJson(pitch),
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
    return {'date': day, 'open': slots.isNotEmpty, 'pitches': pitchJsons};
  }

  static Map<String, Object?> _slotJson(
    Slot slot,
    String day,
    Doc? booking,
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
      if (forOwner && booking != null) 'booking': bookingJson(booking),
      if (forOwner && blockId != null) 'blockId': blockId,
    };
  }

  // ---- Owner overview and inbox -----------------------------------------

  static Map<String, Object?> overview(List<Doc> owned) {
    final now = DateTime.now();
    final today = formatDay(now);
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final weekStart = formatDay(monday);
    final weekEnd = formatDay(monday.add(const Duration(days: 6)));
    final sorted = [...owned]
      ..sort((a, b) {
        final byPaused = (a['paused'] == true ? 1 : 0).compareTo(
          b['paused'] == true ? 1 : 0,
        );
        return byPaused != 0
            ? byPaused
            : (a['id'] as int).compareTo(b['id'] as int);
      });
    var todayCount = 0, income = 0, pending = 0;
    final cards = <Map<String, Object?>>[];
    for (final stadium in sorted) {
      final json = stadiumJson(stadium);
      final pitchCount = (json['pitches'] as List).length;
      var booked = 0;
      for (final b in _list(stadium, 'bookings')) {
        if (!_active(b)) continue;
        final day = b['day'] as String;
        if (day == today) {
          booked++;
          todayCount++;
        }
        if (b['status'] == 'confirmed' &&
            day.compareTo(weekStart) >= 0 &&
            day.compareTo(weekEnd) <= 0) {
          income += b['price'] as int;
        }
        if (b['status'] == 'pending' && day.compareTo(today) >= 0) pending++;
      }
      cards.add({
        ...json,
        'todayBooked': booked,
        'todaySlots': slotsFor(stadium, today).length * pitchCount,
      });
    }
    return {
      'todayBookings': todayCount,
      'weekIncome': income,
      'pendingBookings': pending,
      'stadiums': cards,
    };
  }

  static Map<String, Object?> inbox(List<Doc> owned, bool autoConfirm) {
    final today = formatDay(DateTime.now());
    final rows = <Map<String, Object?>>[];
    final order = <Map<String, Object?>, List<int>>{};
    for (final stadium in owned) {
      for (final b in _list(stadium, 'bookings')) {
        if (!_active(b) || (b['day'] as String).compareTo(today) < 0) continue;
        if (_isFinished(b['day'] as String, b['end'] as int)) continue;
        final pitch = _pitchOf(stadium, b['pitchId'] as int);
        final json = bookingJson(b, stadium: stadium, pitch: pitch);
        rows.add(json);
        order[json] = [pitch?['position'] as int? ?? 0];
      }
    }
    rows.sort((a, b) {
      final byDay = (a['date'] as String).compareTo(b['date'] as String);
      if (byDay != 0) return byDay;
      final byStart = (a['start'] as int).compareTo(b['start'] as int);
      return byStart != 0
          ? byStart
          : order[a]![0].compareTo(order[b]![0]);
    });
    return {
      'autoConfirm': autoConfirm,
      'pending': [
        for (final r in rows)
          if (r['status'] == 'pending') r,
      ],
      'confirmed': [
        for (final r in rows)
          if (r['status'] == 'confirmed') r,
      ],
    };
  }

  // ---- Lookups -----------------------------------------------------------

  static Doc? _pitchOf(Doc stadium, int pitchId) {
    for (final p in _list(stadium, 'pitches')) {
      if (p['id'] == pitchId) return p;
    }
    return null;
  }

  static Doc requirePitch(Doc stadium, int pitchId) =>
      _pitchOf(stadium, pitchId) ?? _fail(404, 'Pitch not found.');

  static void requireOwner(Doc stadium, int me) {
    if (stadium['ownerId'] != me) _fail(404, 'Stadium not found.');
  }

  static bool _hasUpcoming(Doc stadium, {int? pitchId}) {
    final today = formatDay(DateTime.now());
    return _list(stadium, 'bookings').any(
      (b) =>
          _active(b) &&
          (pitchId == null || b['pitchId'] == pitchId) &&
          (b['day'] as String).compareTo(today) >= 0 &&
          !_isFinished(b['day'] as String, b['end'] as int),
    );
  }

  // ---- Owner changes -----------------------------------------------------

  static void update(Doc stadium, int me, Doc input) {
    requireOwner(stadium, me);
    final existing = _list(stadium, 'pitches');
    final given = _list(input, 'pitches');
    final kept = <int>{
      for (final p in given)
        if (p['id'] is int) p['id'] as int,
    };
    final knownIds = {for (final p in existing) p['id'] as int};
    for (final id in kept) {
      if (!knownIds.contains(id)) _fail(400, 'Unknown pitch in this stadium.');
    }
    final removed = [
      for (final p in existing)
        if (!kept.contains(p['id'])) p,
    ];
    for (final p in removed) {
      if (_hasUpcoming(stadium, pitchId: p['id'] as int)) {
        _fail(
          409,
          'Pitch ${p['name']} has upcoming bookings, so it cannot be removed.',
        );
      }
    }
    _requireBookingsStillFit(stadium, input);

    final removedIds = {for (final p in removed) p['id'] as int};
    stadium['pitches'] = [
      for (final p in existing)
        if (!removedIds.contains(p['id'])) p,
    ];
    stadium['blocks'] = [
      for (final k in _list(stadium, 'blocks'))
        if (!removedIds.contains(k['pitchId'])) k,
    ];
    stadium['bookings'] = [
      for (final b in _list(stadium, 'bookings'))
        if (!removedIds.contains(b['pitchId'])) b,
    ];
    for (final key in _copied) {
      stadium[key] = input[key];
    }
    final pitches = _list(stadium, 'pitches');
    for (var i = 0; i < given.length; i++) {
      final id = given[i]['id'];
      if (id is int) {
        final pitch = pitches.firstWhere((p) => p['id'] == id);
        pitch['name'] = _letter(i);
        pitch['size'] = given[i]['size'];
        pitch['surface'] = given[i]['surface'];
        pitch['position'] = i;
      } else {
        pitches.add({
          'id': nextId(stadium),
          'name': _letter(i),
          'size': given[i]['size'],
          'surface': given[i]['surface'],
          'position': i,
        });
      }
    }
    stadium['pitches'] = pitches;
  }

  static void _requireBookingsStillFit(Doc stadium, Doc input) {
    final next = <String, dynamic>{
      'openDays': input['openDays'],
      'openMinute': input['openMinute'],
      'closeMinute': input['closeMinute'],
      'slotMinutes': input['slotMinutes'],
      'pricePerHour': input['pricePerHour'],
      'eveningSurcharge': input['eveningSurcharge'],
    };
    final today = formatDay(DateTime.now());
    final rows = [
      for (final b in _list(stadium, 'bookings'))
        if (_active(b) && (b['day'] as String).compareTo(today) >= 0) b,
    ]..sort((a, b) {
        final byDay = (a['day'] as String).compareTo(b['day'] as String);
        return byDay != 0
            ? byDay
            : (a['start'] as int).compareTo(b['start'] as int);
      });
    for (final row in rows) {
      final day = row['day'] as String;
      final start = row['start'] as int;
      final end = row['end'] as int;
      if (_isFinished(day, end)) continue;
      final fits = slotsFor(
        next,
        day,
      ).any((slot) => slot.start == start && slot.end == end);
      if (!fits) {
        final hour = (start ~/ 60).toString().padLeft(2, '0');
        final minute = (start % 60).toString().padLeft(2, '0');
        _fail(
          409,
          'A booking on $day at $hour:$minute would no longer fit these '
          'hours. Answer or cancel it first.',
        );
      }
    }
  }

  static void requireDeletable(Doc stadium, int me) {
    requireOwner(stadium, me);
    if (_hasUpcoming(stadium)) {
      _fail(409, 'This stadium has upcoming bookings. Pause it instead.');
    }
  }

  static void pause(Doc stadium, int me, bool paused) {
    requireOwner(stadium, me);
    stadium['paused'] = paused;
  }

  /// Blocks a slot and returns the block id.
  static int block(Doc stadium, int me, int pitchId, String day, int start) {
    requireOwner(stadium, me);
    final pitch = requirePitch(stadium, pitchId);
    if (!slotsFor(stadium, day).any((slot) => slot.start == start)) {
      _fail(400, 'That time is outside the stadium hours.');
    }
    final booked = _list(stadium, 'bookings').any(
      (b) =>
          b['pitchId'] == pitch['id'] &&
          b['day'] == day &&
          b['start'] == start &&
          _active(b),
    );
    if (booked) _fail(409, 'That slot is already booked.');
    final blocks = _list(stadium, 'blocks');
    for (final k in blocks) {
      if (k['pitchId'] == pitch['id'] && k['day'] == day && k['start'] == start) {
        return k['id'] as int;
      }
    }
    final id = nextId(stadium);
    blocks.add({'id': id, 'pitchId': pitch['id'], 'day': day, 'start': start});
    stadium['blocks'] = blocks;
    return id;
  }

  static void unblock(Doc stadium, int me, int blockId) {
    requireOwner(stadium, me);
    final blocks = _list(stadium, 'blocks');
    if (!blocks.any((k) => k['id'] == blockId)) {
      _fail(404, 'Blocked slot not found.');
    }
    stadium['blocks'] = [
      for (final k in blocks)
        if (k['id'] != blockId) k,
    ];
  }

  static Doc decide(Doc stadium, int me, int bookingId, {required bool accept}) {
    requireOwner(stadium, me);
    final booking = _list(stadium, 'bookings')
        .where((b) => b['id'] == bookingId)
        .firstOrNull;
    if (booking == null) _fail(404, 'Booking not found.');
    if (booking['status'] != 'pending') {
      _fail(409, 'This booking was already handled.');
    }
    booking['status'] = accept ? 'confirmed' : 'declined';
    return booking;
  }

  // ---- Player booking ----------------------------------------------------

  /// Holds a slot for [hostId] and returns the booking.
  static Doc hold(
    Doc stadium, {
    required int hostId,
    required String hostName,
    required int pitchId,
    required String day,
    required int start,
    required String? matchId,
    required bool autoConfirm,
  }) {
    if (stadium['paused'] == true) {
      _fail(409, 'This stadium is not taking bookings right now.');
    }
    if (matchId != null && matchId.length > 64) {
      _fail(400, 'Invalid match reference.');
    }
    final pitch = requirePitch(stadium, pitchId);
    final slot = slotsFor(stadium, day).where((s) => s.start == start);
    if (slot.isEmpty) _fail(400, 'That time is outside the stadium hours.');
    if (_isPast(day, start)) _fail(400, 'That slot has already started.');
    final blocked = _list(stadium, 'blocks').any(
      (k) => k['pitchId'] == pitch['id'] && k['day'] == day && k['start'] == start,
    );
    if (blocked) _fail(409, 'That slot is not available.');
    final taken = _list(stadium, 'bookings').any(
      (b) =>
          b['pitchId'] == pitch['id'] &&
          b['day'] == day &&
          b['start'] == start &&
          _active(b),
    );
    if (taken) _fail(409, 'Someone already holds that slot.');
    final booking = <String, dynamic>{
      'id': nextId(stadium),
      'pitchId': pitch['id'],
      'day': day,
      'start': start,
      'end': slot.first.end,
      'price': slot.first.price,
      'hostId': hostId,
      'hostName': hostName,
      'matchId': matchId,
      'status': autoConfirm ? 'confirmed' : 'pending',
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    };
    final bookings = _list(stadium, 'bookings')..add(booking);
    stadium['bookings'] = bookings;
    return booking;
  }

  static void release(Doc stadium, int me, int bookingId) {
    final booking = _list(stadium, 'bookings')
        .where((b) => b['id'] == bookingId)
        .firstOrNull;
    if (booking == null || booking['hostId'] != me) {
      _fail(404, 'Booking not found.');
    }
    if (_active(booking)) booking['status'] = 'cancelled';
  }
}
