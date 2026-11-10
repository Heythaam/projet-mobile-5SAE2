import 'package:shared_preferences/shared_preferences.dart';

/// Who is signed in on this phone, saved with shared_preferences.
///
/// Only the account summary lives here. The login token stays in secure
/// storage and passwords are never saved on the phone.
class SavedSession {
  const SavedSession({
    required this.uid,
    required this.username,
    required this.email,
    required this.signedInAt,
  });

  final String uid;
  final String username;
  final String email;
  final DateTime signedInAt;
}

class SessionStore {
  SessionStore(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  static const uidKey = 'session.uid';
  static const usernameKey = 'session.username';
  static const emailKey = 'session.email';
  static const signedInAtKey = 'session.signed_in_at';

  static Future<SessionStore> open() async =>
      SessionStore(await SharedPreferences.getInstance());

  /// The saved session, or null when nobody is signed in or the saved values
  /// are incomplete.
  SavedSession? read() {
    final uid = _prefs.getString(uidKey);
    final username = _prefs.getString(usernameKey);
    final email = _prefs.getString(emailKey);
    final at = _prefs.getInt(signedInAtKey);
    if (uid == null || uid.isEmpty || username == null || email == null) {
      return null;
    }
    return SavedSession(
      uid: uid,
      username: username,
      email: email,
      signedInAt: DateTime.fromMillisecondsSinceEpoch(at ?? 0, isUtc: true),
    );
  }

  /// Replaces the saved session with this account.
  Future<void> save({
    required String uid,
    required String username,
    required String email,
  }) async {
    await _prefs.setString(uidKey, uid);
    await _prefs.setString(usernameKey, username);
    await _prefs.setString(emailKey, email);
    await _prefs.setInt(signedInAtKey, _clock().millisecondsSinceEpoch);
  }

  /// Signs out on this phone.
  Future<void> clear() async {
    for (final key in [uidKey, usernameKey, emailKey, signedInAtKey]) {
      await _prefs.remove(key);
    }
  }
}
