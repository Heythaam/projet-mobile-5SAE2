import 'package:flutter/material.dart';

import 'api_client.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'models.dart';

void main() {
  runApp(const FootballMatchApp());
}

class FootballMatchApp extends StatefulWidget {
  const FootballMatchApp({super.key});

  @override
  State<FootballMatchApp> createState() => _FootballMatchAppState();
}

class _FootballMatchAppState extends State<FootballMatchApp> {
  final _api = ApiClient();
  UserAccount? _user;
  Object? _startupError;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final user = await _api.restoreSession();
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
    await _api.logout();
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kickoff',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF164A35),
        primary: const Color(0xFF164A35),
        surface: const Color(0xFFF7F7F1),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F7F1),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? const Color(0xFF164A35) : const Color(0xFF78827A),
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
        : _user == null
        ? AuthScreen(
            api: _api,
            onAuthenticated: (user) {
              setState(() => _user = user);
            },
          )
        : HomeScreen(api: _api, user: _user!, onLogout: _logout),
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
