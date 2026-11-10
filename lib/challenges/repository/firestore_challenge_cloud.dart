import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/challenge_model.dart';
import 'challenge_cloud.dart';

/// Challenges in Firestore: `challenges/{joinCode}`, with the ids of the
/// players in `participants`. A cancelled challenge stays as `cancelled: true`
/// so other phones can drop their copy.
class FirestoreChallengeCloud implements ChallengeCloud {
  FirestoreChallengeCloud({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const _wait = Duration(seconds: 6);

  CollectionReference<Map<String, dynamic>> get _challenges =>
      _db.collection('challenges');

  @override
  Future<void> push(Challenge challenge, List<int> participants) async {
    if (_auth.currentUser == null) return;
    try {
      final data = challenge.toMap()..remove('id');
      await _challenges.doc(challenge.joinCode).set({
        ...data,
        'participants': participants,
        'cancelled': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Future<void> cancel(String joinCode) async {
    if (_auth.currentUser == null) return;
    try {
      await _challenges.doc(joinCode).set({
        'cancelled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<CloudChallenges?> pull(int userId) async {
    if (_auth.currentUser == null) return null;
    try {
      final mine = await _challenges
          .where('participants', arrayContains: userId)
          .get()
          .timeout(_wait);
      final open = await _challenges
          .where('challenge_status', isEqualTo: 'active')
          .limit(100)
          .get()
          .timeout(_wait);
      final found = <String, CloudChallenge>{};
      final cancelled = <String>{};
      for (final doc in [...mine.docs, ...open.docs]) {
        final data = doc.data();
        if (data['cancelled'] == true) {
          cancelled.add(doc.id);
          continue;
        }
        final parsed = _parse(data);
        if (parsed != null) found[doc.id] = parsed;
      }
      return CloudChallenges(found.values.toList(), cancelled);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<({CloudChallenge? challenge, bool cancelled})> fetch(
    String joinCode,
  ) async {
    if (_auth.currentUser == null) return (challenge: null, cancelled: false);
    try {
      final data = (await _challenges.doc(joinCode).get().timeout(_wait))
          .data();
      if (data == null) return (challenge: null, cancelled: false);
      if (data['cancelled'] == true) return (challenge: null, cancelled: true);
      return (challenge: _parse(data), cancelled: false);
    } catch (_) {
      return (challenge: null, cancelled: false);
    }
  }

  static CloudChallenge? _parse(Map<String, dynamic> data) {
    try {
      final participants = [
        for (final p in data['participants'] as List) (p as num).toInt(),
      ];
      return CloudChallenge(Challenge.fromMap(data), participants);
    } catch (_) {
      return null;
    }
  }
}
