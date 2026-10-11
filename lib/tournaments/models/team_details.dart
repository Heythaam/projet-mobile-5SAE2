/// A team's roster and results, from `GET /tournaments/:id/teams/:teamId`.
class TeamDetails {
  const TeamDetails({
    required this.id,
    required this.name,
    required this.captainId,
    required this.captainName,
    required this.teamSize,
    required this.canManage,
    required this.players,
    required this.stats,
  });

  final int id;
  final String name;
  final int captainId;
  final String captainName;

  /// Players per team, captain included.
  final int teamSize;

  /// Whether the signed-in user captains this team and may remove players.
  final bool canManage;

  /// Captain first, then players in the order they joined.
  final List<TeamPlayer> players;
  final TeamStats stats;

  factory TeamDetails.fromJson(Map<String, dynamic> json) => TeamDetails(
    id: json['id'] as int,
    name: json['name'] as String,
    captainId: json['captainId'] as int,
    captainName: json['captainName'] as String,
    teamSize: json['teamSize'] as int,
    canManage: json['canManage'] as bool? ?? false,
    players: (json['players'] as List<dynamic>)
        .map((item) => TeamPlayer.fromJson(item as Map<String, dynamic>))
        .toList(),
    stats: TeamStats.fromJson(json['stats'] as Map<String, dynamic>),
  );
}

class TeamPlayer {
  const TeamPlayer({
    required this.id,
    required this.username,
    required this.xp,
    required this.level,
    required this.currentStreak,
    required this.isCaptain,
  });

  final int id;
  final String username;
  final int xp;
  final int level;
  final int currentStreak;
  final bool isCaptain;

  factory TeamPlayer.fromJson(Map<String, dynamic> json) => TeamPlayer(
    id: json['id'] as int,
    username: json['username'] as String,
    xp: json['xp'] as int,
    level: json['level'] as int,
    currentStreak: json['currentStreak'] as int,
    isCaptain: json['isCaptain'] as bool? ?? false,
  );
}

/// Team totals; match figures come only from played tournament matches.
class TeamStats {
  const TeamStats({
    required this.players,
    required this.totalXp,
    required this.averageLevel,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.points,
  });

  final int players;
  final int totalXp;
  final int averageLevel;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int points;

  factory TeamStats.fromJson(Map<String, dynamic> json) => TeamStats(
    players: json['players'] as int,
    totalXp: json['totalXp'] as int,
    averageLevel: json['averageLevel'] as int,
    played: json['played'] as int,
    wins: json['wins'] as int,
    draws: json['draws'] as int,
    losses: json['losses'] as int,
    goalsFor: json['goalsFor'] as int,
    goalsAgainst: json['goalsAgainst'] as int,
    points: json['points'] as int,
  );
}
