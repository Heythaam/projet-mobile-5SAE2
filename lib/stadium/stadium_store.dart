import 'package:cloud_firestore/cloud_firestore.dart';

import '../tournaments/cloud/tournament_store.dart';

/// Where stadiums live. A stadium is one document holding its pitches, blocked
/// slots and bookings, so a booking is checked and saved in one step.
abstract class StadiumStore {
  Future<List<Doc>> all();

  Future<Doc?> get(int id);

  /// Takes the next free stadium id and saves what [build] returns for it.
  Future<Doc> create(Doc Function(int id) build);

  /// Reads the stadium, applies [change] and saves it as one step. If
  /// [change] throws, nothing is saved.
  Future<Doc> mutate(int id, void Function(Doc doc) change);

  Future<void> delete(int id);

  Future<bool> autoConfirm(int ownerId);

  Future<void> setAutoConfirm(int ownerId, bool value);
}

/// Firestore: `stadiums/{id}`, counter in `meta/stadiums`, and the owner's
/// choice in `stadiumOwners/{ownerId}`.
class FirestoreStadiumStore implements StadiumStore {
  FirestoreStadiumStore({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _wait = Duration(seconds: 10);

  CollectionReference<Doc> get _stadiums => _db.collection('stadiums');

  @override
  Future<List<Doc>> all() async {
    final snap = await _stadiums.limit(200).get().timeout(_wait);
    return [for (final doc in snap.docs) doc.data()];
  }

  @override
  Future<Doc?> get(int id) async =>
      (await _stadiums.doc('$id').get().timeout(_wait)).data();

  @override
  Future<Doc> create(Doc Function(int id) build) =>
      _db.runTransaction<Doc>((txn) async {
        final counter = _db.collection('meta').doc('stadiums');
        final current = (await txn.get(counter)).data()?['next'] as int? ?? 1;
        final doc = build(current);
        txn.set(counter, {'next': current + 1});
        txn.set(_stadiums.doc('$current'), doc);
        return doc;
      }).timeout(_wait);

  @override
  Future<Doc> mutate(int id, void Function(Doc doc) change) =>
      _db.runTransaction<Doc>((txn) async {
        final ref = _stadiums.doc('$id');
        final data = (await txn.get(ref)).data();
        if (data == null) throw const TournamentMissing();
        final doc = cloneDoc(data);
        change(doc);
        txn.set(ref, doc);
        return doc;
      }).timeout(_wait);

  @override
  Future<void> delete(int id) =>
      _stadiums.doc('$id').delete().timeout(_wait);

  @override
  Future<bool> autoConfirm(int ownerId) async {
    final data = (await _db
            .collection('stadiumOwners')
            .doc('$ownerId')
            .get()
            .timeout(_wait))
        .data();
    return data?['autoConfirm'] == true;
  }

  @override
  Future<void> setAutoConfirm(int ownerId, bool value) => _db
      .collection('stadiumOwners')
      .doc('$ownerId')
      .set({'autoConfirm': value})
      .timeout(_wait);
}

/// In memory, for tests.
class InMemoryStadiumStore implements StadiumStore {
  final Map<int, Doc> docs = {};
  final Map<int, bool> auto = {};
  int _next = 1;
  bool offline = false;

  void _check() {
    if (offline) throw StateError('offline');
  }

  @override
  Future<List<Doc>> all() async {
    _check();
    return [for (final doc in docs.values) cloneDoc(doc)];
  }

  @override
  Future<Doc?> get(int id) async {
    _check();
    final doc = docs[id];
    return doc == null ? null : cloneDoc(doc);
  }

  @override
  Future<Doc> create(Doc Function(int id) build) async {
    _check();
    final doc = build(_next);
    docs[_next++] = cloneDoc(doc);
    return cloneDoc(doc);
  }

  @override
  Future<Doc> mutate(int id, void Function(Doc doc) change) async {
    _check();
    final stored = docs[id];
    if (stored == null) throw const TournamentMissing();
    final doc = cloneDoc(stored);
    change(doc);
    docs[id] = cloneDoc(doc);
    return doc;
  }

  @override
  Future<void> delete(int id) async {
    _check();
    docs.remove(id);
  }

  @override
  Future<bool> autoConfirm(int ownerId) async {
    _check();
    return auto[ownerId] ?? false;
  }

  @override
  Future<void> setAutoConfirm(int ownerId, bool value) async {
    _check();
    auto[ownerId] = value;
  }
}
