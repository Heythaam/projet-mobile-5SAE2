import 'package:flutter/material.dart';

import 'services/api_client.dart';
import 'services/auth/account_service.dart';
import 'services/auth/firebase_account_service.dart';
import 'services/auth/google_auth.dart';
import 'views/auth/auth_screen.dart';
import 'services/challenge/challenge_cloud.dart';
import 'services/challenge/firestore_challenge_cloud.dart';
import 'services/friends/firestore_friends_service.dart';
import 'bd/doc_store.dart';
import 'bd/local_database.dart';
import 'services/tournament/firestore_tournament_service.dart';
import 'services/tournament/tournament_store.dart';
import 'services/stadium/firestore_stadiums.dart';
import 'services/stadium/stadium_store.dart';
import 'services/friends/friends_service.dart';
import 'bd/session_store.dart';
import 'services/security/app_lock.dart';
import 'entities/user/models.dart';
import 'views/home/kickoff_shell.dart';
import 'views/user/choose_username_screen.dart';
import 'app_route_observer.dart';
import 'services/firebase/cloud_sync.dart';
import 'services/firebase/firebase_cloud_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cloud = await FirebaseCloudSync.start();
  final AccountService account = cloud is FirebaseCloudSync
      ? FirebaseAccountService(google: PlatformGoogleAuth())
      : const UnavailableAccountService();
  runApp(
    FootballMatchApp(
      account: account,
      cloud: cloud,
      friendsFor: cloud is FirebaseCloudSync
          ? (user) => FirestoreFriendsService(me: user)
          : (_) => const EmptyFriendsService(),
    ),
  );
}

class FootballMatchApp extends StatefulWidget {
  const FootballMatchApp({
    required this.account,
    required this.friendsFor,
    this.cloud = const NoopCloudSync(),
    super.key,
  });

  final AccountService account;

  /// Friends and chat for the signed-in player.
  final FriendsService Function(UserAccount user) friendsFor;
  final CloudSync cloud;

  @override
  State<FootballMatchApp> createState() => _FootballMatchAppState();
}

class _FootballMatchAppState extends State<FootballMatchApp> {
  final _api = ApiClient();
  final Future<SessionStore> _session = SessionStore.open();
  final Authenticator _authenticator = LocalAuthAuthenticator();
  AppLockSettings? _appLock;
  UserAccount? _user;
  late final StadiumRepo _stadiumRepo = StadiumRepo(
    store: FirestoreStadiumStore(),
    cache: () async => DocStore(await LocalDatabase.open()),
  );

  /// True while a signed-in player adds another account from Settings.
  bool _adding = false;

  /// Email to fill in on the login screen after choosing a saved profile.
  String? _prefillEmail;
  Object? _startupError;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  /// Keeps the phone's saved session in step with the sign-in. Best effort:
  /// the app works without it.
  Future<void> _remember(UserAccount? user) async {
    try {
      final store = await _session;
      if (user == null) {
        await store.clear();
      } else {
        await store.save(
          uid: user.storageUid,
          username: user.username,
          email: user.email,
        );
      }
    } catch (_) {}
  }

  Future<void> _restoreSession() async {
    try {
      try {
        _appLock ??= await AppLockSettings.open();
      } catch (_) {
        // Without saved settings the app simply opens unlocked.
      }
      final user = await widget.account.restoreSession();
      if (user != null) await _remember(user);
      if (!mounted) return;
      setState(() {
        _user = user;
        _startupError = null;
        _starting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _startupError = error;
        _starting = false;
      });
    }
  }

  Future<void> _logout() async {
    await widget.account.logout();
    await _remember(null);
    if (mounted) {
      setState(() {
        _user = null;
        _adding = false;
      });
    }
  }

  /// Signs out and opens the login screen with the chosen profile's email
  /// filled in: Firebase keeps one signed-in account at a time.
  Future<bool> _switchTo(String uid) async {
    final saved = (await widget.account.rememberedAccounts())
        .where((a) => a.uid == uid)
        .firstOrNull;
    if (saved == null) return false;
    await _logout();
    if (mounted) setState(() => _prefillEmail = saved.email);
    return true;
  }

  Widget _locked(Widget shell) {
    final settings = _appLock;
    if (settings == null) return shell;
    return AppLockGate(
      settings: settings,
      authenticator: _authenticator,
      child: shell,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kickoff',
    debugShowCheckedModeBanner: false,
    navigatorObservers: [appRouteObserver],
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0B5FE8),
        primary: const Color(0xFF0B5FE8),
        secondary: const Color(0xFFFFD21F),
        surface: const Color(0xFF1A1A4E),
        onSurface: Colors.white,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF1A1A4E),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? const Color(0xFFFFD21F) : const Color(0xFFB9C3EE),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    ),
    home: _starting
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : _startupError != null
        ? _StartupError(
            error: _startupError!,
            onRetry: () {
              setState(() {
                _starting = true;
                _startupError = null;
              });
              _restoreSession();
            },
          )
        : _user == null || _adding
        ? AuthScreen(
            account: widget.account,
            prefillEmail: _prefillEmail,
            onCancel: _user != null
                ? () => setState(() => _adding = false)
                : null,
            onAuthenticated: (user) {
              _remember(user);
              setState(() {
                _user = user;
                _adding = false;
                _prefillEmail = null;
              });
            },
          )
        : !_user!.usernameChosen
        ? ChooseUsernameScreen(
            account: widget.account,
            onLogout: _logout,
            onDone: (user) {
              _remember(user);
              setState(() => _user = user);
            },
          )
        : _locked(
            KickoffShell(
              key: ValueKey(_user!.id),
              api: _api,
              account: widget.account,
              friends: widget.friendsFor(_user!),
              challengeCloud: widget.cloud is FirebaseCloudSync
                  ? FirestoreChallengeCloud()
                  : const NoopChallengeCloud(),
              tournaments: widget.cloud is FirebaseCloudSync
                  ? FirestoreTournamentService(
                      meId: _user!.id,
                      meName: _user!.username,
                      store: FirestoreTournamentStore(),
                      cache: () async => DocStore(await LocalDatabase.open()),
                    )
                  : null,
              stadiumApi: widget.cloud is FirebaseCloudSync
                  ? FirestoreStadiumApi(
                      meId: _user!.id,
                      meName: _user!.username,
                      repo: _stadiumRepo,
                    )
                  : null,
              stadiumDirectory: widget.cloud is FirebaseCloudSync
                  ? FirestoreStadiumDirectory(
                      meId: _user!.id,
                      meName: _user!.username,
                      repo: _stadiumRepo,
                    )
                  : null,
              cloud: widget.cloud,
              user: _user!,
              onLogout: _logout,
              onSwitchAccount: _switchTo,
              onForgetAccount: widget.account.forget,
              onAddAccount: () => setState(() => _adding = true),
              appLock: _appLock,
              authenticator: _authenticator,
            ),
          ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Could not restore your session.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    ),
  );
}
