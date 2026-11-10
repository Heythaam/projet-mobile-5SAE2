import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/services/security/app_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth implements Authenticator {
  _FakeAuth({this.result = true});

  bool result;
  bool available = true;
  int asked = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    asked++;
    return result;
  }
}

Future<AppLockSettings> _settings({bool enabled = false}) async {
  SharedPreferences.setMockInitialValues({
    if (enabled) AppLockSettings.enabledKey: true,
  });
  return AppLockSettings(await SharedPreferences.getInstance());
}

Widget _app(AppLockSettings settings, Authenticator auth) => MaterialApp(
  home: AppLockGate(
    settings: settings,
    authenticator: auth,
    child: const Scaffold(body: Text('inside')),
  ),
);

Future<void> _background(WidgetTester tester) async {
  final binding = tester.binding;
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
}

Future<void> _foreground(WidgetTester tester) async {
  final binding = tester.binding;
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('settings default to off and remember the choice', (
    tester,
  ) async {
    final settings = await _settings();
    expect(settings.enabled, isFalse);
    await settings.setEnabled(true);
    expect(settings.enabled, isTrue);
    await settings.setEnabled(false);
    expect(settings.enabled, isFalse);
  });

  testWidgets('with the lock off the app opens straight away', (tester) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(_app(await _settings(), auth));
    expect(find.text('inside'), findsOneWidget);
    expect(auth.asked, 0);
  });

  testWidgets('with the lock on it asks, then opens when the check passes', (
    tester,
  ) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(_app(await _settings(enabled: true), auth));
    await tester.pump();
    expect(auth.asked, 1);
    expect(find.text('inside'), findsOneWidget);
  });

  testWidgets('a failed check keeps the app locked until Unlock works', (
    tester,
  ) async {
    final auth = _FakeAuth(result: false);
    await tester.pumpWidget(_app(await _settings(enabled: true), auth));
    await tester.pump();
    expect(find.byKey(const ValueKey('app_locked')), findsOneWidget);
    expect(find.text('inside'), findsNothing);

    auth.result = true;
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    await tester.pump();
    expect(auth.asked, 2);
    expect(find.text('inside'), findsOneWidget);
  });

  testWidgets('going to the background locks it again', (tester) async {
    final settings = await _settings(enabled: true);
    final auth = _FakeAuth();
    await tester.pumpWidget(_app(settings, auth));
    await tester.pump();
    expect(find.text('inside'), findsOneWidget);

    auth.result = false;
    await _background(tester);
    expect(find.byKey(const ValueKey('app_locked')), findsOneWidget);

    auth.result = true;
    await _foreground(tester);
    expect(find.text('inside'), findsOneWidget);
  });

  testWidgets('the background does not lock when the setting is off', (
    tester,
  ) async {
    await tester.pumpWidget(_app(await _settings(), _FakeAuth()));
    await _background(tester);
    expect(find.text('inside'), findsOneWidget);
  });
}
