import 'dart:async';

import 'package:flutter/foundation.dart';

import '../firebase/cloud_sync.dart';
import '../local/local_database.dart';
import '../local/user_local_store.dart';

typedef UserStoreOpener = Future<UserLocalStore> Function();

/// The signed-in player's profile, saved on the phone with SQFlite.
///
/// The first time it loads, it copies the username and email from the account
/// the app signed in with. After that the phone copy is the one that is edited.
/// Until Firebase sync exists, edits stay on this phone.
class UserProfileController extends ChangeNotifier {
  UserProfileController({
    required this.uid,
    required this.accountUsername,
    required this.email,
    UserStoreOpener? openStore,
    this.cloud = const NoopCloudSync(),
  }) : _openStore = openStore ?? _openDefaultStore;

  final String uid;
  final String accountUsername;
  final String email;
  final UserStoreOpener _openStore;

  /// Cloud copy of the profile; the phone stays the main copy.
  final CloudSync cloud;

  LocalUser? profile;
  bool loaded = false;

  /// Message for the last failed action, ready to show to the player.
  String? lastError;

  UserLocalStore? _store;
  Future<void>? _loading;
  bool _disposed = false;

  static Future<UserLocalStore> _openDefaultStore() async =>
      UserLocalStore(await LocalDatabase.open());

  Future<UserLocalStore> _ensureStore() async => _store ??= await _openStore();

  /// Opens the database once and loads, or creates, the profile.
  Future<void> load() => _loading ??= _load().whenComplete(() {
    loaded = true;
    _notify();
  });

  Future<void> _load() async {
    try {
      final store = await _ensureStore();
      profile = await store.getByUid(uid) ?? await _firstCopy(store);
    } on LocalUserException catch (error) {
      lastError = error.message;
    } catch (_) {
      lastError = 'Your profile could not be loaded from this phone.';
    }
  }

  /// First time this phone sees the account: start from the cloud profile (so
  /// a second phone gets the same bio, position and avatar) or, without one,
  /// from the account itself.
  Future<LocalUser> _firstCopy(UserLocalStore store) async {
    final remote = await cloud.pullProfile();
    if (remote != null) {
      try {
        final created = await store.create(
          uid: uid,
          username: accountUsername,
          email: email,
          bio: '${remote['bio'] ?? ''}',
          position: remote['position'] as String?,
          avatarId: (remote['avatarId'] as num?)?.toInt() ?? 0,
        );
        final country = remote['country'];
        if (country is String && country.isNotEmpty) {
          return await store.updateProfile(uid, country: country);
        }
        return created;
      } on LocalUserException {
        // A value in the cloud copy is not valid here: start from the account.
      }
    }
    return store.create(uid: uid, username: accountUsername, email: email);
  }

  /// Saves the changes. Returns false and sets [lastError] when a value is not
  /// valid, for example a username that is already taken.
  Future<bool> save({
    String? username,
    String? bio,
    String? position,
    bool clearPosition = false,
    int? avatarId,
    String? country,
    bool clearCountry = false,
    String? photoPath,
    bool clearPhoto = false,
  }) async {
    lastError = null;
    try {
      final store = await _ensureStore();
      profile = await store.updateProfile(
        uid,
        username: username,
        bio: bio,
        position: position,
        clearPosition: clearPosition,
        avatarId: avatarId,
        country: country,
        clearCountry: clearCountry,
        photoPath: photoPath,
        clearPhoto: clearPhoto,
      );
      _notify();
      final saved = profile;
      if (saved != null) unawaited(cloud.pushProfile(saved));
      return true;
    } on LocalUserException catch (error) {
      lastError = error.message;
      _notify();
      return false;
    } catch (_) {
      lastError = 'Your profile could not be saved on this phone.';
      _notify();
      return false;
    }
  }

  /// Profiles saved on this phone that match [query], A to Z.
  Future<List<LocalUser>> search(String query) async =>
      (await _ensureStore()).search(query);

  /// Deletes another profile saved on this phone. Your own profile cannot be
  /// deleted here; use [resetProfile]. Returns false and sets [lastError] when
  /// it fails.
  Future<bool> deleteOther(String otherUid) async {
    lastError = null;
    if (otherUid == uid) {
      lastError = 'Your own profile cannot be deleted here.';
      return false;
    }
    try {
      final done = await (await _ensureStore()).delete(otherUid);
      if (!done) lastError = 'That profile was already removed.';
      return done;
    } catch (_) {
      lastError = 'That profile could not be deleted.';
      return false;
    }
  }

  /// Deletes the phone copy and starts again from the signed-in account, with
  /// no bio, no position and the default avatar. Returns false and sets
  /// [lastError] when it fails.
  Future<bool> resetProfile() async {
    lastError = null;
    try {
      final store = await _ensureStore();
      await store.delete(uid);
      profile = await store.create(
        uid: uid,
        username: accountUsername,
        email: email,
      );
      _notify();
      return true;
    } on LocalUserException catch (error) {
      lastError = error.message;
    } catch (_) {
      lastError = 'Your profile could not be reset on this phone.';
    }
    _notify();
    return false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
