import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/bd/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SessionStore store;
  final now = DateTime.utc(2026, 11, 9, 12);

  Future<SessionStore> open([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    return SessionStore(
      await SharedPreferences.getInstance(),
      clock: () => now,
    );
  }

  setUp(() async => store = await open());

  test('nobody is signed in at first', () {
    expect(store.read(), isNull);
  });

  test('save then read returns the same account', () async {
    await store.save(uid: '7', username: 'farouk', email: 'f@example.com');
    final session = store.read()!;
    expect(session.uid, '7');
    expect(session.username, 'farouk');
    expect(session.email, 'f@example.com');
    expect(session.signedInAt, now);
  });

  test('saving again replaces the previous account', () async {
    await store.save(uid: '7', username: 'farouk', email: 'f@example.com');
    await store.save(uid: '8', username: 'sami', email: 's@example.com');
    expect(store.read()?.uid, '8');
    expect(store.read()?.username, 'sami');
  });

  test('clear signs out', () async {
    await store.save(uid: '7', username: 'farouk', email: 'f@example.com');
    await store.clear();
    expect(store.read(), isNull);
  });

  test('survives a restart: a new store sees the saved values', () async {
    final again = await open({
      SessionStore.uidKey: '7',
      SessionStore.usernameKey: 'farouk',
      SessionStore.emailKey: 'f@example.com',
      SessionStore.signedInAtKey: now.millisecondsSinceEpoch,
    });
    expect(again.read()?.username, 'farouk');
  });

  test('incomplete saved values count as signed out', () async {
    final partial = await open({SessionStore.uidKey: '7'});
    expect(partial.read(), isNull);
  });
}
