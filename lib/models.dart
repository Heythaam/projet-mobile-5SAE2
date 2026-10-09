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

class Achievement {
  const Achievement({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.rewardXp,
    required this.progress,
    required this.total,
    this.unlockedAt,
  });

  final String code;
  final String title;
  final String description;
  final String icon;
  final int rewardXp;
  final int progress;
  final int total;
  final String? unlockedAt;

  bool get unlocked => unlockedAt != null;

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    code: json['code'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    icon: json['icon'] as String,
    rewardXp: json['rewardXp'] as int,
    progress: json['progress'] as int,
    total: json['total'] as int,
    unlockedAt: json['unlockedAt'] as String?,
  );
}

class GamificationProfile {
  const GamificationProfile({
    required this.xp,
    required this.level,
    required this.rank,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.currentStreak,
    required this.bestStreak,
    required this.sentMessages,
    required this.achievements,
  });

  final int xp;
  final int level;
  final String rank;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final int currentStreak;
  final int bestStreak;
  final int sentMessages;
  final List<Achievement> achievements;

  factory GamificationProfile.fromJson(Map<String, dynamic> json) =>
      GamificationProfile(
        xp: json['xp'] as int,
        level: json['level'] as int,
        rank: json['rank'] as String,
        xpIntoLevel: json['xpIntoLevel'] as int,
        xpForNextLevel: json['xpForNextLevel'] as int,
        currentStreak: json['currentStreak'] as int,
        bestStreak: json['bestStreak'] as int,
        sentMessages: json['sentMessages'] as int,
        achievements: (json['achievements'] as List<dynamic>)
            .map((item) => Achievement.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
