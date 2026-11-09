import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/local/local_database.dart';
import 'package:football_match_app/local/user_local_store.dart';
import 'package:football_match_app/screens/edit_profile_screen.dart';
import 'package:football_match_app/users/user_profile_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  Future<(Database, UserProfileController)> setup({bool taken = false}) async {
    final db = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final store = UserLocalStore(db);
    if (taken) {
      await store.create(uid: '8', username: 'sami', email: 's@example.com');
    }
    final controller = UserProfileController(
      uid: '7',
      accountUsername: 'farouk',
      email: 'f@example.com',
      openStore: () async => store,
    );
    await controller.load();
    return (db, controller);
  }

  testWidgets('saving updates the phone profile and closes the screen', (
    tester,
  ) async {
    final (db, controller) = (await tester.runAsync(setup))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => EditProfileScreen(controller: controller),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('edit_profile_bio')),
      'Left foot only',
    );
    await tester.tap(find.byKey(const ValueKey('position_FWD')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(controller.profile?.bio, 'Left foot only');
    expect(controller.profile?.position, 'FWD');
    await tester.runAsync(db.close);
  });

  testWidgets('a taken username shows the error and stays open', (
    tester,
  ) async {
    final (db, controller) = (await tester.runAsync(() => setup(taken: true)))!;
    await tester.pumpWidget(
      MaterialApp(home: EditProfileScreen(controller: controller)),
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit_profile_username')),
      'sami',
    );
    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('edit_profile_error')), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await tester.runAsync(db.close);
  });
}
