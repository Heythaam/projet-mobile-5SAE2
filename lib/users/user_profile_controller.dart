import 'package:flutter/foundation.dart';

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
  }) : _openStore = openStore ?? _openDefaultStore;

  final String uid;
  final String accountUsername;
  final String email;
  final UserStoreOpener _openStore;

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
      profile =
          await store.getByUid(uid) ??
          await store.create(
            uid: uid,
            username: accountUsername,
            email: email,
          );
    } on LocalUserException catch (error) {
      lastError = error.message;
    } catch (_) {
      lastError = 'Your profile could not be loaded from this phone.';
    }
  }

  /// Saves the changes. Returns false and sets [lastError] when a value is not
  /// valid, for example a username that is already taken.
  Future<bool> save({
    String? username,
    String? bio,
    String? position,
    bool clearPosition = false,
    int? avatarId,
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
      );
      _notify();
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
