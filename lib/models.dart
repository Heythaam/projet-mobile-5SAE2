class UserAccount {
  const UserAccount({
    required this.id,
    required this.username,
    required this.email,
  });

  final int id;
  final String username;
  final String email;

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    id: json['id'] as int,
    username: json['username'] as String,
    email: json['email'] as String,
  );
}

class Friend {
  const Friend({required this.id, required this.username});

  final int id;
  final String username;

  factory Friend.fromJson(Map<String, dynamic> json) =>
      Friend(id: json['id'] as int, username: json['username'] as String);
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.user,
    required this.createdAt,
  });

  final int id;
  final Friend user;
  final String createdAt;

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
    id: json['id'] as int,
    user: Friend.fromJson(json['user'] as Map<String, dynamic>),
    createdAt: json['createdAt'] as String,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.sentAt,
  });

  final int id;
  final int senderId;
  final String body;
  final String sentAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int,
    senderId: json['senderId'] as int,
    body: json['body'] as String,
    sentAt: json['sentAt'] as String,
  );
}
