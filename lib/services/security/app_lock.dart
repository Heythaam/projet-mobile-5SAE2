import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../items/kickoff_style.dart';

/// Asks the phone to check the player: fingerprint, face, or the screen lock.
abstract class Authenticator {
  /// False when the phone has no fingerprint, face or screen lock set up.
  Future<bool> isAvailable();

  /// True when the player passed the check. Never throws.
  Future<bool> authenticate(String reason);
}

class LocalAuthAuthenticator implements Authenticator {
  LocalAuthAuthenticator({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } on Object {
      return false;
    }
  }
}

/// Whether the app lock is on, kept with shared_preferences.
class AppLockSettings {
  AppLockSettings(this._prefs);

  final SharedPreferences _prefs;

  static const enabledKey = 'app_lock.enabled';

  static Future<AppLockSettings> open() async =>
      AppLockSettings(await SharedPreferences.getInstance());

  bool get enabled => _prefs.getBool(enabledKey) ?? false;

  Future<void> setEnabled(bool value) => _prefs.setBool(enabledKey, value);
}

/// Shows [child] only after the player passes the phone's check, when the app
/// lock is on. The app locks again every time it goes to the background.
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    required this.settings,
    required this.authenticator,
    required this.child,
    super.key,
  });

  final AppLockSettings settings;
  final Authenticator authenticator;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  late bool _locked = widget.settings.enabled;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) _unlock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && widget.settings.enabled) {
      if (!_locked) setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed && _locked) {
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_asking) return;
    _asking = true;
    final ok = await widget.authenticator.authenticate('Unlock Kickoff');
    _asking = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    return Scaffold(
      backgroundColor: KickoffColors.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_rounded,
                size: 56,
                color: KickoffColors.yellow,
              ),
              const SizedBox(height: 12),
              const Text(
                'Kickoff is locked',
                key: ValueKey('app_locked'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                child: ChunkyButton(
                  label: 'Unlock',
                  icon: Icons.fingerprint_rounded,
                  onPressed: _unlock,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
