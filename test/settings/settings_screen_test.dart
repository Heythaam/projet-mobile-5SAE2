import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/services/auth/account_service.dart';
import 'package:football_match_app/entities/user/models.dart';
import 'package:football_match_app/views/settings/settings_screen.dart';

import '../support/fake_account_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const me = UserAccount(
    id: 1,
    uid: 'uid_ann',
    username: 'ann',
    email: 'a@x.tn',
  );

  FakeAccountService accounts() => FakeAccountService(
    remembered: const [
      RememberedAccount(uid: 'uid_ann', username: 'ann', email: 'a@x.tn'),
      RememberedAccount(uid: 'uid_bob', username: 'bob', email: 'b@x.tn'),
    ],
  );

  testWidgets('settings has the five options, a theme switch and log out', (
    tester,
  ) async {
    var loggedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          account: accounts(),
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
    String? switched;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilesScreen(
          account: accounts(),
          user: me,
          onSwitchAccount: (uid) async {
            switched = uid;
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
    expect(find.byKey(const ValueKey('profile_uid_bob')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile_uid_bob')));
    await tester.pumpAndSettle();
    expect(switched, 'uid_bob');
  });
}
