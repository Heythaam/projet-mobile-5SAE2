import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/views/friends/friends_screen.dart';
import 'package:football_match_app/services/friends/friends_service.dart';
import 'package:football_match_app/entities/user/models.dart';

class _FakeFriends implements FriendsService {
  final calls = <String>[];
  bool accepted = false;

  @override
  Future<List<Friend>> getFriends() async => [
    const Friend(id: 2, uid: 'u2', username: 'samira'),
    if (accepted) const Friend(id: 3, uid: 'u3', username: 'noah'),
  ];

  @override
  Future<List<FriendRequest>> getFriendRequests() async => accepted
      ? const []
      : const [
          FriendRequest(
            id: 9,
            user: Friend(id: 3, uid: 'u3', username: 'noah'),
            createdAt: '2026-11-10',
          ),
        ];

  @override
  Future<void> acceptFriendRequest(FriendRequest request) async {
    calls.add('accept ${request.user.username}');
    accepted = true;
  }

  @override
  Future<void> sendFriendRequest(String username) async {
    calls.add('send $username');
    if (username == 'ghost') {
      throw const FriendsException('No player is called @ghost.');
    }
  }

  @override
  Future<void> removeFriend(Friend friend) async =>
      calls.add('remove ${friend.username}');

  @override
  Future<List<ChatMessage>> getMessages(Friend friend, {int after = 0}) async =>
      const [];

  @override
  Future<ChatMessage> sendMessage(Friend friend, String body) async =>
      throw UnimplementedError();
}

void main() {
  const me = UserAccount(id: 1, username: 'me', email: 'm@x.tn');

  testWidgets('lists friends and requests, and accepting adds a friend', (
    tester,
  ) async {
    final friends = _FakeFriends();
    await tester.pumpWidget(
      MaterialApp(home: FriendsScreen(friends: friends, user: me)),
    );
    await tester.pumpAndSettle();

    expect(find.text('@samira'), findsOneWidget);
    expect(find.text('Friends (1)'), findsOneWidget);
    expect(find.byKey(const ValueKey('request_9')), findsOneWidget);
    expect(find.byKey(const ValueKey('friends_share')), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(friends.calls, ['accept noah']);
    expect(find.text('Friends (2)'), findsOneWidget);
    expect(find.byKey(const ValueKey('request_9')), findsNothing);
  });

  testWidgets('a friend request to an unknown username shows why', (
    tester,
  ) async {
    final friends = _FakeFriends();
    await tester.pumpWidget(
      MaterialApp(home: FriendsScreen(friends: friends, user: me)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('friends_add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '@ghost');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('friend_send')));
    await tester.pumpAndSettle();

    expect(friends.calls, ['send ghost']);
    expect(find.text('No player is called @ghost.'), findsOneWidget);
  });

  test('both friends get the same chat id', () {
    expect(pairId('b', 'a'), pairId('a', 'b'));
    expect(pairId('a', 'b'), 'a_b');
  });
}
