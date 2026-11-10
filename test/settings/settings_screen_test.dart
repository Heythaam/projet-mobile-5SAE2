import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/api_client.dart';
import 'package:football_match_app/models.dart';
import 'package:football_match_app/settings/settings_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const me = UserAccount(id: 1, username: 'ann', email: 'a@x.tn');

  ApiClient api() => ApiClient(
    baseUrl: 'http://api.test',
    client: MockClient((_) async => http.Response('{}', 200)),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'accounts': jsonEncode({
        '1': {'token': 't1', 'username': 'ann', 'email': 'a@x.tn'},
        '2': {'token': 't2', 'username': 'bob', 'email': 'b@x.tn'},
      }),
    });
  });

  testWidgets('settings has the five options, a theme switch and log out', (
    tester,
  ) async {
    var loggedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          api: api(),
          user: me,
          onEditProfile: () {},
          onLogout: () => loggedOut = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['Edit profile', 'Theme', 'Security', 'Profiles']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Dark mode'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme_switch')));
    await tester.pumpAndSettle();
    expect(find.text('Light mode'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
  });

  testWidgets('profiles lists the other account and switches to it', (
    tester,
  ) async {
    int? switched;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilesScreen(
          api: api(),
          user: me,
          onSwitchAccount: (id) async {
            switched = id;
            return true;
          },
          onForgetAccount: (_) async {},
          onAddAccount: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile_active')), findsOneWidget);
    expect(find.text('@bob'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile_2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_2')));
    await tester.pumpAndSettle();
    expect(switched, 2);
  });
}
