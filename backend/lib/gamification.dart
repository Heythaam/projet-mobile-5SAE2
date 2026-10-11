import 'database.dart';

class AchievementDefinition {
  const AchievementDefinition({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.rewardXp,
    required this.target,
  });

  final String code;
  final String title;
  final String description;
  final String icon;
  final int rewardXp;
  final int target;
}

const achievements = [
  AchievementDefinition(
    code: 'first_kickoff',
    title: 'FIRST KICKOFF',
    description: 'Create your player account.',
    icon: 'whistle',
    rewardXp: 50,
    target: 1,
  ),
  AchievementDefinition(
    code: 'first_teammate',
    title: 'SQUAD ASSEMBLED',
    description: 'Accept your first teammate.',
    icon: 'team',
    rewardXp: 100,
    target: 1,
  ),
  AchievementDefinition(
    code: 'squad_of_five',
    title: 'FULL STARTING FIVE',
    description: 'Build a five-player squad.',
    icon: 'formation',
    rewardXp: 250,
    target: 5,
  ),
  AchievementDefinition(
    code: 'first_message',
    title: 'OPEN COMMS',
    description: 'Send your first teammate message.',
    icon: 'chat',
    rewardXp: 50,
    target: 1,
  ),
  AchievementDefinition(
    code: 'playmaker',
    title: 'PLAYMAKER',
    description: 'Send ten messages to your teammates.',
    icon: 'star',
    rewardXp: 150,
    target: 10,
  ),
  AchievementDefinition(
    code: 'streak_three',
    title: 'THREE-PEAT',
    description: 'Show up on three consecutive days.',
    icon: 'flame',
    rewardXp: 100,
    target: 3,
  ),
  AchievementDefinition(
    code: 'streak_seven',
    title: 'ALWAYS IN THE SQUAD',
    description: 'Show up on seven consecutive days.',
    icon: 'crown',
    rewardXp: 300,
    target: 7,
  ),
];

void recordActiveDay(AppDatabase database, int userId, {DateTime? now}) {
  final today = _dateKey(now ?? DateTime.now().toUtc());
  final row = database.db.select(
    'SELECT current_streak, best_streak, last_active_on FROM users WHERE id = ?',
    [userId],
  );
  if (row.isEmpty) return;

  final previous = row.first['last_active_on'] as String?;
  if (previous == today) return;

  final current = row.first['current_streak'] as int;
  final best = row.first['best_streak'] as int;
  final yesterday = _dateKey(
    DateTime.parse('${today}T00:00:00Z').subtract(const Duration(days: 1)),
  );
  final streak = previous == yesterday ? current + 1 : 1;
  database.db.execute(
    '''
      UPDATE users
      SET current_streak = ?, best_streak = ?, last_active_on = ?
      WHERE id = ?
    ''',
    [streak, streak > best ? streak : best, today, userId],
  );
  if (streak >= 3) unlockAchievement(database, userId, 'streak_three');
  if (streak >= 7) unlockAchievement(database, userId, 'streak_seven');
}

void grantFriendshipXp(AppDatabase database, int userId) {
  database.db.execute('UPDATE users SET xp = xp + 100 WHERE id = ?', [userId]);
  unlockEligibleAchievements(database, userId);
}

void grantMessageXp(AppDatabase database, int userId) {
  database.db.execute('UPDATE users SET xp = xp + 10 WHERE id = ?', [userId]);
  unlockEligibleAchievements(database, userId);
}

void unlockAchievement(AppDatabase database, int userId, String code) {
  final definition = achievements.firstWhere((item) => item.code == code);
  database.db.execute(
    '''
      INSERT OR IGNORE INTO user_achievements (user_id, code)
      VALUES (?, ?)
    ''',
    [userId, code],
  );
  if (database.db.updatedRows == 1) {
    database.db.execute('UPDATE users SET xp = xp + ? WHERE id = ?', [
      definition.rewardXp,
      userId,
    ]);
  }
}

void unlockEligibleAchievements(AppDatabase database, int userId) {
  final friendCount =
      database.db
              .select(
                '''
      SELECT COUNT(*) AS count FROM friendships
      WHERE status = 'accepted' AND (requester_id = ? OR addressee_id = ?)
    ''',
                [userId, userId],
              )
              .first['count']
          as int;
  final messageCount =
      database.db.select(
            'SELECT COUNT(*) AS count FROM messages WHERE sender_id = ?',
            [userId],
          ).first['count']
          as int;

  if (friendCount >= 1) unlockAchievement(database, userId, 'first_teammate');
  if (friendCount >= 5) unlockAchievement(database, userId, 'squad_of_five');
  if (messageCount >= 1) unlockAchievement(database, userId, 'first_message');
  if (messageCount >= 10) unlockAchievement(database, userId, 'playmaker');
}

Map<String, Object?> gamificationSnapshot(AppDatabase database, int userId) {
  final row = database.db.select(
    '''
      SELECT xp, current_streak, best_streak
      FROM users WHERE id = ?
    ''',
    [userId],
  );
  if (row.isEmpty) {
    throw StateError('Cannot load career profile for missing user $userId.');
  }
  final stats = row.first;
  final xp = stats['xp'] as int;
  final level = 1 + xp ~/ 300;
  final friendCount =
      database.db
              .select(
                '''
      SELECT COUNT(*) AS count FROM friendships
      WHERE status = 'accepted' AND (requester_id = ? OR addressee_id = ?)
    ''',
                [userId, userId],
              )
              .first['count']
          as int;
  final messageCount =
      database.db.select(
            'SELECT COUNT(*) AS count FROM messages WHERE sender_id = ?',
            [userId],
          ).first['count']
          as int;
  final unlocked = database.db.select(
    'SELECT code, unlocked_at FROM user_achievements WHERE user_id = ?',
    [userId],
  );
  final unlockedAt = {
    for (final badge in unlocked)
      badge['code'] as String: badge['unlocked_at'] as String,
  };
  final streak = stats['current_streak'] as int;

  return {
    'xp': xp,
    'level': level,
    'rank': _rankForLevel(level),
    'xpIntoLevel': xp % 300,
    'xpForNextLevel': 300,
    'currentStreak': streak,
    'bestStreak': stats['best_streak'],
    'sentMessages': messageCount,
    'achievements': [
      for (final definition in achievements)
        {
          'code': definition.code,
          'title': definition.title,
          'description': definition.description,
          'icon': definition.icon,
          'rewardXp': definition.rewardXp,
          'unlockedAt': unlockedAt[definition.code],
          'progress': switch (definition.code) {
            'first_kickoff' => 1,
            'first_teammate' => friendCount.clamp(0, 1),
            'squad_of_five' => friendCount.clamp(0, 5),
            'first_message' => messageCount.clamp(0, 1),
            'playmaker' => messageCount.clamp(0, 10),
            'streak_three' => streak.clamp(0, 3),
            'streak_seven' => streak.clamp(0, 7),
            _ => 0,
          },
          'total': definition.target,
        },
    ],
  };
}

String _rankForLevel(int level) => switch (level) {
  >= 10 => 'CLUB LEGEND',
  >= 7 => 'GOLDEN BOOT',
  >= 4 => 'TEAM CAPTAIN',
  >= 2 => 'RISING STAR',
  _ => 'ROOKIE',
};

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
