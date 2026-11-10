import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/services/auth/account_service.dart';
import 'package:football_match_app/services/auth/firebase_account_service.dart';
import 'package:football_match_app/views/auth/auth_screen.dart';
import 'package:football_match_app/entities/user/models.dart';

import '../../support/fake_account_service.dart';

void main() {
  test('a uid always maps to the same player number', () {
    expect(stableUserId('abc123'), stableUserId('abc123'));
    expect(stableUserId('abc123'), isNot(stableUserId('abc124')));
    expect(stableUserId('abc123'), isNonNegative);
  });

  test('accounts from Firebase save their data under the uid', () {
    const account = UserAccount(
      id: 7,
      uid: 'firebase-uid',
      username: 'ann',
      email: 'a@x.tn',
    );
    expect(account.storageUid, 'firebase-uid');
    expect(
      const UserAccount(id: 7, username: 'a', email: 'a@x.tn').storageUid,
      '7',
    );
  });

  test('Firebase errors become plain messages', () {
    expect(
      friendlyAuthError('email-already-in-use'),
      'That email is already registered.',
    );
    expect(
      friendlyAuthError('invalid-credential'),
      'Email or password is incorrect.',
    );
    expect(friendlyAuthError('wrong-password'), friendlyAuthError('user-not-found'));
    expect(friendlyAuthError('something-new'), contains('something-new'));
  });

  testWidgets('a saved profile fills the email and asks for the password', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          account: FakeAccountService(
            remembered: const [
              RememberedAccount(
                uid: 'uid_bob',
                username: 'bob',
                email: 'bob@x.tn',
              ),
            ],
          ),
          onAuthenticated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('continue_uid_bob')));
    await tester.pumpAndSettle();
    expect(find.text('bob@x.tn'), findsOneWidget);
  });

  testWidgets('signing in reports the account and shows login errors', (
    tester,
  ) async {
    UserAccount? signedIn;
    final account = FakeAccountService();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          account: account,
          prefillEmail: 'ann@x.tn',
          onAuthenticated: (user) => signedIn = user,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, 'secret-pass-1');
    await tester.tap(find.byKey(const ValueKey('auth_submit')));
    await tester.pumpAndSettle();
    expect(account.calls, ['login ann@x.tn']);
    expect(signedIn?.username, 'ann');

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          account: FakeAccountService(loginError: 'Email or password is incorrect.'),
          prefillEmail: 'ann@x.tn',
          onAuthenticated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'wrong-pass-1');
    await tester.tap(find.byKey(const ValueKey('auth_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
  });

  testWidgets('Continue with Google signs in, and a cancel does nothing', (
    tester,
  ) async {
    UserAccount? signedIn;
    final cancelled = FakeAccountService(supportsGoogle: true);
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          account: cancelled,
          onAuthenticated: (user) => signedIn = user,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auth_google')));
    await tester.pumpAndSettle();
    expect(cancelled.calls, ['google']);
    expect(signedIn, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          account: FakeAccountService(
            supportsGoogle: true,
            googleUser: FakeAccountService.account('gus'),
          ),
          onAuthenticated: (user) => signedIn = user,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('auth_google')));
    await tester.pumpAndSettle();
    expect(signedIn?.username, 'gus');
  });
}
