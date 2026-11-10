import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../local/match_local_store.dart';
import '../local/user_local_store.dart';
import 'cloud_sync.dart';

/// Firebase Auth + Firestore copy of the player's profile and matches.
///
/// Collections: `users/{firebaseUid}` and `matches/{code}`.
class FirebaseCloudSync implements CloudSync {
  /// Starts Firebase. Returns [NoopCloudSync] when it cannot start, for
  /// example without a connection to the config or on an unsupported device.
  static Future<CloudSync> start() async {
    try {
      await Firebase.initializeApp();
      return FirebaseCloudSync._();
    } catch (_) {
      return const NoopCloudSync();
    }
  }

  FirebaseCloudSync._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>?> pullProfile() async {
    final cloudUid = _auth.currentUser?.uid;
    if (cloudUid == null) return null;
    try {
      return (await _db.collection('users').doc(cloudUid).get()).data();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> pushProfile(LocalUser user) async {
    final cloudUid = _auth.currentUser?.uid;
    if (cloudUid == null) return;
    try {
      await _db.collection('users').doc(cloudUid).set({
        'uid': user.uid,
        'email': user.email,
        'bio': user.bio,
        'position': user.position,
        'avatarId': user.avatarId,
        'country': user.country,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<void> pushMatch(LocalMatch match) async {
    if (_auth.currentUser == null) return;
    try {
      await _db.collection('matches').doc(match.code).set({
        'code': match.code,
        'hostUid': match.hostUid,
        'stadium': match.stadium,
        'scheduledAt': Timestamp.fromDate(match.scheduledAt),
        'capacity': match.capacity,
        'isPublic': match.isPublic,
        'slots': match.slots,
        'slotNames': match.slotNames,
        'latitude': match.latitude,
        'longitude': match.longitude,
        'cancelled': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Future<void> deleteMatch(String code) async {
    if (_auth.currentUser == null) return;
    try {
      // Kept as a cancelled match so other phones can drop their copy.
      await _db.collection('matches').doc(code).set({
        'cancelled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<CloudMatches?> pullMatches(String uid) async {
    if (_auth.currentUser == null) return null;
    try {
      final matches = _db.collection('matches');
      final mine = await matches
          .where('slots', arrayContains: uid)
          .get()
          .timeout(_wait);
      final open = await matches
          .where('isPublic', isEqualTo: true)
          .limit(100)
          .get()
          .timeout(_wait);
      final found = <String, LocalMatch>{};
      final cancelled = <String>{};
      for (final doc in [...mine.docs, ...open.docs]) {
        final data = doc.data();
        if (data['cancelled'] == true) {
          cancelled.add(doc.id);
          continue;
        }
        final match = _matchFrom(data);
        if (match != null) found[match.code] = match;
      }
      return CloudMatches(found.values.toList(), cancelled);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<({LocalMatch? match, bool cancelled})> fetchMatch(String code) async {
    if (_auth.currentUser == null) return (match: null, cancelled: false);
    try {
      final data = (await _db
              .collection('matches')
              .doc(code)
              .get()
              .timeout(_wait))
          .data();
      if (data == null) return (match: null, cancelled: false);
      if (data['cancelled'] == true) return (match: null, cancelled: true);
      return (match: _matchFrom(data), cancelled: false);
    } catch (_) {
      return (match: null, cancelled: false);
    }
  }

  static const _wait = Duration(seconds: 6);

  static LocalMatch? _matchFrom(Map<String, dynamic> data) {
    try {
      final slots = [for (final s in data['slots'] as List) s as String?];
      final names = [
        for (final n in (data['slotNames'] as List?) ?? const []) n as String?,
      ];
      while (names.length < slots.length) {
        names.add(null);
      }
      final at = (data['scheduledAt'] as Timestamp).toDate();
      return LocalMatch(
        code: data['code'] as String,
        hostUid: data['hostUid'] as String,
        stadium: data['stadium'] as String,
        scheduledAt: at.toUtc(),
        capacity: (data['capacity'] as num).toInt(),
        isPublic: data['isPublic'] == true,
        slots: slots,
        slotNames: names,
        latitude: (data['latitude'] as num?)?.toDouble(),
        longitude: (data['longitude'] as num?)?.toDouble(),
        createdAt: at.toUtc(),
        updatedAt: at.toUtc(),
      );
    } catch (_) {
      return null;
    }
  }
}
