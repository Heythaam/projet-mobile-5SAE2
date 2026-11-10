import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/entities/user/models.dart';
import 'package:football_match_app/views/user/choose_username_screen.dart';

import '../../support/fake_account_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the username must be free before the player moves on', (
    tester,
  ) async {
    UserAccount? done;
    await tester.pumpWidget(
      MaterialApp(
        home: ChooseUsernameScreen(
          account: FakeAccountService(takenUsernames: {'taken'}),
          onDone: (user) => done = user,
          onLogout: () {},
        ),
      ),
    );

    final field = find.descendant(
      of: find.byKey(const ValueKey('choose_username')),
      matching: find.byType(TextField),
    );
    final submit = find.byKey(const ValueKey('choose_username_submit'));

    await tester.enterText(field, 'ab');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.textContaining('3-20 letters'), findsOneWidget);
    expect(done, isNull);

    await tester.enterText(field, 'taken');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('That username is already taken.'), findsOneWidget);
    expect(done, isNull);

    await tester.enterText(field, 'fresh_name');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(done?.username, 'fresh_name');
  });
}
