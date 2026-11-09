import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/users/avatar_palette.dart';
import 'package:football_match_app/users/user_avatar.dart';

void main() {
  test('diceBearUrl carries the seed, size and colour', () {
    final url = diceBearUrl('farouk', const Color(0xFFFFD21F), 88);
    expect(url.host, 'api.dicebear.com');
    expect(url.path, '/9.x/adventurer/png');
    expect(url.queryParameters['seed'], 'farouk');
    expect(url.queryParameters['size'], '176');
    expect(url.queryParameters['backgroundColor'], 'ffd21f');
  });

  testWidgets('shows only the colour when the image cannot load', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatarFace(username: 'farouk', avatarId: 0, size: 80),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('F'), findsNothing);
    expect(find.byKey(const ValueKey('avatar_dicebear')), findsOneWidget);
  });

  testWidgets('a photo path replaces the DiceBear image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatarFace(
            username: 'farouk',
            avatarId: 2,
            size: 80,
            photoPath: '/no/such/photo.jpg',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('avatar_photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar_dicebear')), findsNothing);
    expect(find.text('F'), findsNothing);
  });

  test('the saved number is look * 6 + colour', () {
    expect(avatarLook(0), 0);
    expect(avatarLook(5), 0);
    expect(avatarLook(6), 1);
    expect(avatarColor(6), avatarColor(0));
    expect(avatarColor(8), avatarColors[2]);
    expect(avatarLook(6 * 40 + 3), 40);
  });
}
