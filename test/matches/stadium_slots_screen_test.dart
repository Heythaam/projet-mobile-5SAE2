import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/bd/local_database.dart';
import 'package:football_match_app/bd/match_local_store.dart';
import 'package:football_match_app/services/match/match_controller.dart';
import 'package:football_match_app/entities/stadium/real_stadium.dart';
import 'package:football_match_app/services/stadium/stadium_directory.dart';
import 'package:football_match_app/views/match/match_create_screens.dart';
import 'package:football_match_app/entities/match/match_mock_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Directory implements StadiumDirectory {
  _Directory(this.slots);

  final List<FreeSlot> slots;

  @override
  Future<List<RealStadium>> stadiums() async => const [];

  @override
  Future<List<FreeSlot>> freeSlots(int stadiumId, DateTime day) async => slots;

  @override
  Future<int> hold({
    required int stadiumId,
    required int pitchId,
    required DateTime day,
    required int start,
    required String matchCode,
  }) async => 1;

  @override
  Future<void> release(int bookingId) async {}
}

void main() {
  sqfliteFfiInit();

  const stadium = MatchStadiumData(
    stadiumId: 5,
    name: 'Arena Nord',
    distance: 'Rue du Stade',
    coins: 60,
    players: 14,
  );

  Future<void> open(WidgetTester tester, List<FreeSlot> slots) async {
    final controller = MatchController(
      uid: '1',
      username: 'Farouk',
      openStore: () async =>
          MatchLocalStore(await LocalDatabase.open(
            factory: databaseFactoryFfi,
            path: inMemoryDatabasePath,
          )),
      stadiumDirectory: _Directory(slots),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DateTimePickScreen(controller: controller, stadium: stadium),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a real stadium lists its free slots', (tester) async {
    await open(tester, const [
      FreeSlot(
        pitch: RealPitch(id: 11, name: 'A', size: '5v5'),
        start: 18 * 60,
        end: 19 * 60,
        price: 60,
      ),
    ]);
    // The default time is 18:00, so the pitch free then is offered.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('5v5 · 18:00'), findsOneWidget);
    expect(find.text('Choose a pitch'), findsOneWidget);
    expect(find.byKey(const ValueKey('pick_date')), findsOneWidget);
    expect(find.byKey(const ValueKey('pick_time')), findsOneWidget);
    // No list of hours any more.
    expect(find.text('08:00'), findsNothing);
  });

  testWidgets('a time with no free pitch lists the free start times', (
    tester,
  ) async {
    await open(tester, const [
      FreeSlot(
        pitch: RealPitch(id: 11, name: 'A', size: '5v5'),
        start: 20 * 60,
        end: 21 * 60,
        price: 60,
      ),
    ]);
    expect(find.byKey(const ValueKey('no_pitch_at_time')), findsOneWidget);
    expect(find.textContaining('20:00'), findsOneWidget);
  });

  testWidgets('a day without free slots says so', (tester) async {
    await open(tester, const []);
    expect(find.byKey(const ValueKey('no_slots')), findsOneWidget);
  });
}
