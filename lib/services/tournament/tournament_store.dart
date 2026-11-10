import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

typedef Doc = Map<String, dynamic>;

/// Where tournaments live. A tournament is one document holding its teams,
/// join requests and matches, so a change is checked and saved in one step.
abstract class TournamentStore {
  /// Every tournament, newest data from the cloud. Throws when offline.
  Future<List<Doc>> all();

  Future<Doc?> get(int id);

  /// Takes the next free tournament id and saves what [build] returns for it.
  Future<Doc> create(Doc Function(int id) build);

  /// Reads the tournament, applies [change] and saves the result as one step.
  /// If [change] throws, nothing is saved.
  Future<Doc> mutate(int id, void Function(Doc doc) change);

  /// Notifications for [userId], newest first.
  Future<List<Doc>> notifications(int userId);

  Future<void> addNotification(Doc notification);

  Future<void> markNotificationRead(int id);
}

/// Deep copy through JSON, so a failed change never leaks into stored data.
Doc cloneDoc(Doc doc) => jsonDecode(jsonEncode(doc)) as Doc;

/// Firestore: `tournaments/{id}`, counter in `meta/tournaments`, and
/// `tournamentNotifications/{id}`.
class FirestoreTournamentStore implements TournamentStore {
  FirestoreTournamentStore({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _wait = Duration(seconds: 10);

  CollectionReference<Doc> get _tournaments => _db.collection('tournaments');
  CollectionReference<Doc> get _notes =>
      _db.collection('tournamentNotifications');

  @override
  Future<List<Doc>> all() async {
    final snap = await _tournaments.limit(200).get().timeout(_wait);
    return [for (final doc in snap.docs) doc.data()];
  }

  @override
  Future<Doc?> get(int id) async =>
      (await _tournaments.doc('$id').get().timeout(_wait)).data();

  @override
  Future<Doc> create(Doc Function(int id) build) =>
      _db.runTransaction<Doc>((txn) async {
        final counter = _db.collection('meta').doc('tournaments');
        final current = (await txn.get(counter)).data()?['next'] as int? ?? 1;
        final doc = build(current);
        txn.set(counter, {'next': current + 1});
        txn.set(_tournaments.doc('$current'), doc);
        return doc;
      }).timeout(_wait);

  @override
  Future<Doc> mutate(int id, void Function(Doc doc) change) =>
      _db.runTransaction<Doc>((txn) async {
        final ref = _tournaments.doc('$id');
        final data = (await txn.get(ref)).data();
        if (data == null) throw const TournamentMissing();
        final doc = cloneDoc(data);
        change(doc);
        txn.set(ref, doc);
        return doc;
      }).timeout(_wait);

  @override
  Future<List<Doc>> notifications(int userId) async {
    final snap = await _notes
        .where('userId', isEqualTo: userId)
        .limit(100)
        .get()
        .timeout(_wait);
    final list = [for (final doc in snap.docs) doc.data()];
    list.sort(
      (a, b) => (b['createdAtMs'] as int).compareTo(a['createdAtMs'] as int),
    );
    return list.take(50).toList();
  }

  @override
  Future<void> addNotification(Doc notification) =>
      _notes.doc('${notification['id']}').set(notification);

  @override
  Future<void> markNotificationRead(int id) =>
      _notes.doc('$id').set({'isRead': true}, SetOptions(merge: true));
}

/// Thrown by a store when the tournament does not exist.
class TournamentMissing implements Exception {
  const TournamentMissing();
}

/// In memory, for tests.
class InMemoryTournamentStore implements TournamentStore {
  final Map<int, Doc> docs = {};
  final List<Doc> notes = [];
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
  Future<List<Doc>> notifications(int userId) async {
    _check();
    return [
      for (final note in notes.reversed)
        if (note['userId'] == userId) cloneDoc(note),
    ];
  }

  @override
  Future<void> addNotification(Doc notification) async {
    _check();
    notes.add(cloneDoc(notification));
  }

  @override
  Future<void> markNotificationRead(int id) async {
    _check();
    for (final note in notes) {
      if (note['id'] == id) note['isRead'] = true;
    }
  }
}
