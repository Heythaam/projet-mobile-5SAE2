import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('shows the initial when the image cannot load', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatarFace(username: 'farouk', avatarId: 0, size: 80),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('F'), findsOneWidget);
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
    expect(find.text('F'), findsOneWidget);
  });
}
