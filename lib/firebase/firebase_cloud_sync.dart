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
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Future<void> deleteMatch(String code) async {
    if (_auth.currentUser == null) return;
    try {
      await _db.collection('matches').doc(code).delete();
    } catch (_) {}
  }
}
