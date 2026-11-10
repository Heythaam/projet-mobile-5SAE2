import '../../entities/user/models.dart';

/// A friends problem with a message that is ready to show to the player.
class FriendsException implements Exception {
  const FriendsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Friends, friend requests and the chat between two friends.
abstract class FriendsService {
  Future<List<Friend>> getFriends();

  Future<List<FriendRequest>> getFriendRequests();

  /// Asks the player with this username to be a friend. If they already asked
  /// you, you become friends.
  Future<void> sendFriendRequest(String username);

  Future<void> acceptFriendRequest(FriendRequest request);

  Future<void> removeFriend(Friend friend);

  /// Messages with [friend] sent after the message number [after], oldest
  /// first.
  Future<List<ChatMessage>> getMessages(Friend friend, {int after = 0});

  Future<ChatMessage> sendMessage(Friend friend, String body);
}

/// The id of the friendship (and of the chat) between two players. The same
/// for both of them, whichever order the uids come in.
String pairId(String a, String b) => a.compareTo(b) <= 0 ? '${a}_$b' : '${b}_$a';

/// Used when the cloud is not available: no friends, and changes say why.
class EmptyFriendsService implements FriendsService {
  const EmptyFriendsService();

  static const _message =
      'Friends are not available right now. Check your connection.';

  @override
  Future<List<Friend>> getFriends() async => const [];

  @override
  Future<List<FriendRequest>> getFriendRequests() async => const [];

  @override
  Future<void> sendFriendRequest(String username) =>
      throw const FriendsException(_message);

  @override
  Future<void> acceptFriendRequest(FriendRequest request) =>
      throw const FriendsException(_message);

  @override
  Future<void> removeFriend(Friend friend) =>
      throw const FriendsException(_message);

  @override
  Future<List<ChatMessage>> getMessages(Friend friend, {int after = 0}) async =>
      const [];

  @override
  Future<ChatMessage> sendMessage(Friend friend, String body) =>
      throw const FriendsException(_message);
}
