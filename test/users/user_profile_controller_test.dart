import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/local/local_database.dart';
import 'package:football_match_app/local/user_local_store.dart';
import 'package:football_match_app/users/avatar_palette.dart';
import 'package:football_match_app/users/user_profile_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late UserLocalStore store;

  UserProfileController make({String uid = '7', String name = 'farouk'}) =>
      UserProfileController(
        uid: uid,
        accountUsername: name,
        email: 'f@example.com',
        openStore: () async => store,
      );

  setUp(() async {
    db = await LocalDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    store = UserLocalStore(db);
  });

  tearDown(() => db.close());

  test('load creates the phone profile from the account once', () async {
    final controller = make();
    expect(controller.profile, isNull);
    await controller.load();
    expect(controller.loaded, isTrue);
    expect(controller.profile?.username, 'farouk');
    expect(controller.profile?.email, 'f@example.com');
    await controller.load();
    expect((await db.query('users')), hasLength(1));
  });

  test('load keeps an edited profile instead of the account name', () async {
    await store.create(uid: '7', username: 'edited', email: 'f@example.com');
    final controller = make();
    await controller.load();
    expect(controller.profile?.username, 'edited');
  });

  test('load reports an account name the phone cannot store', () async {
    final controller = make(name: 'x');
    await controller.load();
    expect(controller.profile, isNull);
    expect(controller.lastError, isNotNull);
  });

  test('save changes the profile and notifies', () async {
    final controller = make();
    await controller.load();
    var notified = 0;
    controller.addListener(() => notified++);
    final saved = await controller.save(
      username: 'Captain_F',
      bio: '  Left foot only ',
      position: 'MID',
      avatarId: 3,
    );
    expect(saved, isTrue);
    expect(notified, 1);
    expect(controller.profile?.username, 'captain_f');
    expect(controller.profile?.bio, 'Left foot only');
    expect(controller.profile?.position, 'MID');
    expect(controller.profile?.avatarId, 3);
    expect((await store.getByUid('7'))?.position, 'MID');
  });

  test('save can clear the position', () async {
    final controller = make();
    await controller.load();
    await controller.save(position: 'GK');
    expect(controller.profile?.position, 'GK');
    await controller.save(clearPosition: true);
    expect(controller.profile?.position, isNull);
  });

  test('save fails with a message when the username is taken', () async {
    await store.create(uid: '8', username: 'sami', email: 's@example.com');
    final controller = make();
    await controller.load();
    final saved = await controller.save(username: 'Sami');
    expect(saved, isFalse);
    expect(controller.lastError, isNotNull);
    expect(controller.profile?.username, 'farouk');
  });

  test('resetProfile goes back to the account details', () async {
    final controller = make();
    await controller.load();
    await controller.save(
      username: 'captain',
      bio: 'hello',
      position: 'GK',
      avatarId: 4,
    );
    final reset = await controller.resetProfile();
    expect(reset, isTrue);
    expect(controller.profile?.username, 'farouk');
    expect(controller.profile?.bio, '');
    expect(controller.profile?.position, isNull);
    expect(controller.profile?.avatarId, 0);
    expect(await db.query('users'), hasLength(1));
  });

  test('save keeps and clears the country', () async {
    final controller = make();
    await controller.load();
    await controller.save(country: 'tn');
    expect(controller.profile?.country, 'TN');
    await controller.save(clearCountry: true);
    expect(controller.profile?.country, isNull);
    expect(await controller.save(country: 'XYZ'), isFalse);
    expect(controller.lastError, isNotNull);
  });

  test('avatarColor wraps around the palette', () {
    expect(avatarColor(0), avatarColors.first);
    expect(avatarColor(avatarColors.length), avatarColors.first);
    expect(avatarColor(-1), avatarColors[1]);
  });
}
