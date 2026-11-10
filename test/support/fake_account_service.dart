import 'package:football_match_app/auth/account_service.dart';
import 'package:football_match_app/models.dart';

/// An in-memory [AccountService] for widget tests.
class FakeAccountService implements AccountService {
  FakeAccountService({
    this.supportsGoogle = false,
    List<RememberedAccount> remembered = const [],
    this.takenUsernames = const {},
    this.googleUser,
    this.loginError,
  }) : _remembered = [...remembered];

  @override
  final bool supportsGoogle;
  final Set<String> takenUsernames;
  final UserAccount? googleUser;
  final String? loginError;
  final List<RememberedAccount> _remembered;

  final calls = <String>[];

  static UserAccount account(String username) => UserAccount(
    id: 1,
    uid: 'uid_$username',
    username: username,
    email: '$username@x.tn',
  );

  @override
  Future<UserAccount?> restoreSession() async => null;

  @override
  Future<UserAccount> register({
    required String email,
    required String password,
  }) async {
    calls.add('register $email');
    return account(email.split('@').first);
  }

  @override
  Future<UserAccount> login({
    required String email,
    required String password,
  }) async {
    calls.add('login $email');
    if (loginError != null) throw AccountException(loginError!);
    return account(email.split('@').first);
  }

  @override
  Future<UserAccount?> loginWithGoogle() async {
    calls.add('google');
    return googleUser;
  }

  @override
  Future<UserAccount> setUsername(String username) async {
    final name = username.toLowerCase();
    if (takenUsernames.contains(name)) {
      throw const AccountException('That username is already taken.');
    }
    calls.add('username $name');
    return account(name);
  }

  @override
  Future<void> logout() async => calls.add('logout');

  @override
  Future<List<RememberedAccount>> rememberedAccounts() async => _remembered;

  @override
  Future<void> forget(String uid) async {
    calls.add('forget $uid');
    _remembered.removeWhere((a) => a.uid == uid);
  }
}
