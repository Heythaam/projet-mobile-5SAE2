import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/local/local_database.dart';
import 'package:football_match_app/local/user_local_store.dart';
import 'package:football_match_app/screens/edit_profile_screen.dart';
import 'package:football_match_app/users/photo_source.dart';
import 'package:football_match_app/users/user_profile_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

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
    tall(tester);
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

  testWidgets('choosing an avatar from the pop-up is saved', (tester) async {
    tall(tester);
    final (db, controller) = (await tester.runAsync(setup))!;
    await tester.pumpWidget(
      MaterialApp(home: EditProfileScreen(controller: controller)),
    );
    await tester.tap(find.byKey(const ValueKey('avatar_choose')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('avatar_grid')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('avatar_choice_3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('avatar_grid')), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(controller.profile?.avatarId, 3 * 6);
    await tester.runAsync(db.close);
  });

  testWidgets('a taken username shows the error and stays open', (
    tester,
  ) async {
    tall(tester);
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

  testWidgets('a picked photo is saved, and replacing it deletes the old copy', (
    tester,
  ) async {
    tall(tester);
    final (db, controller) = (await tester.runAsync(setup))!;
    final photos = _FakePhotos(['/app/p1.jpg', '/app/p2.jpg']);
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(controller: controller, photos: photos),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('photo_gallery')));
    await tester.pump();
    expect(find.byKey(const ValueKey('avatar_photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('photo_remove')), findsOneWidget);

    // A second pick throws the unsaved first copy away.
    await tester.tap(find.byKey(const ValueKey('photo_camera')));
    await tester.pump();
    expect(photos.deleted, ['/app/p1.jpg']);

    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(controller.profile?.photoPath, '/app/p2.jpg');
    expect(photos.deleted, ['/app/p1.jpg']);
    await tester.runAsync(db.close);
  });

  testWidgets('removing the photo clears it and deletes the old file', (
    tester,
  ) async {
    tall(tester);
    final (db, controller) = (await tester.runAsync(setup))!;
    await tester.runAsync(() => controller.save(photoPath: '/app/old.jpg'));
    final photos = _FakePhotos([]);
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(controller: controller, photos: photos),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('photo_remove')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(controller.profile?.photoPath, isNull);
    expect(photos.deleted, ['/app/old.jpg']);
    await tester.runAsync(db.close);
  });

  testWidgets('a photo failure shows a message', (tester) async {
    tall(tester);
    final (db, controller) = (await tester.runAsync(setup))!;
    final photos = _FakePhotos([], fail: true);
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(controller: controller, photos: photos),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('photo_camera')));
    await tester.pump();
    expect(find.byKey(const ValueKey('edit_profile_error')), findsOneWidget);
    await tester.runAsync(db.close);
  });
}

class _FakePhotos implements PhotoSource {
  _FakePhotos(this.paths, {this.fail = false});

  final List<String> paths;
  final bool fail;
  final deleted = <String>[];

  @override
  Future<String?> pick(PhotoChoice choice) async {
    if (fail) throw const PhotoException('Could not get that photo.');
    return paths.isEmpty ? null : paths.removeAt(0);
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);
}
