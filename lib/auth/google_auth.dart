import 'package:google_sign_in/google_sign_in.dart';

/// Gets a Google ID token from the phone's Google account picker.
abstract class GoogleAuth {
  /// Returns the ID token, or null when the player cancels.
  Future<String?> idToken();

  Future<void> signOut();
}

class PlatformGoogleAuth implements GoogleAuth {
  static Future<void>? _ready;

  Future<void> _init() => _ready ??= GoogleSignIn.instance.initialize();

  @override
  Future<String?> idToken() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
