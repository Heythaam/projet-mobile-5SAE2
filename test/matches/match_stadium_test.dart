import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/local/local_database.dart';
import 'package:football_match_app/local/match_local_store.dart';
import 'package:football_match_app/matches/match_controller.dart';
import 'package:football_match_app/matches/stadium_directory.dart';
import 'package:football_match_app/screens/match/match_mock_data.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _pitchA = RealPitch(id: 11, name: 'A', size: '5v5');
const _pitchB = RealPitch(id: 12, name: 'B', size: '7v7');

const _arena = RealStadium(
  id: 5,
  name: 'Arena Nord',
  address: 'Rue du Stade, Tunis',
  pricePerHour: 60,
  pitches: [_pitchA, _pitchB],
);

class _FakeDirectory implements StadiumDirectory {
  List<RealStadium> list = const [_arena];
  Object? listError;
  Object? holdError;
  Object? releaseError;
  int nextBooking = 99;
  final holds = <Map<String, Object?>>[];
  final released = <int>[];

  @override
  Future<List<RealStadium>> stadiums() async {
    if (listError != null) throw listError!;
    return list;
  }

  @override
  Future<List<FreeSlot>> freeSlots(int stadiumId, DateTime day) async => [
    const FreeSlot(pitch: _pitchA, start: 18 * 60, end: 19 * 60, price: 60),
  ];

  @override
  Future<int> hold({
    required int stadiumId,
    required int pitchId,
    required DateTime day,
    required int start,
    required String matchCode,
  }) async {
    if (holdError != null) throw holdError!;
    holds.add({
      'stadiumId': stadiumId,
      'pitchId': pitchId,
      'day': day,
      'start': start,
      'matchCode': matchCode,
    });
    return nextBooking;
  }

  @override
  Future<void> release(int bookingId) async {
    if (releaseError != null) throw releaseError!;
    released.add(bookingId);
  }
}

