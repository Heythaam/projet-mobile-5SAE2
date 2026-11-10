import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/bd/local_database.dart';
import 'package:football_match_app/bd/user_local_store.dart';
import 'package:football_match_app/views/user/people_screen.dart';
import 'package:football_match_app/services/user/user_profile_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  Future<(Database, UserProfileController)> setup() async {
    final db = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final store = UserLocalStore(db);
    await store.create(uid: '8', username: 'sami', email: 's@example.com');
    final controller = UserProfileController(
      uid: '7',
      accountUsername: 'farouk',
      email: 'f@example.com',
      openStore: () async => store,
    );
    await controller.load();
    return (db, controller);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  testWidgets('lists profiles, marks yours and searches', (tester) async {
    final (db, controller) = (await tester.runAsync(setup))!;
    await tester.pumpWidget(
      MaterialApp(home: PeopleScreen(controller: controller)),
    );
    await settle(tester);
    expect(find.text('@farouk (you)'), findsOneWidget);
    expect(find.text('@sami'), findsOneWidget);
    expect(find.byKey(const ValueKey('delete_7')), findsNothing);
    expect(find.byKey(const ValueKey('delete_8')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('people_search')), 'sam');
    await settle(tester);
    expect(find.text('@sami'), findsOneWidget);
    expect(find.text('@farouk (you)'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('people_search')), 'zzz');
    await settle(tester);
    expect(find.byKey(const ValueKey('people_empty')), findsOneWidget);
    await tester.runAsync(db.close);
  });

  testWidgets('deleting another profile asks first, then removes it', (
    tester,
  ) async {
    final (db, controller) = (await tester.runAsync(setup))!;
    await tester.pumpWidget(
      MaterialApp(home: PeopleScreen(controller: controller)),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('delete_8')));
    await tester.pumpAndSettle();
    expect(find.text('Delete @sami?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await settle(tester);
    await settle(tester);
    expect(find.text('@sami'), findsNothing);
    expect(find.text('@farouk (you)'), findsOneWidget);
    await tester.runAsync(db.close);
  });
}
