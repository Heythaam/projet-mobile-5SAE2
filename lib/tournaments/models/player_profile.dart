/// Another player's game stats, from `GET /users/:id/profile`.
class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.username,
    required this.xp,
    required this.level,
    required this.rank,
    required this.currentStreak,
    required this.bestStreak,
    required this.achievements,
    required this.recentMatches,
  });

  final int id;
  final String username;
  final int xp;
  final int level;
  final String rank;
  final int currentStreak;
  final int bestStreak;

  /// Unlocked achievements only, oldest first.
  final List<ProfileAchievement> achievements;

  /// Latest played tournament matches of teams the player plays for.
  final List<ProfileMatch> recentMatches;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
    id: json['id'] as int,
    username: json['username'] as String,
    xp: json['xp'] as int,
    level: json['level'] as int,
    rank: json['rank'] as String,
    currentStreak: json['currentStreak'] as int,
    bestStreak: json['bestStreak'] as int,
    achievements: (json['achievements'] as List<dynamic>)
        .map(
          (item) => ProfileAchievement.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
    recentMatches: (json['recentMatches'] as List<dynamic>)
        .map((item) => ProfileMatch.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class ProfileAchievement {
  const ProfileAchievement({
    required this.code,
    required this.title,
    required this.icon,
  });

  final String code;
  final String title;

  /// Icon name from the API (`whistle`, `team`, `flame`, ...).
  final String icon;

  factory ProfileAchievement.fromJson(Map<String, dynamic> json) =>
      ProfileAchievement(
        code: json['code'] as String,
        title: json['title'] as String,
        icon: json['icon'] as String? ?? '',
      );
}

enum MatchResult {
  win('win'),
  draw('draw'),
  loss('loss');

  const MatchResult(this.apiValue);

  final String apiValue;

  static MatchResult fromApi(String value) => values.firstWhere(
    (result) => result.apiValue == value,
    orElse: () => throw FormatException('Unknown match result: $value'),
  );
}

class ProfileMatch {
  const ProfileMatch({
    required this.tournamentName,
    required this.teamName,
    required this.opponentName,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.result,
    this.playedAt,
  });

  final String tournamentName;
  final String teamName;
  final String opponentName;
  final int goalsFor;
  final int goalsAgainst;
  final MatchResult result;
  final DateTime? playedAt;

  factory ProfileMatch.fromJson(Map<String, dynamic> json) => ProfileMatch(
    tournamentName: json['tournamentName'] as String,
    teamName: json['teamName'] as String,
    opponentName: json['opponentName'] as String,
    goalsFor: json['goalsFor'] as int,
    goalsAgainst: json['goalsAgainst'] as int,
    result: MatchResult.fromApi(json['result'] as String),
    playedAt: switch (json['playedAt']) {
      final String value => DateTime.tryParse(value),
      _ => null,
    },
  );
}