void main() {
  sqfliteFfiInit();

  late Database db;
  late MatchLocalStore store;
  late _FakeDirectory directory;

  MatchController controller() => MatchController(
    uid: '1',
    username: 'Farouk',
    openStore: () async => store,
    stadiumDirectory: directory,
  );

  final tomorrow = DateUtils0.tomorrow();

  CreateMatchDraft realDraft({FreeSlot? slot}) => CreateMatchDraft(
    stadium: const MatchStadiumData(
      stadiumId: 5,
      name: 'Arena Nord',
      distance: 'Rue du Stade',
      coins: 60,
      players: 14,
    ),
    startsAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 18),
    visibility: 'Public',
    slot:
        slot ??
        const FreeSlot(pitch: _pitchB, start: 18 * 60, end: 19 * 60, price: 60),
  );

  setUp(() async {
    db = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    store = MatchLocalStore(db);
    directory = _FakeDirectory();
  });

  tearDown(() => db.close());

  group('loadStadiums', () {
    test('uses the real stadiums when the server answers', () async {
      final c = controller();
      await c.loadStadiums();
      expect(c.usingSampleStadiums, isFalse);
      expect(c.stadiums.single.stadiumId, 5);
      expect(c.stadiums.single.name, 'Arena Nord');
      expect(c.stadiums.single.distance, 'Rue du Stade');
      expect(c.stadiums.single.coins, 60);
      expect(c.stadiums.single.players, 14);
    });

    test('falls back to the sample list when the server fails', () async {
      directory.listError = const StadiumDirectoryException('offline');
      final c = controller();
      await c.loadStadiums();
      expect(c.usingSampleStadiums, isTrue);
      expect(c.stadiums, matchStadiums);
    });

    test('falls back to the sample list when no stadium is open', () async {
      directory.list = const [];
      final c = controller();
      await c.loadStadiums();
      expect(c.usingSampleStadiums, isTrue);
    });
  });

  group('createMatch in a real stadium', () {
    test('holds the slot, sizes the match by pitch and keeps the booking', () async {
      final c = controller();
      await c.load();
      final created = await c.createMatch(realDraft());
      expect(created.capacity, 14);
      expect(directory.holds.single['pitchId'], 12);
      expect(directory.holds.single['start'], 18 * 60);
      expect(directory.holds.single['matchCode'], created.code);
      expect((await store.getByCode(created.code))?.bookingId, 99);
    });

    test('removes the match again when the slot cannot be held', () async {
      directory.holdError = const StadiumDirectoryException(
        'Someone already holds that slot.',
        statusCode: 409,
      );
      final c = controller();
      await c.load();
      await expectLater(
        c.createMatch(realDraft()),
        throwsA(
          isA<MatchBookingException>().having(
            (e) => e.message,
            'message',
            'Someone already holds that slot.',
          ),
        ),
      );
      expect(await store.allUpcoming(), isEmpty);
      expect(c.upcomingMatch, isNull);
    });

    test('a sample stadium never calls the server', () async {
      final c = controller();
      await c.load();
      await c.createMatch(
        CreateMatchDraft(
          stadium: matchStadiums.first,
          startsAt: DateTime.now().add(const Duration(hours: 5)),
          visibility: 'Private',
        ),
      );
      expect(directory.holds, isEmpty);
    });
  });

  group('cancelMatch with a booking', () {
    test('releases the slot, then removes the match', () async {
      final c = controller();
      await c.load();
      final created = await c.createMatch(realDraft());
      expect(await c.cancelMatch(created.code), isTrue);
      expect(directory.released, [99]);
      expect(await store.getByCode(created.code), isNull);
    });

    test('keeps the match when the slot cannot be released', () async {
      final c = controller();
      await c.load();
      final created = await c.createMatch(realDraft());
      directory.releaseError = const StadiumDirectoryException('offline');
      expect(await c.cancelMatch(created.code), isFalse);
      expect(c.lastError, contains('stadium slot'));
      expect(await store.getByCode(created.code), isNotNull);
    });

    test('a booking the server no longer knows does not block cancel', () async {
      final c = controller();
      await c.load();
      final created = await c.createMatch(realDraft());
      directory.releaseError = const StadiumDirectoryException(
        'Booking not found.',
        statusCode: 404,
      );
      expect(await c.cancelMatch(created.code), isTrue);
      expect(await store.getByCode(created.code), isNull);
    });
  });

  test('freeSlots asks the server only for real stadiums', () async {
    final c = controller();
    final real = await c.freeSlots(realDraft().stadium, tomorrow);
    expect(real.single.startLabel, '18:00');
    expect(await c.freeSlots(matchStadiums.first, tomorrow), isEmpty);
  });

  group('HttpStadiumDirectory', () {
    http.Request? seen;
    setUp(() => seen = null);

    HttpStadiumDirectory directoryFor(
      http.Response Function(http.Request request) answer, {
      String? token = 't0ken',
    }) => HttpStadiumDirectory(
      client: MockClient((request) async {
        seen = request;
        return answer(request);
      }),
      readToken: () async => token,
      baseUrl: 'http://api.test',
    );

    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

    test('lists stadiums with the bearer token', () async {
      final api = directoryFor(
        (_) => json({
          'stadiums': [
            {
              'id': 5,
              'name': 'Arena Nord',
              'address': 'Rue du Stade, Tunis',
              'pricePerHour': 60,
              'pitches': [
                {'id': 11, 'name': 'A', 'size': '5v5', 'surface': 'turf'},
                {'id': 12, 'name': 'B', 'size': '11v11', 'surface': 'grass'},
              ],
            },
          ],
        }),
      );
      final list = await api.stadiums();
      expect(seen?.url.path, '/stadiums');
      expect(seen?.headers['authorization'], 'Bearer t0ken');
      expect(list.single.maxCapacity, 22);
      expect(list.single.pitches.first.capacity, 10);
    });

    test('free slots keep only free ones, sorted by time', () async {
      final api = directoryFor(
        (_) => json({
          'open': true,
          'pitches': [
            {
              'id': 11,
              'name': 'A',
              'size': '5v5',
              'slots': [
                {'start': 1140, 'end': 1200, 'price': 60, 'state': 'taken'},
                {'start': 1200, 'end': 1260, 'price': 72, 'state': 'free'},
              ],
            },
            {
              'id': 12,
              'name': 'B',
              'size': '7v7',
              'slots': [
                {'start': 1080, 'end': 1140, 'price': 60, 'state': 'free'},
                {'start': 1140, 'end': 1200, 'price': 60, 'state': 'past'},
              ],
            },
          ],
        }),
      );
      final slots = await api.freeSlots(5, DateTime(2026, 11, 20));
      expect(seen?.url.toString(), 'http://api.test/stadiums/5/slots?date=2026-11-20');
      expect(slots.map((s) => '${s.pitch.name} ${s.startLabel}'), [
        'B 18:00',
        'A 20:00',
      ]);
    });

    test('a closed day has no slots', () async {
      final api = directoryFor((_) => json({'open': false, 'pitches': []}));
      expect(await api.freeSlots(5, DateTime(2026, 11, 20)), isEmpty);
    });

    test('hold posts the match code and returns the booking id', () async {
      final api = directoryFor(
        (_) => json({
          'booking': {'id': 31, 'status': 'pending'},
        }, 201),
      );
      final id = await api.hold(
        stadiumId: 5,
        pitchId: 12,
        day: DateTime(2026, 11, 20),
        start: 1080,
        matchCode: 'K7X92',
      );
      expect(id, 31);
      expect(seen?.method, 'POST');
      expect(jsonDecode((seen as http.Request).body), {
        'pitchId': 12,
        'date': '2026-11-20',
        'start': 1080,
        'matchId': 'K7X92',
      });
    });

    test('release deletes the booking and accepts 204', () async {
      final api = directoryFor((_) => http.Response('', 204));
      await api.release(31);
      expect(seen?.method, 'DELETE');
      expect(seen?.url.path, '/stadium-bookings/31');
    });

    test('server errors keep their message and status', () async {
      final api = directoryFor(
        (_) => json({'error': 'Someone already holds that slot.'}, 409),
      );
      await expectLater(
        api.hold(
          stadiumId: 5,
          pitchId: 12,
          day: DateTime(2026, 11, 20),
          start: 1080,
          matchCode: 'K7X92',
        ),
        throwsA(
          isA<StadiumDirectoryException>()
              .having((e) => e.message, 'message', 'Someone already holds that slot.')
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('without a token it asks to sign in', () async {
      final api = directoryFor((_) => json({}), token: null);
      await expectLater(api.stadiums(), throwsA(isA<StadiumDirectoryException>()));
      expect(seen, isNull);
    });
  });
}

/// Midnight tomorrow, local time.
class DateUtils0 {
  static DateTime tomorrow() {
    final now = DateTime.now().add(const Duration(days: 1));
    return DateTime(now.year, now.month, now.day);
  }
}
