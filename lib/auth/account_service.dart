import '../models.dart';

/// A sign-in problem with a message that is ready to show to the player.
class AccountException implements Exception {
  const AccountException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// An account that signed in on this phone before. It lets the login screen
/// offer "Continue as @name" without asking for the email again.
class RememberedAccount {
  const RememberedAccount({
    required this.uid,
    required this.username,
    required this.email,
  });

  final String uid;
  final String username;
  final String email;
}

/// Sign-in and the account's username. Firebase Auth and Firestore sit behind
/// it, so the same account works on every phone.
abstract class AccountService {
  /// Whether the login screen shows "Continue with Google".
  bool get supportsGoogle;

  /// The account that is still signed in from last time, or null.
  Future<UserAccount?> restoreSession();

  /// Creates the account. The player picks a username afterwards.
  Future<UserAccount> register({
    required String email,
    required String password,
  });

  Future<UserAccount> login({required String email, required String password});

  /// Null when the player closes the Google chooser.
  Future<UserAccount?> loginWithGoogle();

  /// Claims [username] for the signed-in account. Throws [AccountException]
  /// when someone else already has it.
  Future<UserAccount> setUsername(String username);

  /// Signs out. The account stays in [rememberedAccounts].
  Future<void> logout();

  Future<List<RememberedAccount>> rememberedAccounts();

  Future<void> forget(String uid);
}

/// Used when Firebase could not start: every sign-in says why.
class UnavailableAccountService implements AccountService {
  const UnavailableAccountService();

  static const _message =
      'Sign-in is not available right now. Check your connection and restart.';

  @override
  bool get supportsGoogle => false;

  @override
  Future<UserAccount?> restoreSession() async => null;

  @override
  Future<UserAccount> register({
    required String email,
    required String password,
  }) => throw const AccountException(_message);

  @override
  Future<UserAccount> login({
    required String email,
    required String password,
  }) => throw const AccountException(_message);

  @override
  Future<UserAccount?> loginWithGoogle() =>
      throw const AccountException(_message);

  @override
  Future<UserAccount> setUsername(String username) =>
      throw const AccountException(_message);

  @override
  Future<void> logout() async {}

  @override
  Future<List<RememberedAccount>> rememberedAccounts() async => const [];

  @override
  Future<void> forget(String uid) async {}
}

/// A number that is the same on every run for the same [uid]. Modules that
/// still use whole-number player ids use it until they move to Firebase.
int stableUserId(String uid) {
  var hash = 0x811c9dc5;
  for (final unit in uid.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
